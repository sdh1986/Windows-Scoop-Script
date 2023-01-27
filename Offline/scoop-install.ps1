# Turn on logging, default location C:\Users\sdh\Documents, here we use Path to specify to the current script location
$SYSDATE = (Get-Date -Format 'yyyy-MM-dd')
Start-Transcript -Path ${PWD}\logs\${SYSDATE}-Scoop_install.log -Append -Force -NoClobber | Out-Null

# Use the scoop command to check if scoop is installed, if it does not exist then it will be installed automatically
function Install-Scoop {
  $EMPTY = "[ \f\n\r\t\v]"
  $NCP = "[a-zA-Z]:\\"
  $CURRENTUSER = (Read-Host -Prompt 'Please Enter The Current-User Installation Path ("C:\Scoop"e.g.)')
  $GLOBALUSER = (Read-Host -Prompt 'Please Enter The Global-User Installation Path ("C:\ScoopGlobal"e.g.)')
  $DEFAULTCURRENTUSER = "${env:USERPROFILE}\Scoop"
  $DEFAULTGLOBALUSER = "${env:ProgramData}\ScoopGlobal"

  try {
    Write-Host "scoop Installed" -ForegroundColor Green -BackgroundColor Black | scoop --version
  }
  catch {
    if (${CURRENTUSER}, ${GLOBALUSER} -imatch ${NCP}) { 
      Write-Host "The Path Of Your Installation Is ${CURRENTUSER}, ${GLOBALUSER}" -ForegroundColor Green -BackgroundColor Black
      . "${PSScriptRoot}\Installation\install.ps1" -ScoopDir ${CURRENTUSER} -ScoopGlobalDir ${GLOBALUSER} -NoProxy
    } 
    elseif (${CURRENTUSER}, ${GLOBALUSER} -imatch ${EMPTY}) {
      Write-Host "The Path Of Your Installation Is ${DEFAULTCURRENTUSER}, ${DEFAULTGLOBALUSER}" -ForegroundColor Blue -BackgroundColor Black
      . "${PSScriptRoot}\Installation\install.ps1" -ScoopDir ${DEFAULTCURRENTUSER} -ScoopGlobalDir ${DEFAULTGLOBALUSER} -NoProxy
    }
    else {
      Clear-Host
      Write-Host "Wrong Format, Please Follow The Prompts To Enter The Correct Format Path, If You Want To Install To The 'Default Location' You Can Enter 'Space'" -ForegroundColor Red -BackgroundColor Black
      powershell -Command . ${PSCommandPath}
    }
  }
}

Install-Scoop

# Required software to install scoop
function Install-App {
  $GSUDO = 'https://ghproxy.com/raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/gsudo.json'
  $7ZIP = 'https://ghproxy.com/raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/7zip.json'
  $APPCURRENT = (Get-Content "${PWD}\app\appinstallation_currentuser.txt")
  $APPGLOBAL = (Get-Content "${PWD}\app\appinstallation_globaluser.txt")
  $REPO = 'https://gitcode.net/mirrors/ScoopInstaller/Scoop'
  # Installation
  try {
    Write-Host "7-Zip Installed" -ForegroundColor Green -BackgroundColor Black | 7z | Where-Object { ${PSItem} -like "*7-Zip*" }
    Write-Host "gsudo Installed" -ForegroundColor Green -BackgroundColor Black | gsudo --version | Where-Object { ${PSItem} -like "*gsudo*" }
    Write-Host "aria2 Installed" -ForegroundColor Green -BackgroundColor Black | aria2c --version | Where-Object { ${PSItem} -like "*aria2 version*" }
  }
  catch {
    scoop install "${GSUDO}"
    scoop install "${7ZIP}"
    scoop install "${APPCURRENT}"
    gsudo scoop install "${APPGLOBAL}" --global
  }
  # Add repository and update
  scoop config SCOOP_REPO "${REPO}"
  scoop bucket rm main
  scoop update
}

Install-App

# Add available bucket
function Install-Bucket {
  $MAIN = (Get-Content "${PWD}\src\main.txt")
  $JAVA = (Get-Content "${PWD}\src\java.txt")
  $EXTRAS = (Get-Content "${PWD}\src\extras.txt")
  $DORADO = (Get-Content "${PWD}\src\dorado.txt")
  $SCOOPCN = (Get-Content "${PWD}\src\scoopcn.txt")
  $VERSIONS = (Get-Content "${PWD}\src\versions.txt")
  # Delete bucket
  $MAIN | ForEach-Object { scoop bucket rm main "${PSItem}" }
  $JAVA | ForEach-Object { scoop bucket rm java "${PSItem}" }
  $EXTRAS | ForEach-Object { scoop bucket rm extras "${PSItem}" }
  $DORADO | ForEach-Object { scoop bucket rm dorado "${PSItem}" }
  $SCOOPCN | ForEach-Object { scoop bucket rm scoopcn "${PSItem}" }
  $VERSIONS | ForEach-Object { scoop bucket rm versions "${PSItem}" }
  # Add bucket
  $MAIN | ForEach-Object { scoop bucket add main "${PSItem}" }
  $JAVA | ForEach-Object { scoop bucket add java "${PSItem}" }
  $EXTRAS | ForEach-Object { scoop bucket add extras "${PSItem}" }
  $DORADO | ForEach-Object { scoop bucket add dorado "${PSItem}" }
  $SCOOPCN | ForEach-Object { scoop bucket add scoopcn "${PSItem}" }
  $VERSIONS | ForEach-Object { scoop bucket add versions "${PSItem}" }
  # Example：$MAIN | ForEach-Object -Begin {Write-Output "add main"} -Process {scoop bucket add main "$_"} -End {Write-Output "ok"}
}

Install-Bucket

# Installing custom software
function Install-Software { 
  . "${PSScriptRoot}\scoopbackup\backups\backup-*.ps1"
  . "${PSScriptRoot}\scoopbackup\backups\backup-*.bat"
}

Install-Software

# Backup all software installed by scoop
function Backup-Scoop {
  . "${PSScriptRoot}\scoopbackup\scoop-backup.ps1"
  . "${PSScriptRoot}\scoopbackup\scoop-backup.ps1" --compress
}

Backup-Scoop

# 下面是foreach循环枚举方式
<# foreach ($MAINS in $MAIN)
  {
    scoop bucket add main $MAINS
  }

foreach ($JAVAS in $JAVA)
  {
    scoop bucket add java $JAVAS
  }

foreach ($EXTRASS in $EXTRAS)
  {
    scoop bucket add extras $EXTRASS
  }

foreach ($DORADOS in $DORADO)
  {
    scoop bucket add dorado $DORADOS
  }

foreach ($SCOOPCNS in $SCOOPCN)
  {
    scoop bucket add scoopcn $SCOOPCNS
  }

foreach ($VERSIONSS in $VERSIONS)
  {
    scoop bucket add versions $VERSIONSS
  }
} #>