# Turn on logging, default location C:\Users\sdh\Documents, here we use Path to specify to the current script location.
$DATE = (Get-Date -Format 'yyyy-MM-dd')
$LOG_FILE = "$PSScriptRoot\installation\logs\${DATE}_Scoop-Install.log"
Start-Transcript -Path ${LOG_FILE} -Append -Force -NoClobber | Out-Null

# Use the scoop command to check if scoop is installed, if it does not exist then it will be installed automatically.('Invoke-Expression' = '&' = '.').
function Install-Scoop {
  try {
    Write-Host "Scoop Installed" -ForegroundColor Green -BackgroundColor Black | scoop --version
  }
  catch {
    $DEFAULT_CURRENT_USER = "$env:USERPROFILE\Scoop"
    $DEFAULT_GLOBAL_USER = "$env:ProgramData\ScoopGlobal"
    . "$PSScriptRoot\installation\install.ps1" -ScoopDir ${DEFAULT_CURRENT_USER} -ScoopGlobalDir ${DEFAULT_GLOBAL_USER} -NoProxy
  }
}

Install-Scoop

& "$PSScriptRoot\installation\install-depend.ps1"