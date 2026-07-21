#requires -Version 5.1
<#
.SYNOPSIS
    Uninstalls Scoop and all installed applications, buckets, and environment configuration.

.DESCRIPTION
    This script performs a complete standard uninstall of Scoop from the local machine.
    It uninstalls all user and global applications, removes all buckets, deletes the
    Scoop root and global directories, and cleans up associated PATH and environment
    variables. The user configuration directory at $env:USERPROFILE\.config\scoop is
    intentionally preserved so it can be reused during a later installation.

.PARAMETER Force
    Skip the interactive confirmation prompt and proceed immediately.

.PARAMETER NoBackup
    Skip generating the pre-uninstall restore script. By default, the script invokes
    the backup module before any destructive action occurs.

.PARAMETER DryRun
    Print the full uninstall plan and make no changes to the system.

.EXAMPLE
    .\scoop-uninstall.ps1 -WhatIf
    Not supported; use -DryRun to preview the plan without making changes.

.EXAMPLE
    .\scoop-uninstall.ps1 -DryRun
    Displays the plan without uninstalling anything.

.EXAMPLE
    .\scoop-uninstall.ps1 -Force -NoBackup
    Uninstalls Scoop without prompting and without creating a restore script.
#>
param(
    [switch]$Force,
    [switch]$NoBackup,
    [switch]$DryRun
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# --- helper functions ---
function Write-ColorLine {
    param(
        [string]$Text,
        [string]$ForegroundColor = 'White',
        [string]$BackgroundColor = 'Black'
    )
    Write-Host $Text -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-CaseInsensitivePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    if (Test-Path -LiteralPath $Path) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    $parent = Split-Path -Parent $Path
    $leaf = Split-Path -Leaf $Path
    if ([string]::IsNullOrWhiteSpace($parent)) {
        return $null
    }
    if (-not (Test-Path -LiteralPath $parent)) {
        return $null
    }
    $item = Get-ChildItem -Path $parent | Where-Object {
        $_.Name -eq $leaf
    } | Select-Object -First 1
    if ($item) {
        return $item.FullName
    }
    return $null
}

function Remove-TrailingBackslash {
    param([string]$Path)
    if ($Path -and $Path.EndsWith('\')) {
        return $Path.TrimEnd('\')
    }
    return $Path
}

# Strict-mode-safe property reader: returns $null when the property is absent
# instead of throwing PropertyNotFoundStrict.
function Get-ObjectProperty {
    param(
        [object]$Object,
        [string]$Name
    )
    if ($null -eq $Object) {
        return $null
    }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) {
        return $prop.Value
    }
    return $null
}

function Test-IsPathSafeToDelete {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Warning "Deletion safety check skipped: path is empty."
        return $false
    }
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        Write-Warning "Deletion safety check failed: '$Path' does not exist."
        return $false
    }
    $fullPath = $resolved.Path
    $root = (Split-Path -Qualifier $fullPath).TrimEnd('\')
    if ($fullPath -ieq $root) {
        Write-Warning "Deletion safety check failed: '$fullPath' is a drive root."
        return $false
    }
    $segments = $fullPath -split '\\' | Where-Object { $_ -ne '' }
    $hasScoopSegment = $false
    foreach ($segment in $segments) {
        if ($segment -ieq 'scoop') {
            $hasScoopSegment = $true
            break
        }
    }
    if ($hasScoopSegment) {
        return $true
    }
    $hasApps = Test-Path -LiteralPath (Join-Path $fullPath 'apps')
    $hasShims = Test-Path -LiteralPath (Join-Path $fullPath 'shims')
    if ($hasApps -and $hasShims) {
        return $true
    }
    Write-Warning "Deletion safety check failed: '$fullPath' does not contain a 'scoop' path segment and does not contain both 'apps' and 'shims' subdirectories."
    return $false
}

function Open-EnvironmentKey {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('User', 'Machine')]
        [string]$Scope,
        [bool]$Writable = $true
    )
    # Registry hives must be opened via the proper static properties; deriving them
    # from path strings like 'HKCU:\Environment' does NOT work with [Registry]::.
    if ($Scope -eq 'User') {
        return [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $Writable)
    }
    return [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $Writable)
}

