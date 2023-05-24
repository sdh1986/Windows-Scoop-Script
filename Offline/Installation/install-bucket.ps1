# Add available bucket.
function Install-Bucket {
  $BUCKET_FILES = @("sparke", "php", "main",
    "java", "extras", "dorado", "nirsoft",
    "scoopcn", "versions", "nonportable",
    "sysinternals", "scoop-cn", "nerd-fonts",
    "nirsoft-alternative")
  
  foreach ($BUCKET in $BUCKET_FILES) {
    $BUCKET_CONTENT = Get-Content "$PSScriptRoot\src\$BUCKET.txt"
    $BUCKET_CONTENT | ForEach-Object { scoop bucket rm $BUCKET $PSItem }
    $BUCKET_CONTENT | ForEach-Object { scoop bucket add $BUCKET $PSItem }
  }
  & $env:TEMP\Fastgithub_Installer\fastgithub-uninstaller.cmd
  gsudo Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1
  gsudo Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -Value 1
  git config --global http.sslverify true
}

Install-Bucket