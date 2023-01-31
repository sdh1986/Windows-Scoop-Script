# Turn on logging, default location C:\Users\sdh\Documents, here we use Path to specify to the current script location.
$DATE = (Get-Date -Format 'yyyy-MM-dd')
$LOG_FILE = "${PWD}\logs\${DATE}_Scoop-install.log"
Start-Transcript -Path $LOG_FILE -Append -Force -NoClobber | Out-Null

# Use the scoop command to check if scoop is installed, if it does not exist then it will be installed automatically.('Invoke-Expression' = '&' = '.')
function Install-Scoop {
  try {
    Write-Host "scoop Installed" -ForegroundColor Green -BackgroundColor Black | scoop --version
  }
  catch {
    $CURRENT_USER = Read-Host -Prompt 'Please Enter The Current-User Installation Path (e.g. C:\Scoop)'
    $GLOBAL_USER = Read-Host -Prompt 'Please Enter The Global-User Installation Path (e.g. C:\ScoopGlobal)'
    $DEFAULT_CURRENT_USER = "${env:USERPROFILE}\Scoop"
    $DEFAULT_GLOBAL_USER = "${env:ProgramData}\ScoopGlobal"

    if (${CURRENT_USER}, ${GLOBAL_USER} -imatch '^[a-zA-Z]:\\') { 
      Write-Host "The Path Of Your Installation Is ${CURRENT_USER}, ${GLOBAL_USER}" -ForegroundColor Green -BackgroundColor Black
    } 
    elseif (${CURRENT_USER}, ${GLOBAL_USER} -imatch '^[ \f\n\r\t\v]+$') {
      ${CURRENT_USER} = ${DEFAULT_CURRENT_USER}
      ${GLOBAL_USER} = ${DEFAULT_GLOBAL_USER}
      Write-Host "The Path Of Your Installation Is ${DEFAULT_CURRENT_USER}, ${DEFAULT_GLOBAL_USER}" -ForegroundColor Blue -BackgroundColor Black
    }
    else {
      Clear-Host
      Write-Host "Wrong Format, Please Follow The Prompts To Enter The Correct Format Path, If You Want To Install To The 'Default Location' You Can Enter 'Spaces'." -ForegroundColor Red -BackgroundColor Black
      powershell -Command . ${PSCommandPath}
      return
    }
    . "${PSScriptRoot}\Installation\install.ps1" -ScoopDir ${CURRENT_USER} -ScoopGlobalDir ${GLOBAL_USER} -NoProxy
  }
}

Install-Scoop

# Required software to install scoop.
function Install-App {
  $REPO = 'https://ghproxy.com/github.com/ScoopInstaller/Scoop'
  $7ZIP = 'https://ghproxy.com/raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/7zip.json'
  $GSUDO = 'https://ghproxy.com/raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/gsudo.json'
  $APPCURRENT = (Get-Content "${PWD}\app\appinstallation_currentuser.txt")

  # Installation
  try {
    Write-Host '7-Zip Installed' -ForegroundColor Green -BackgroundColor Black | 7z | Where-Object { ${PSItem} -like "*7-Zip*" }
    Write-Host 'git Installed' -ForegroundColor Green -BackgroundColor Black | git --version | Where-Object { ${PSItem} -like "*git*" }
    Write-Host 'gsudo Installed' -ForegroundColor Green -BackgroundColor Black | gsudo --version | Where-Object { ${PSItem} -like "*gsudo*" }
    Write-Host 'aria2 Installed' -ForegroundColor Green -BackgroundColor Black | aria2c --version | Where-Object { ${PSItem} -like "*aria2 version*" }
  }
  catch {
    scoop install ${GSUDO}
    scoop install ${7ZIP}
    scoop install ${APPCURRENT}
  }
  # Add repository and update.
  scoop config SCOOP_REPO ${REPO}
  scoop bucket rm main
  scoop update
}

Install-App

# Add available bucket.
function Install-Bucket {
  $BUCKET_FILES = @("main", "java", "extras", "dorado", "scoopcn", "scoop-cn", "versions")
  
  foreach (${BUCKET} in ${BUCKET_FILES}) {
    $BUCKET_CONTENT = Get-Content "${PWD}\src\${BUCKET}.txt"
    ${BUCKET_CONTENT} | ForEach-Object { scoop bucket rm ${BUCKET} ${PSItem} }
    ${BUCKET_CONTENT} | ForEach-Object { scoop bucket add ${BUCKET} ${PSItem} }
  }
}

Install-Bucket

# Installing custom software.('Invoke-Expression' = '&' = '.')
function Install-Software {
  try {
    $INSTALL_SOFTWARE = "${PSScriptRoot}\scoopbackup\backups\backup"
    Invoke-Expression ${INSTALL_SOFTWARE}-*.ps1
    Invoke-Expression ${INSTALL_SOFTWARE}-*.bat
    Write-Host 'Software Installation Completed Successfully.' -ForegroundColor Green -BackgroundColor Black
  }
  catch {
    Write-Error "An Error Occurred While Installing Software: $($_.Exception.Message)"
  }
}

Install-Software

# Backup all software installed by scoop.('Invoke-Expression' = '&' = '.')
function Backup-Scoop {
  try {
    $BACKUP_SCOOP = "${PSScriptRoot}\scoopbackup\scoop-backup.ps1"
    & ${BACKUP_SCOOP}
    & ${BACKUP_SCOOP} --compress
    Write-Host 'Backup Scoop Completed Successfully.' -ForegroundColor Green -BackgroundColor Black
  }
  catch {
    Write-Error "An Error Occurred While Backup Soop: $($_.Exception.Message)"
  }
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
}

Install-Bucket #>


# Add available bucket
<# function Install-Bucket {
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

Install-Bucket #>