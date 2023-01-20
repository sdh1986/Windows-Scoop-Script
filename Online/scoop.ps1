# Turn on logging, default location C:\Users\sdh\Documents, here we use Path to specify to the current script location
$SYSTEMDATE = (Get-Date -Format 'yyMMdd')
Start-Transcript -Path $PWD\logs\Scoop-install"$SYSTEMDATE".log -Append -Force -NoClobber

# Use the scoop command to check if scoop is installed, if it does not exist then it will be installed automatically
function Install-Scoop {
    Try {
        Write-Host "scoop Installed" -ForegroundColor Green -BackgroundColor Black | scoop --version | Where-Object { $_ -like "*Scoop version*"} > $null
    }
    Catch {
        Invoke-Expression (new-object net.webclient).downloadstring('https://ghproxy.com/raw.githubusercontent.com/duzyn/scoop-cn/master/install.ps1')
    }
}

# Required software to install scoop
function Install-App {
    $7ZIP = 'https://ghproxy.com/raw.githubusercontent.com/duzyn/scoop-cn/master/bucket/7zip.json'
    $APPS = (Get-Content "$PWD\app\appinstaller.txt")
    $REPO = 'https://gitcode.net/mirrors/ScoopInstaller/Scoop'
    # Installation
    Try {
        Write-Host "7-Zip Installed" -ForegroundColor Green -BackgroundColor Black | 7z | Where-Object { $_ -like "*7-Zip*" } > $null
        Write-Host "gsudo Installed" -ForegroundColor Green -BackgroundColor Black | gsudo --version | Where-Object { $_ -like "*gsudo*" } > $null
        Write-Host "aria2 Installed" -ForegroundColor Green -BackgroundColor Black | aria2c --version | Where-Object { $_ -like "*aria2 version*" } > $null
    }
    Catch {
        scoop install "$7ZIP"
        scoop install "$APPS"
    }
    # Add repository and update
    scoop config SCOOP_REPO "$REPO"
    scoop bucket rm main
    scoop update
}

# Add available bucket
function Install-Bucket {
    $MAIN = (Get-Content "$PWD\src\main.txt")
    $JAVA = (Get-Content "$PWD\src\java.txt")
    $EXTRAS = (Get-Content "$PWD\src\extras.txt")
    $DORADO = (Get-Content "$PWD\src\dorado.txt")
    $SCOOPCN = (Get-Content "$PWD\src\scoopcn.txt")
    $VERSIONS = (Get-Content "$PWD\src\versions.txt")
    # Delete bucket
    $MAIN | ForEach-Object { scoop bucket rm main "$_" }
    $JAVA | ForEach-Object { scoop bucket rm java "$_" }
    $EXTRAS | ForEach-Object { scoop bucket rm extras "$_" }
    $DORADO | ForEach-Object { scoop bucket rm dorado "$_" }
    $SCOOPCN | ForEach-Object { scoop bucket rm scoopcn "$_" }
    $VERSIONS | ForEach-Object { scoop bucket rm versions "$_" }
    # Add bucket
    $MAIN | ForEach-Object { scoop bucket add main "$_" }
    $JAVA | ForEach-Object { scoop bucket add java "$_" }
    $EXTRAS | ForEach-Object { scoop bucket add extras "$_" }
    $DORADO | ForEach-Object { scoop bucket add dorado "$_" }
    $SCOOPCN | ForEach-Object { scoop bucket add scoopcn "$_" }
    $VERSIONS | ForEach-Object { scoop bucket add versions "$_" }
    # Example：$MAIN | ForEach-Object -Begin {Write-Output "add main"} -Process {scoop bucket add main "$_"} -End {Write-Output "ok"}    
}

# Installing custom software
function Install-Software {
    . "$PSScriptRoot\scoopbackup\backups\backup-*.ps1"
    . "$PSScriptRoot\scoopbackup\backups\backup-*.bat"
}

# Backup all software installed by scoop
function Backup-Scoop {
    . "$PSScriptRoot\scoopbackup\scoop-backup.ps1"
    . "$PSScriptRoot\scoopbackup\scoop-backup.ps1" --compress
}

# The following is the foreach loop enumeration method
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
    scoop bucket add dorados $DORADOS
}

foreach ($DODORZS in $DODORZ)
{
    scoop bucket add dodorz $DODORZS
}

foreach ($SCOOPCNS in $SCOOPCN)
{
    scoop bucket add scoopcn $SCOOPCNS
}

foreach ($VERSIONSS in $VERSIONS)
{
    scoop bucket add versions $VERSIONSS
} #>

# Use function
Install-Scoop
Install-App
Install-Bucket
Install-Software
Backup-Scoop