<#
.SYNOPSIS
    Creates a PowerShell restore script for the current Scoop installation.

.PARAMETER DestinationFolder
    Folder where the backup artifacts are written. Defaults to "$PSScriptRoot\backups".

.PARAMETER Compress
    Also emit an encoded .bat wrapper alongside the .ps1 restore script.

.PARAMETER NoTranscript
    Disable transcript logging.

.EXAMPLE
    .\scoop-backup.ps1 -DestinationFolder C:\scoop-backup -Compress
#>
param(
    [string]$DestinationFolder,
    [switch]$Compress,
    [switch]$NoTranscript
)

# Isolate this script from the caller's scope: when invoked from another script
# (e.g. the uninstaller sets strict mode + EAP=Stop), inherited settings would
# turn harmless $null property reads into terminating errors.
Set-StrictMode -Off
$ErrorActionPreference = 'Continue'

# Use a default destination folder if the caller did not supply one.
if ([string]::IsNullOrWhiteSpace($DestinationFolder)) {
    $DestinationFolder = "$PSScriptRoot\backups"
}

# Verify that scoop is available on the system.
if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host 'ERROR: scoop is not available on this system.' -ForegroundColor Red
    exit 1
}

# Compute the date stamps once for all output artifacts.
$dateStamp = Get-Date -Format 'yyMMdd'
$logDateStamp = Get-Date -Format 'yyyy-MM-dd'

# Start a transcript unless the caller disabled it.
$transcriptStarted = $false
if (!$NoTranscript) {
    $logDir = "$PSScriptRoot\logs"
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logFile = "$logDir\backup-$logDateStamp.log"
    Start-Transcript -Path $logFile -Append -Force | Out-Null
    $transcriptStarted = $true
}

# Ensure the destination folder exists.
if (!(Test-Path $DestinationFolder)) {
    New-Item -ItemType Directory -Path $DestinationFolder -Force | Out-Null
}

# Gather the current Scoop state. Prefer the machine-readable JSON export and
# fall back to parsing the table-style list output if export fails.
$exportJson = $null
$exportObj = $null
$usedFallback = $false

try {
    $exportJson = (& scoop export 2>$null) -join "`n"
    if ($? -and $exportJson) {
        $exportObj = $exportJson | ConvertFrom-Json
    }
    else {
        $usedFallback = $true
    }
}
catch {
    $usedFallback = $true
}

