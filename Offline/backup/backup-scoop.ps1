# Backup all software installed by scoop.('Invoke-Expression' = '&' = '.').
function Backup-Scoop {
  try {
    $BACKUP_SCOOP = "$PSScriptRoot\scoopbackup\scoop-backup.ps1"
    & ${BACKUP_SCOOP}
    & ${BACKUP_SCOOP} --compress
    Write-Host 'Backup Scoop Completed Successfully.' -ForegroundColor Green
  }
  catch {
    Write-Error "An Error Occurred While Backup Soop: $($_.Exception.Message)"
  }
}

Backup-Scoop