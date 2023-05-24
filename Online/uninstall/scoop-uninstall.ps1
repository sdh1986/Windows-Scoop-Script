#requires -Version 3
# include functions and argument processing
$global:arguments = $args
. "$psscriptroot\functions.ps1"

$supported_arguments = @(
    (argument 'prints this help message' '-h' '--help' '/?' '-?'),
    (argument 'compresses the restoration script as an encoded batch file' '-c' '--compress')
)

# parse various default path settings
$compressed = passed($supported_arguments[1])
$default_filename = "uninstall-$(Get-Date -f yyMMdd)"
$default_file = "$default_filename" + $(if ($compressed) { ".bat" } else { ".ps1" })
$default_destination = "$psscriptroot\uninstallation\$default_file"
$destination = $default_destination

# check for help arguments
if (passed($supported_arguments[0])) {
    Write-Host "Usage: scoop-uninstall [flags] [destination_folder] `n"
    Write-Host "Default destination: $default_destination `n"

    $supported_arguments | ForEach-Object {
        Write-Host "$($_.Aliases)   `t $($_.Description)"
    }
    break
}

# filter all paths from our arguments and set our output folder the last path found
$global:arguments = $arguments | Where-Object {
    if (Test-Path -Path $_ -PathType container) {
        class ClassName {
            $destination
        } = "$_\$default_file"
        return $false
    }
    complain "the following path does not exist or is not a directory: $_"
    return $true
}

# complain about unrecognized arguments and abort if found
if ($arguments.Count -ne 0) {
    complain "unrecognized arguments: $arguments"
    complain "see: 'scoop-uninstall --help'"
    break
}



# import core libraries
try {
    if (!$env:SCOOP_HOME) { $env:SCOOP_HOME = Resolve-Path (scoop prefix scoop) }
    $scooplib = "$env:SCOOP_HOME\lib"
    . "$scooplib\core.ps1"
    . "$scooplib\commands.ps1"
    . "$scooplib\help.ps1"
    . "$scooplib\manifest.ps1"
    . "$scooplib\buckets.ps1"
    . "$scooplib\versions.ps1"
}
catch {
    Write-Output "Failed to import Scoop libraries, not found on path"
    break
}

# next, we install apps
$apps = installed_apps
if (($apps | Measure-Object).Count -gt 0) {

    # installing each app on a new line is, unfortunately, more resilient
    $apps | ForEach-Object {
        $info = install_info $_ (Select-CurrentVersion -AppName $_ -Global:$false) $false
        if ($info.url) { $info.url } else { "$($info.bucket)/$_" }
    } | ForEach-Object { append "scoop uninstall $_" }
}

# next, we install global apps
$globals = installed_apps $true
if (($globals | Measure-Object).Count -gt 0) {
    append 'scoop uninstall main/gsudo'

    # installing each app on a new line is, unfortunately, more resilient
    append ("gsudo powershell -Command {`nscoop uninstall --global " + (($globals | ForEach-Object {
                    $info = install_info $_ (Select-CurrentVersion -AppName $_ -Global:$true) $true
                    if ($info.url) { $($info.url) } else { "$($info.bucket)/$_" }
                }) -Join "`nscoop uninstall --global ") + "`n}")
}

# writing the final output
New-Item $destination -Force | Out-Null
if ($compressed) {
    $cmd_bytes = [System.Text.Encoding]::Unicode.GetBytes($cmd)
    $cmd_encoded = '@echo off' + [environment]::NewLine `
        + "powershell.exe -NoProfile -EncodedCommand " `
        + [Convert]::ToBase64String($cmd_bytes) + [environment]::NewLine `
        + 'pause'
    Add-Content -Path $destination -Value $cmd_encoded
}
else {
    Add-Content -Path $destination -Value $cmd
}

Write-Output "uninstall to: $destination"