function Remove-EnvPathEntries {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('User', 'Machine')]
        [string]$Scope,
        [string]$TargetFolder
    )
    $targetFolder = Remove-TrailingBackslash -Path $TargetFolder
    if ([string]::IsNullOrWhiteSpace($targetFolder)) {
        return $false
    }
    $regKey = Open-EnvironmentKey -Scope $Scope -Writable $true
    if (-not $regKey) {
        Write-Warning "Could not open the $Scope environment registry key."
        return $false
    }
    try {
        $options = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
        $value = $regKey.GetValue('PATH', $null, $options)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $false
        }
        $originalParts = $value -split ';' | Where-Object { $_ -ne '' }
        $newParts = @()
        $changed = $false
        foreach ($part in $originalParts) {
            $normalized = Remove-TrailingBackslash -Path $part
            if ($normalized -ieq $targetFolder) {
                $changed = $true
            } else {
                $newParts += $part
            }
        }
        if ($changed) {
            $newValue = $newParts -join ';'
            if ($newParts.Count -eq 0) {
                $newValue = ''
            }
            $kind = [Microsoft.Win32.RegistryValueKind]::String
            if ($value.Contains('%')) {
                $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
            }
            $regKey.SetValue('PATH', $newValue, $kind)
        }
        return $changed
    }
    finally {
        $regKey.Dispose()
    }
}

function Remove-EnvVariable {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('User', 'Machine')]
        [string]$Scope,
        [string]$VariableName
    )
    $regKey = Open-EnvironmentKey -Scope $Scope -Writable $true
    if (-not $regKey) {
        Write-Warning "Could not open the $Scope environment registry key."
        return $false
    }
    try {
        $value = $regKey.GetValue($VariableName, $null)
        if ($null -ne $value) {
            $regKey.DeleteValue($VariableName)
            return $true
        }
        return $false
    }
    finally {
        $regKey.Dispose()
    }
}

