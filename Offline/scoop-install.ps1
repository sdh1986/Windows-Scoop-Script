# Turn on logging, default location C:\Users\sdh\Documents, here we use Path to specify to the current script location.
$DATE = (Get-Date -Format 'yyyy-MM-dd')
$LOG_FILE = "$PSScriptRoot\installation\logs\${DATE}_Scoop-Install.log"
Start-Transcript -Path ${LOG_FILE} -Append -Force -NoClobber | Out-Null

# Use the scoop command to check if scoop is installed, if it does not exist then it will be installed automatically.('Invoke-Expression' = '&' = '.')
function Install-Scoop {
    try {
        Write-Host "scoop Installed." -ForegroundColor Green | scoop --version
    }
    catch {
        $CURRENT_USER = Read-Host -Prompt 'Please Enter The Current-User Installation Path (e.g. C:\Scoop)'
        $GLOBAL_USER = Read-Host -Prompt 'Please Enter The Global-User Installation Path (e.g. C:\ScoopGlobal)'
        $DEFAULT_CURRENT_USER = "$env:USERPROFILE\Scoop"
        $DEFAULT_GLOBAL_USER = "$env:ProgramData\ScoopGlobal"

        if (($CURRENT_USER -match '^([a-zA-Z]:\\[^/:*?"<>|]*)$') -and ($GLOBAL_USER -match '^([a-zA-Z]:\\[^/:*?"<>|]*)$')) {
            Write-Host "The Path Of Your Installation Is ${CURRENT_USER}, ${GLOBAL_USER}" -ForegroundColor Green
        }
        elseif (($CURRENT_USER -match '^[ \f\n\r\t\v]+$') -or ($GLOBAL_USER -match '^[ \f\n\r\t\v]+$')) {
            $CURRENT_USER = $DEFAULT_CURRENT_USER
            $GLOBAL_USER = $DEFAULT_GLOBAL_USER
            Write-Host "The Path Of Your Installation Is ${DEFAULT_CURRENT_USER}, ${DEFAULT_GLOBAL_USER}" -ForegroundColor Blue
        }
        else {
            Clear-Host
            Write-Host "Wrong Format, Please Follow The Prompts To Enter The Correct Format Path, If You Want To Install To The 'Default_Installation' You Can Enter 'Spacebar'." -ForegroundColor Red
            powershell -Command . $PSCommandPath
            return
        }
        . "$PSScriptRoot\Installation\install.ps1" -ScoopDir ${CURRENT_USER} -ScoopGlobalDir ${GLOBAL_USER} -NoProxy
    }
}

#function Install-Scoop {
#  try {
#      Write-Host "scoop Installed." -ForegroundColor Green | scoop --version
#  }
#  catch {
#      $CURRENT_USER = Read-Host -Prompt 'Please Enter The Current-User Installation Path (e.g. C:\Scoop)'
#      $GLOBAL_USER = Read-Host -Prompt 'Please Enter The Global-User Installation Path (e.g. C:\ScoopGlobal)'
#      $DEFAULT_CURRENT_USER = "$env:USERPROFILE\Scoop"
#      $DEFAULT_GLOBAL_USER = "$env:ProgramData\ScoopGlobal"
#
#      if (${CURRENT_USER}, ${GLOBAL_USER} -imatch '^[a-zA-Z]:\\') { 
#          Write-Host "The Path Of Your Installation Is ${CURRENT_USER}, ${GLOBAL_USER}" -ForegroundColor Green
#      } 
#      elseif (${CURRENT_USER}, ${GLOBAL_USER} -imatch '^[ \f\n\r\t\v]+$') {
#          ${CURRENT_USER} = ${DEFAULT_CURRENT_USER}
#          ${GLOBAL_USER} = ${DEFAULT_GLOBAL_USER}
#          Write-Host "The Path Of Your Installation Is ${DEFAULT_CURRENT_USER}, ${DEFAULT_GLOBAL_USER}" -ForegroundColor Blue
#      }
#      else {
#          Clear-Host
#          Write-Host "Wrong Format, Please Follow The Prompts To Enter The Correct Format Path, If You Want To Install To The 'Default_Installation' You Can Enter 'Spacebar'." -ForegroundColor Red
#          powershell -Command . $PSCommandPath
#          return
#      }
#      . "$PSScriptRoot\Installation\install.ps1" -ScoopDir ${CURRENT_USER} -ScoopGlobalDir ${GLOBAL_USER} -NoProxy
#  }
#}

Install-Scoop

& "$PSScriptRoot\installation\install-depend.ps1"