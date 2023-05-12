# Turn on logging, default location C:\Users\sdh\Documents, here we use Path to specify to the current script location.
$DATE = (Get-Date -Format 'yyyy-MM-dd')
$LOG_FILE = "$PWD\logs\${DATE}_Scoop-install.log"
Start-Transcript -Path ${LOG_FILE} -Append -Force -NoClobber | Out-Null

# Use the scoop command to check if scoop is installed, if it does not exist then it will be installed automatically.('Invoke-Expression' = '&' = '.')
function Install-Scoop {
    try {
        Write-Host "scoop Installed." -ForegroundColor Green -BackgroundColor Black | scoop --version
    }
    catch {
        $CURRENT_USER = Read-Host -Prompt 'Please Enter The Current-User Installation Path (e.g. C:\Scoop)'
        $GLOBAL_USER = Read-Host -Prompt 'Please Enter The Global-User Installation Path (e.g. C:\ScoopGlobal)'
        $DEFAULT_CURRENT_USER = "$env:USERPROFILE\Scoop"
        $DEFAULT_GLOBAL_USER = "$env:ProgramData\ScoopGlobal"

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
            Write-Host "Wrong Format, Please Follow The Prompts To Enter The Correct Format Path, If You Want To Install To The 'Default_Installation' You Can Enter 'Spacebar'." -ForegroundColor Red -BackgroundColor Black
            powershell -Command . $PSCommandPath
            return
        }
        . "$PSScriptRoot\Installation\install.ps1" -ScoopDir ${CURRENT_USER} -ScoopGlobalDir ${GLOBAL_USER} -NoProxy
    }
}

Install-Scoop

# Required software to install scoop.
function Install-App {
    $REPO = 'https://gitee.com/scoop-bucket/scoop'
    $7ZIP = 'https://gitee.com/sdhsparke/sparke/raw/master/bucket/7zip.json'
    $APPCURRENT = (Get-Content "$PWD\app\appinstallation_currentuser.txt")
  
    # Installation
    try {
        Write-Host '7-Zip Installed.' -ForegroundColor Green -BackgroundColor Black | 7z | Where-Object { $PSItem -like "*7-Zip*" }
        Write-Host 'git   Installed.' -ForegroundColor Green -BackgroundColor Black | git --version | Where-Object { $PSItem -like "*git*" }
        Write-Host 'gsudo Installed.' -ForegroundColor Green -BackgroundColor Black | gsudo --version | Where-Object { $PSItem -like "*gsudo*" }
        Write-Host 'aria2 Installed.' -ForegroundColor Green -BackgroundColor Black | aria2c --version | Where-Object { $PSItem -like "*aria2 version*" }
    }
    catch {
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
    $BUCKET_FILES = @("sparke", "php", "main",
        "java", "extras", "dorado", "nirsoft",
        "scoopcn", "versions", "nonportable",
        "sysinternals", "scoop-cn", "nerd-fonts",
        "nirsoft-alternative"
    )
    
    foreach ($BUCKET in ${BUCKET_FILES}) {
        $BUCKET_CONTENT = Get-Content "$PWD\src\${BUCKET}.txt"
        ${BUCKET_CONTENT} | ForEach-Object { scoop bucket rm ${BUCKET} $PSItem }
        ${BUCKET_CONTENT} | ForEach-Object { scoop bucket add ${BUCKET} $PSItem }
    }
}

Install-Bucket

# Installing custom software.('Invoke-Expression' = '&' = '.')
function Install-Software {
    try {
        $INSTALL_SOFTWARE = "$PSScriptRoot\scoopbackup\backups\backup"
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
        $BACKUP_SCOOP = "$PSScriptRoot\scoopbackup\scoop-backup.ps1"
        & ${BACKUP_SCOOP}
        & ${BACKUP_SCOOP} --compress
        Write-Host 'Backup Scoop Completed Successfully.' -ForegroundColor Green -BackgroundColor Black
    }
    catch {
        Write-Error "An Error Occurred While Backup Soop: $($_.Exception.Message)"
    }
}

Backup-Scoop