# scoop app dirs contain 'current' junctions; Remove-Item -Recurse chokes on them
# ('access denied'). cmd's rmdir removes reparse points correctly, so prefer it.
function Remove-DirectoryRobust {
    param([string]$Path)
    $cmdline = 'rmdir /s /q "{0}"' -f $Path
    cmd.exe /c $cmdline
    if ($LASTEXITCODE -eq 0) {
        return $true
    }
    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Broadcast-EnvironmentChange {
    if (-not ('Win32.NativeMethods' -as [Type])) {
        Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    }
    $result = [UIntPtr]::Zero
    [void][Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}

# --- a) transcript ---
$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir ("uninstall-{0:yyyy-MM-dd}.log" -f (Get-Date))
Start-Transcript -Path $logFile -Append -Force | Out-Null

Write-ColorLine "=== Scoop Standard Uninstaller ===" -ForegroundColor Cyan

# --- b) detect scoop ---
$scoopCmd = Get-Command 'scoop' -ErrorAction SilentlyContinue
if (-not $scoopCmd) {
    Write-ColorLine "Scoop is not installed, nothing to do." -ForegroundColor Green
    Stop-Transcript | Out-Null
    exit 0
}

# --- d) resolve paths and read config ---
$configPath = Join-Path $env:USERPROFILE '.config\scoop\config.json'
$config = $null
if (Test-Path -LiteralPath $configPath) {
    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Warning "Failed to parse Scoop config: $_"
    }
}

$ScoopRoot = $env:SCOOP
if (-not $ScoopRoot -and $config) {
    $ScoopRoot = Get-ObjectProperty -Object $config -Name 'root_path'
}
if (-not $ScoopRoot) {
    $ScoopRoot = Resolve-CaseInsensitivePath -Path (Join-Path $env:USERPROFILE 'scoop')
    if (-not $ScoopRoot) {
        $ScoopRoot = Resolve-CaseInsensitivePath -Path (Join-Path $env:USERPROFILE 'Scoop')
    }
}
if ($ScoopRoot) {
    # Guard: Resolve-Path may return nothing for a stale SCOOP/root_path value,
    # and accessing .Path on $null throws under Set-StrictMode.
    $resolvedScoopRoot = Resolve-Path -LiteralPath $ScoopRoot -ErrorAction SilentlyContinue
    if ($resolvedScoopRoot) {
        $ScoopRoot = $resolvedScoopRoot.Path
    }
}
if (-not $ScoopRoot) {
    $ScoopRoot = Join-Path $env:USERPROFILE 'scoop'
}

$GlobalRoot = $env:SCOOP_GLOBAL
if (-not $GlobalRoot -and $config) {
    $GlobalRoot = Get-ObjectProperty -Object $config -Name 'global_path'
}
if (-not $GlobalRoot) {
    $GlobalRoot = Resolve-CaseInsensitivePath -Path (Join-Path $env:ProgramData 'scoop')
    if (-not $GlobalRoot) {
        $GlobalRoot = Resolve-CaseInsensitivePath -Path (Join-Path $env:ProgramData 'ScoopGlobal')
    }
}
if ($GlobalRoot) {
    $resolvedGlobalRoot = Resolve-Path -LiteralPath $GlobalRoot -ErrorAction SilentlyContinue
    if ($resolvedGlobalRoot) {
        $GlobalRoot = $resolvedGlobalRoot.Path
    }
}
if (-not $GlobalRoot) {
    $GlobalRoot = Join-Path $env:ProgramData 'scoop'
}

$ShimsDir = Join-Path $ScoopRoot 'shims'

# --- c) gather state ---
$userApps = @()
$globalApps = @()
$buckets = @()

$exportJson = $null
try {
    $exportJson = scoop export | Out-String | ConvertFrom-Json
}
catch {
    Write-Warning "scoop export JSON parse failed; falling back to scoop list and scoop bucket list."
}

if ($exportJson -and $exportJson.apps) {
    foreach ($app in $exportJson.apps) {
        $appInfo = Get-ObjectProperty -Object $app -Name 'Info'
        if ($appInfo -and $appInfo -like '*Global install*') {
            $globalApps += $app.Name
        }
        else {
            $userApps += $app.Name
        }
    }
}
else {
    try {
        $userApps = (scoop list | Where-Object { $_ -and $_.Info -notlike '*Global install*' }).Name
        $globalApps = (scoop list | Where-Object { $_ -and $_.Info -like '*Global install*' }).Name
    }
    catch {
        Write-Warning "Failed to enumerate installed apps: $_"
    }
}

if ($exportJson -and $exportJson.buckets) {
    $buckets = $exportJson.buckets | ForEach-Object { @{ Name = $_.Name; Source = $_.Source } }
}
else {
    try {
        $buckets = scoop bucket list | ForEach-Object { @{ Name = $_.Name; Source = $_.Source } }
    }
    catch {
        Write-Warning "Failed to enumerate buckets: $_"
    }
}

# Normalize to arrays
if (-not $userApps) { $userApps = @() }
if (-not $globalApps) { $globalApps = @() }
if (-not $buckets) { $buckets = @() }
$userApps = @($userApps)
$globalApps = @($globalApps)
$buckets = @($buckets)

# Filesystem fallback: when the scoop CLI is broken (e.g. the main bucket directory
# is missing, which crashes 'scoop list'/'scoop export'), enumerate installed apps
# and buckets straight from the directory tree so they can still be removed.
if ($userApps.Count -eq 0) {
    $appsDir = Join-Path $ScoopRoot 'apps'
    if (Test-Path -LiteralPath $appsDir) {
        $userApps = @(Get-ChildItem -LiteralPath $appsDir -Directory | Where-Object { $_.Name -ne 'scoop' } | ForEach-Object { $_.Name })
        if ($userApps.Count -gt 0) {
            Write-Warning "scoop CLI unavailable; enumerated $($userApps.Count) user app(s) from the filesystem."
        }
    }
}
if ($globalApps.Count -eq 0) {
    $globalAppsDir = Join-Path $GlobalRoot 'apps'
    if (Test-Path -LiteralPath $globalAppsDir) {
        $globalApps = @(Get-ChildItem -LiteralPath $globalAppsDir -Directory | ForEach-Object { $_.Name })
        if ($globalApps.Count -gt 0) {
            Write-Warning "scoop CLI unavailable; enumerated $($globalApps.Count) global app(s) from the filesystem."
        }
    }
}
if ($buckets.Count -eq 0) {
    $bucketsDir = Join-Path $ScoopRoot 'buckets'
    if (Test-Path -LiteralPath $bucketsDir) {
        $buckets = @(Get-ChildItem -LiteralPath $bucketsDir -Directory | ForEach-Object { @{ Name = $_.Name; Source = '' } })
    }
}

# --- e) print plan ---
Write-ColorLine "PLAN:" -ForegroundColor Yellow
Write-Host "User apps to remove: $($userApps.Count)"
if ($userApps.Count -gt 0) {
    Write-Host "  $($userApps -join ', ')"
}
Write-Host "Global apps to remove: $($globalApps.Count)"
if ($globalApps.Count -gt 0) {
    Write-Host "  $($globalApps -join ', ')"
}
Write-Host "Buckets to remove: $($buckets.Count)"
if ($buckets.Count -gt 0) {
    Write-Host "  $($buckets.Name -join ', ')"
}
Write-Host "ScoopRoot to delete: $ScoopRoot"
Write-Host "GlobalRoot to delete: $GlobalRoot"
Write-Host "PATH entries to remove:"
Write-Host "  User PATH entries under: $ShimsDir"
if ($globalApps.Count -gt 0) {
    Write-Host "  Machine PATH entries under: $(Join-Path $GlobalRoot 'shims')"
}
Write-ColorLine "The configuration directory '$env:USERPROFILE\.config\scoop' will be PRESERVED." -ForegroundColor Green

# --- f) dry run ---
if ($DryRun) {
    Write-ColorLine "DRY RUN - no changes made." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    exit 0
}

# --- g) backup ---
if (-not $NoBackup) {
    $backupScript = Join-Path $PSScriptRoot '..\backup\scoop-backup.ps1'
    $resolvedBackupScript = Resolve-Path -LiteralPath $backupScript -ErrorAction SilentlyContinue
    if ($resolvedBackupScript) {
        $backupScript = $resolvedBackupScript.Path
    }
    if ($backupScript -and (Test-Path -LiteralPath $backupScript)) {
        $restoreDir = Join-Path $PSScriptRoot 'restores'
        try {
            Write-Host "Creating pre-uninstall restore script in $restoreDir ..."
            & $backupScript -DestinationFolder $restoreDir
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Backup script returned exit code $LASTEXITCODE; continuing anyway."
            }
        }
        catch {
            Write-Warning "Backup script failed: $_; continuing anyway."
        }
    }
    else {
        Write-Warning "Backup module not found at '$backupScript'; continuing without backup."
    }
}