if ($usedFallback -or ($null -eq $exportObj)) {
    $buckets = @()
    try {
        foreach ($item in (& scoop bucket list 2>$null)) {
            if ($item -is [System.Management.Automation.PSCustomObject]) {
                $buckets += @{
                    Name   = $item.Name
                    Source = $item.Source
                }
            }
            elseif ($item -is [string] -and $item.Trim() -ne '') {
                $tokens = $item.Trim() -split '\s+'
                if ($tokens[0] -and $tokens[0] -notmatch '^(Name|---|Source|Updated|Manifests)$') {
                    $buckets += @{
                        Name   = $tokens[0]
                        Source = if ($tokens.Length -gt 1) { $tokens[1] } else { '' }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to parse 'scoop bucket list': $_"
    }

    $apps = @()
    try {
        foreach ($item in (& scoop list 2>$null)) {
            if ($item -is [System.Management.Automation.PSCustomObject]) {
                $apps += @{
                    Name    = $item.Name
                    Version = $item.Version
                    Source  = $item.Source
                    Info    = $item.Info
                }
            }
            elseif ($item -is [string] -and $item.Trim() -ne '') {
                $line = $item.Trim()
                if ($line -notmatch '^(Installed apps|Name\s+Version|---|Source|Updated|Info)$') {
                    $tokens = $line -split '\s+'
                    $apps += @{
                        Name    = if ($tokens.Length -gt 0) { $tokens[0] } else { '' }
                        Version = if ($tokens.Length -gt 1) { $tokens[1] } else { '' }
                        Source  = if ($tokens.Length -gt 2) { $tokens[2] } else { '' }
                        Info    = if ($tokens.Length -gt 3) { $tokens[3] } else { '' }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to parse 'scoop list': $_"
    }

    $exportObj = @{
        buckets = $buckets
        apps    = $apps
    }
}

# Normalize the two arrays so we can safely count and iterate.
$buckets = @($exportObj.buckets)
$apps    = @($exportObj.apps)

# Resolve scoop roots for potential filesystem fallbacks.
$fsScoopRoot = $env:SCOOP
if (-not $fsScoopRoot) {
    if (Test-Path "$env:USERPROFILE\Scoop\apps") { $fsScoopRoot = "$env:USERPROFILE\Scoop" }
    elseif (Test-Path "$env:USERPROFILE\scoop\apps") { $fsScoopRoot = "$env:USERPROFILE\scoop" }
}
$fsGlobalRoot = $env:SCOOP_GLOBAL
if (-not $fsGlobalRoot) {
    if (Test-Path "$env:ProgramData\ScoopGlobal\apps") { $fsGlobalRoot = "$env:ProgramData\ScoopGlobal" }
    elseif (Test-Path "$env:ProgramData\scoop\apps") { $fsGlobalRoot = "$env:ProgramData\scoop" }
}

# Filesystem fallback for buckets (sources unknown in this case).
if ($buckets.Count -eq 0 -and $fsScoopRoot -and (Test-Path (Join-Path $fsScoopRoot 'buckets'))) {
    foreach ($dir in (Get-ChildItem -LiteralPath (Join-Path $fsScoopRoot 'buckets') -Directory)) {
        $buckets += @{ Name = $dir.Name; Source = '' }
    }
}

# Filesystem fallback for apps: when the scoop CLI is broken (e.g. the main bucket
# directory is missing, which crashes 'scoop list'/'scoop export'), enumerate
# installed apps straight from the apps directories. Sources are unknown; the
# restore lines fall back to plain 'scoop install <name>'.
if ($apps.Count -eq 0) {
    if ($fsScoopRoot -and (Test-Path (Join-Path $fsScoopRoot 'apps'))) {
        foreach ($dir in (Get-ChildItem -LiteralPath (Join-Path $fsScoopRoot 'apps') -Directory)) {
            if ($dir.Name -eq 'scoop') { continue }
            $apps += @{ Name = $dir.Name; Version = ''; Source = ''; Info = '' }
        }
    }
    if ($fsGlobalRoot -and (Test-Path (Join-Path $fsGlobalRoot 'apps'))) {
        foreach ($dir in (Get-ChildItem -LiteralPath (Join-Path $fsGlobalRoot 'apps') -Directory)) {
            $apps += @{ Name = $dir.Name; Version = ''; Source = ''; Info = 'Global install' }
        }
    }
    if ($apps.Count -gt 0) {
        Write-Warning "scoop CLI unavailable; enumerated $($apps.Count) app(s) from the filesystem (sources unknown)."
    }
}

# Helper: determine whether a source string looks like a plain bucket name.
function Test-BucketName {
    param([string]$Value)
    return $Value -cmatch '^[A-Za-z0-9_-]+$'
}

# Helper: quote a source string only when it contains spaces.
function Format-QuotedSource {
    param([string]$Source)
    if ($Source -match '\s') {
        return '"' + $Source + '"'
    }
    return $Source
}

# Build the restore script as an array of lines.
$restoreLines = @()
$restoreLines += '# Scoop restore script generated by scoop-backup.ps1'
$restoreLines += "# Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# --- Buckets ---
$bucketLines = @()
foreach ($bucket in $buckets) {
    $name   = $bucket.Name
    $source = $bucket.Source
    if ([string]::IsNullOrWhiteSpace($source)) {
        $bucketLines += "# Bucket '$name' has no source URL; skipping add."
    }
    else {
        $bucketLines += "scoop bucket add $name $source"
    }
}
if ($bucketLines.Count -gt 0) {
    $restoreLines += ''
    $restoreLines += '# --- Buckets ---'
    $restoreLines += $bucketLines
}

# --- User-scope apps ---
$userApps = @($apps | Where-Object { $_.Info -ne 'Global install' })
$userLines = @()
foreach ($app in $userApps) {
    $source = $app.Source
    $name   = $app.Name
    if ([string]::IsNullOrWhiteSpace($source)) {
        $userLines += "scoop install $name # source bucket unknown; any bucket providing it works"
    }
    elseif (Test-BucketName -Value $source) {
        $userLines += "scoop install $source/$name"
    }
    else {
        $quotedSource = Format-QuotedSource -Source $source
        $userLines += "scoop install $quotedSource # was: $name"
    }
}
if ($userLines.Count -gt 0) {
    $restoreLines += ''
    $restoreLines += '# --- User-scope apps ---'
    $restoreLines += $userLines
}

# --- Global apps ---
$globalApps = @($apps | Where-Object { $_.Info -eq 'Global install' })
if ($globalApps.Count -gt 0) {
    $restoreLines += ''
    $restoreLines += '# --- Global apps ---'

    # Make sure gsudo is available so the following elevated installs can run.
    $gsudoCovered = $false
    foreach ($app in $userApps) {
        if ($app.Name -eq 'gsudo') {
            $gsudoCovered = $true
            break
        }
    }
    if (!$gsudoCovered) {
        $restoreLines += 'scoop install main/gsudo'
    }

    foreach ($app in $globalApps) {
        $source = $app.Source
        $name   = $app.Name
        if ([string]::IsNullOrWhiteSpace($source)) {
            $restoreLines += "gsudo scoop install --global $name # source bucket unknown; any bucket providing it works"
        }
        elseif (Test-BucketName -Value $source) {
            $restoreLines += "gsudo scoop install --global $source/$name"
        }
        else {
            $quotedSource = Format-QuotedSource -Source $source
            $restoreLines += "gsudo scoop install --global $quotedSource # was: $name"
        }
    }
}

# Append a summary comment at the end of the script.
$restoreLines += ''
$restoreLines += '# --- Summary ---'
$restoreLines += "# Buckets exported: $($buckets.Count)"
$restoreLines += "# User apps exported: $($userApps.Count)"
$restoreLines += "# Global apps exported: $($globalApps.Count)"

$restoreContent = $restoreLines -join "`r`n"

# Write the main restore script.
$baseName    = "backup-$dateStamp"
$restoreFile = Join-Path $DestinationFolder "$baseName.ps1"
Set-Content -Path $restoreFile -Value $restoreContent -Encoding UTF8 -Force

# Copy the Scoop config file if it exists.
$configSource = "$env:USERPROFILE\.config\scoop\config.json"
$configFile  = Join-Path $DestinationFolder "$baseName.config.json"
if (Test-Path $configSource) {
    Copy-Item -Path $configSource -Destination $configFile -Force
}

# Save the raw export data (or the fallback reconstruction) as JSON.
$exportFile = Join-Path $DestinationFolder "$baseName.export.json"
if ($usedFallback -or ([string]::IsNullOrWhiteSpace($exportJson))) {
    $exportObj | ConvertTo-Json -Depth 10 | Set-Content -Path $exportFile -Encoding UTF8 -Force
}
else {
    Set-Content -Path $exportFile -Value $exportJson -Encoding UTF8 -Force
}

# Optionally write an encoded batch wrapper that invokes the restore script.
if ($Compress) {
    $batFile = Join-Path $DestinationFolder "$baseName.bat"
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($restoreContent))
    $batContent = "@echo off`r`npowershell.exe -NoProfile -EncodedCommand $encoded`r`npause"
    Set-Content -Path $batFile -Value $batContent -Encoding UTF8 -Force
}

# Print a colored summary to the console.
Write-Host ''
Write-Host 'Scoop backup completed successfully.' -ForegroundColor Green
Write-Host "Buckets exported: $($buckets.Count)" -ForegroundColor Cyan
Write-Host "User apps exported: $($userApps.Count)" -ForegroundColor Cyan
Write-Host "Global apps exported: $($globalApps.Count)" -ForegroundColor Cyan
Write-Host "Restore script: $restoreFile" -ForegroundColor Yellow
if ($Compress) {
    Write-Host "Encoded batch: $batFile" -ForegroundColor Yellow
}
Write-Host "Config export: $configFile" -ForegroundColor Yellow
Write-Host "Raw export: $exportFile" -ForegroundColor Yellow

if ($transcriptStarted) {
    Stop-Transcript | Out-Null
}

exit 0
