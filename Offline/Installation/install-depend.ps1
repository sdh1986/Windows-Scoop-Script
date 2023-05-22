# Required software to install scoop.
function Install-Depend {
  $GSUDO = 'https://ghproxy.com/raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/gsudo.json'
  $7ZIP = 'https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/7zip.json'
  $GIT  = 'https://ghproxy.com/raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/git.json'
  $APP = (Get-Content "$PSScriptRoot\app\appinstallation_currentuser.txt")

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
    irm https://gitee.com/sdhsparke/online-installer/raw/master/Online-FastGithubInstaller.ps1 | iex
    gsudo scoop install ${7ZIP} --global
    gsudo scoop install ${GIT} --global
    scoop install ${APP}
  }
    $env:Path += ";$env:ProgramData\ScoopGlobal\apps\git\current\bin"
    git config --global http.sslverify false
    scoop update
}

Install-Depend

. "$PSScriptRoot\install-bucket.ps1"