# --- h) confirmation ---
if (-not $Force) {
    $confirmation = Read-Host "Type YES to continue"
    if ($confirmation -ne 'YES') {
        Write-ColorLine "Uninstall aborted by user." -ForegroundColor Yellow
        Stop-Transcript | Out-Null
        exit 0
    }
}

$failures = @()
$skipped = @()
$isAdmin = Test-IsAdmin
$gsudoCmd = Get-Command 'gsudo' -ErrorAction SilentlyContinue

# --- i) execute uninstall ---

# Preserve gsudo until the very end: it is a user app, but it is needed elevated for
# global apps, GlobalRoot deletion, and machine-level registry cleanup.
$appsWithoutGsudo = @($userApps | Where-Object { $_ -ne 'gsudo' })

# 1. Global apps (gsudo still present)
foreach ($app in $globalApps) {
    try {
        if ($gsudoCmd) {
            Write-Host "Uninstalling global app with gsudo: $app"
            gsudo scoop uninstall --global $app
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "gsudo scoop uninstall returned exit code $LASTEXITCODE for global app '$app'."
                $failures += "global app: $app (exit $LASTEXITCODE)"
            }
        }
        elseif ($isAdmin) {
            Write-Host "Uninstalling global app as administrator: $app"
            scoop uninstall --global $app
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "scoop uninstall --global returned exit code $LASTEXITCODE for '$app'."
                $failures += "global app: $app (exit $LASTEXITCODE)"
            }
        }
        else {
            Write-Warning "Global app '$app' skipped: requires gsudo or administrator privileges."
            $skipped += "global app: $app (needs manual removal)"
        }
    }
    catch {
        Write-Warning "Failed to uninstall global app '$app': $_"
        $failures += "global app: $app"
    }
}

# 2. User apps except gsudo
foreach ($app in $appsWithoutGsudo) {
    try {
        Write-Host "Uninstalling user app: $app"
        scoop uninstall $app
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "scoop uninstall returned exit code $LASTEXITCODE for user app '$app'."
            $failures += "user app: $app (exit $LASTEXITCODE)"
        }
    }
    catch {
        Write-Warning "Failed to uninstall user app '$app': $_"
        $failures += "user app: $app"
    }
}

