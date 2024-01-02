# Required software to install scoop.
function Install-Depend {
  $GSUDO = 'https://mirror.ghproxy.com/https://raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/gsudo.json'
  $7ZIP = 'https://mirror.ghproxy.com/https://raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/7zip.json'
  $GIT = 'https://mirror.ghproxy.com/https://raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/git.json'
  $REPO = 'https://mirror.ghproxy.com/https://github.com/ScoopInstaller/Scoop'
  $APP = (Get-Content "$PSScriptRoot\app\appinstallation_currentuser.txt")

  # Solve the problem of 7zip error due to lack of directory
  $BucketPath = "$env:USERPROFILE\scoop\buckets\scoop-cn\bucket"
  $ScriptsPath = "$env:USERPROFILE\scoop\buckets\scoop-cn\scripts\7-zip"
  $ZipJsonPath = "$BucketPath\7zip.json"
  $InstallRegPath = "$ScriptsPath\install-context.reg"
  $UninstallRegPath = "$ScriptsPath\uninstall-context.reg"
  
  if (-not (Test-Path $BucketPath)) {
    New-Item -ItemType "directory" -Path $BucketPath
}
  if (-not (Test-Path $ScriptsPath)) {
    New-Item -ItemType "directory" -Path $ScriptsPath
}
  if (-not (Test-Path $ZipJsonPath)) {
    Invoke-RestMethod -Uri "https://mirror.ghproxy.com/https://raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/7zip.json" -OutFile $ZipJsonPath
}
  if (-not (Test-Path $InstallRegPath)) {
    Invoke-RestMethod -Uri "https://mirror.ghproxy.com/https://raw.githubusercontent.com/duzyn/scoop-cn/master/scripts/7-zip/install-context.reg" -OutFile $InstallRegPath
}
  if (-not (Test-Path $UninstallRegPath)) {
    Invoke-RestMethod -Uri "https://mirror.ghproxy.com/https://raw.githubusercontent.com/duzyn/scoop-cn/master/scripts/7-zip/uninstall-context.reg" -OutFile $UninstallRegPath
}

  # Installation.
  try {
    Write-Host '7-Zip   Installed' -ForegroundColor Green | 7z | Where-Object { $PSItem -like "*7-Zip*" }
    Write-Host 'aria2   Installed' -ForegroundColor Green | aria2c --version | Where-Object { $PSItem -like "*aria2 version*" }
    Write-Host 'dark    Installed' -ForegroundColor Green | dark | Where-Object { $PSItem -like "*dark.*" }
    Write-Host 'git     Installed' -ForegroundColor Green | git --version | Where-Object { $PSItem -like "*git*" }
    Write-Host 'gsudo   Installed' -ForegroundColor Green | gsudo --version | Where-Object { $PSItem -like "*gsudo*" }
    Write-Host 'innounp Installed' -ForegroundColor Green | innounp | Where-Object { $PSItem -like "*innounp,*" }
  }
  catch {
    scoop install ${GSUDO}
    gsudo reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f
    gsudo . "$PSScriptRoot\install-githubhosts.ps1"
    gsudo scoop install ${7ZIP} --global
    gsudo scoop install ${GIT} --global
    scoop install ${APP}
    scoop bucket rm main
    scoop config scoop_repo ${REPO}
  }
  # Reload variables in current window.
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
  # Due to GIT TLS/SSL not being able to pass through self-signed certificates, it must be turned off.
  git config --global http.sslverify false
  scoop update
}

Install-Depend

. "$PSScriptRoot\install-bucket.ps1"