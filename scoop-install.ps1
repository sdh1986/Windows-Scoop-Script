# Turn on logging, default location C:\Users\sdh\Documents, here we use Path to specify to the current script location.
$DATE = (Get-Date -Format 'yyyy-MM-dd')
$LOG_FILE = "$PSScriptRoot\installation\logs\${DATE}_Scoop-Install.log"
$LOG_DIR = "$PSScriptRoot\installation\logs"
if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
}
Start-Transcript -Path ${LOG_FILE} -Append -Force | Out-Null

# Use the scoop command to check if scoop is installed, if it does not exist then it will be installed automatically.('Invoke-Expression' = '&' = '.').
function Install-Scoop {
  if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host 'Scoop already installed.' -ForegroundColor Green -BackgroundColor Black
    scoop --version
  }
  else {
    $DEFAULT_CURRENT_USER = "$env:USERPROFILE\Scoop"
    $DEFAULT_GLOBAL_USER = "$env:ProgramData\ScoopGlobal"
    . "$PSScriptRoot\installation\install.ps1" -ScoopDir ${DEFAULT_CURRENT_USER} -ScoopGlobalDir ${DEFAULT_GLOBAL_USER} -NoProxy
  }
}

Install-Scoop

& "$PSScriptRoot\installation\install-depend.ps1"