# 3. Buckets
foreach ($bucket in $buckets) {
    try {
        Write-Host "Removing bucket: $($bucket.Name)"
        scoop bucket rm $bucket.Name
    }
    catch {
        Write-Warning "Failed to remove bucket '$($bucket.Name)': $_"
        $failures += "bucket: $($bucket.Name)"
    }
}

# 4. Delete GlobalRoot (gsudo still present if not admin)
$globalSafe = Test-IsPathSafeToDelete -Path $GlobalRoot
if ($globalSafe) {
    try {
        if ($isAdmin) {
            Write-Host "Deleting GlobalRoot: $GlobalRoot"
            if (Remove-DirectoryRobust -Path $GlobalRoot) {
                Write-Host "GlobalRoot deleted." -ForegroundColor Green
            }
            else {
                Write-Warning "Failed to delete GlobalRoot '$GlobalRoot'."
                $failures += "GlobalRoot deletion: $GlobalRoot"
            }
        }
        elseif ($gsudoCmd) {
            # Elevated junction-safe deletion; rmdir's exit code propagates through gsudo.
            Write-Host "Deleting GlobalRoot with gsudo: $GlobalRoot"
            $rmdirLine = 'rmdir /s /q "{0}"' -f $GlobalRoot
            gsudo cmd.exe /c $rmdirLine
            if ($LASTEXITCODE -eq 0) {
                Write-Host "GlobalRoot deleted." -ForegroundColor Green
            }
            else {
                Write-Warning "gsudo rmdir of GlobalRoot returned exit code $LASTEXITCODE."
                $failures += "GlobalRoot deletion: $GlobalRoot"
            }
        }
        else {
            Write-Warning "GlobalRoot '$GlobalRoot' skipped: requires gsudo or administrator privileges."
            $skipped += "GlobalRoot deletion: $GlobalRoot (needs manual removal)"
        }
    }
    catch {
        Write-Warning "Failed to delete GlobalRoot '$GlobalRoot': $_"
        $failures += "GlobalRoot deletion: $GlobalRoot"
    }
}
else {
    $skipped += "GlobalRoot deletion: $GlobalRoot (safety check failed)"
}

# 5. Machine environment cleanup (gsudo still present if not admin)
$envChanged = $false

