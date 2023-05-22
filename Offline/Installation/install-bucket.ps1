# Add available bucket.
function Install-Bucket {
  $BUCKET_FILES = @("shgr", "grsh", "scoop-cn")
  
  foreach ($BUCKET in $BUCKET_FILES) {
    $BUCKET_CONTENT = Get-Content "$PSScriptRoot\src\$BUCKET.txt"
    $BUCKET_CONTENT | ForEach-Object { scoop bucket rm $BUCKET $PSItem }
    $BUCKET_CONTENT | ForEach-Object { scoop bucket add $BUCKET $PSItem }
  }
    irm https://bucketshgr.duckdns.org/shendonghu/Install-Software/-/raw/master/Fastgithub-Uninstaller.ps1 | iex
    gsudo Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1
    gsudo Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -Value 1
    git config --global http.sslverify true
}

Install-Bucket