if ($isAdmin -or $gsudoCmd) {
    try {
        $globalShims = Join-Path $GlobalRoot 'shims'
        Write-Host "Cleaning machine PATH entries under $globalShims"
        $machinePathChanged = $false
        if ($isAdmin) {
            $machinePathChanged = Remove-EnvPathEntries -Scope 'Machine' -TargetFolder $globalShims
        }
        else {
            $machinePathChanged = gsudo powershell -NoProfile -Command "
                `$dir = Join-Path '$GlobalRoot' 'shims'
                `$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', `$true)
                `$options = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
                `$value = `$regKey.GetValue('PATH', `$null, `$options)
                if (`$value) {
                    `$parts = `$value -split ';' | Where-Object { `$_ -ne '' }
                    `$newParts = @()
                    `$changed = `$false
                    `$target = `$dir.TrimEnd('\')
                    foreach (`$part in `$parts) {
                        if ((`$part.TrimEnd('\')) -ieq `$target) { `$changed = `$true } else { `$newParts += `$part }
                    }
                    if (`$changed) {
                        `$newValue = `$newParts -join ';'
                        if (`$newParts.Count -eq 0) { `$newValue = '' }
                        `$kind = if (`$value.Contains('%')) { [Microsoft.Win32.RegistryValueKind]::ExpandString } else { [Microsoft.Win32.RegistryValueKind]::String }
                        `$regKey.SetValue('PATH', `$newValue, `$kind)
                    }
                }
                `$regKey.Dispose()
                if (`$changed) { exit 1 } else { exit 0 }
            "
            if ($LASTEXITCODE -eq 1) { $machinePathChanged = $true }
        }
        if ($machinePathChanged) { $envChanged = $true }
    }
    catch {
        Write-Warning "Failed to clean machine PATH: $_"
        $failures += "machine PATH cleanup"
    }

    try {
        Write-Host "Deleting machine environment variables SCOOP_GLOBAL and SCOOP_CACHE if present"
        $globalVarChanged = $false
        if ($isAdmin) {
            if (Remove-EnvVariable -Scope 'Machine' -VariableName 'SCOOP_GLOBAL') { $globalVarChanged = $true }
            if (Remove-EnvVariable -Scope 'Machine' -VariableName 'SCOOP_CACHE') { $globalVarChanged = $true }
        }
        else {
            $globalVarChanged = gsudo powershell -NoProfile -Command "
                `$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', `$true)
                `$changed = `$false
                foreach (`$var in @('SCOOP_GLOBAL','SCOOP_CACHE')) {
                    if (`$regKey.GetValue(`$var, `$null) -ne `$null) { `$regKey.DeleteValue(`$var); `$changed = `$true }
                }
                `$regKey.Dispose()
                if (`$changed) { exit 1 } else { exit 0 }
            "
            if ($LASTEXITCODE -eq 1) { $globalVarChanged = $true }
        }
        if ($globalVarChanged) { $envChanged = $true }
    }
    catch {
        Write-Warning "Failed to delete machine SCOOP_GLOBAL/SCOOP_CACHE variables: $_"
        $failures += "machine SCOOP_GLOBAL/SCOOP_CACHE variable deletion"
    }
}

# 6. Uninstall gsudo itself (last scoop operation while scoop still works)
if ($userApps -contains 'gsudo') {
    try {
        Write-Host "Uninstalling user app: gsudo"
        scoop uninstall gsudo
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "scoop uninstall returned exit code $LASTEXITCODE for user app 'gsudo'."
            $failures += "user app: gsudo (exit $LASTEXITCODE)"
        }
    }
    catch {
        Write-Warning "Failed to uninstall user app 'gsudo': $_"
        $failures += "user app: gsudo"
    }
}

# 7. Delete ScoopRoot (no elevation needed now)
$deleteScoop = Test-IsPathSafeToDelete -Path $ScoopRoot
if ($deleteScoop) {
    Write-Host "Deleting ScoopRoot: $ScoopRoot"
    if (Remove-DirectoryRobust -Path $ScoopRoot) {
        Write-Host "ScoopRoot deleted." -ForegroundColor Green
    }
    else {
        Write-Warning "Failed to delete ScoopRoot '$ScoopRoot'. A running application may be locking files - exit it first (security clients like cms6 must be closed or removed via their own uninstaller) and re-run this script."
        $failures += "ScoopRoot deletion: $ScoopRoot (locked by a running app?)"
    }
}
else {
    $skipped += "ScoopRoot deletion: $ScoopRoot (safety check failed)"
}

# 8. User environment cleanup
try {
    Write-Host "Cleaning user PATH entries under $ShimsDir"
    $userChanged = Remove-EnvPathEntries -Scope 'User' -TargetFolder $ShimsDir
    if ($userChanged) { $envChanged = $true }
}
catch {
    Write-Warning "Failed to clean user PATH: $_"
    $failures += "user PATH cleanup"
}

try {
    Write-Host "Deleting user environment variable SCOOP if present"
    $scoopVarChanged = Remove-EnvVariable -Scope 'User' -VariableName 'SCOOP'
    if ($scoopVarChanged) { $envChanged = $true }
}
catch {
    Write-Warning "Failed to delete user SCOOP variable: $_"
    $failures += "user SCOOP variable deletion"
}

if ($envChanged) {
    Broadcast-EnvironmentChange
}

# 9. Config preserved (nothing to do)

# --- j) summary ---
Write-ColorLine "=== Uninstall Summary ===" -ForegroundColor Cyan
Write-Host "User apps removed: $($userApps.Count - $failures.Where({$_ -like 'user app:*'}).Count) of $($userApps.Count)"
Write-Host "Global apps removed: $($globalApps.Count - $failures.Where({$_ -like 'global app:*'}).Count) of $($globalApps.Count)"
Write-Host "Buckets removed: $($buckets.Count - $failures.Where({$_ -like 'bucket:*'}).Count) of $($buckets.Count)"
if ($skipped.Count -gt 0) {
    Write-ColorLine "Skipped:" -ForegroundColor Yellow
    $skipped | ForEach-Object { Write-Host "  $_" }
}
if ($failures.Count -gt 0) {
    Write-ColorLine "Failures:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  $_" }
}
Write-ColorLine "Configuration preserved at: $env:USERPROFILE\.config\scoop" -ForegroundColor Green

Stop-Transcript | Out-Null
if ($failures.Count -gt 0) {
    exit 1
}
exit 0
