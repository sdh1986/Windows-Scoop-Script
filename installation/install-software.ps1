# Install Software
function Install-Software {
  $SOFTWARE_NAMES = @("scoop-cn/aria2", "scoop-cn/dark", "scoop-cn/innounp", 
  "scoop-cn/scoop-search", "scoop-cn/wecom", "scoop-cn/wechat")

  $installed = @()
  $failed = @()
  $skipped = @()

  foreach ($SOFTWARE in $SOFTWARE_NAMES) {
    try {
      scoop install $SOFTWARE
      if ($LASTEXITCODE -ne 0) {
        throw "scoop install exited with code $LASTEXITCODE"
      }
      $installed += $SOFTWARE
      Write-Host "Installed: $SOFTWARE" -ForegroundColor Green
    }
    catch {
      $failed += $SOFTWARE
      Write-Warning "Failed to install ${SOFTWARE}: $_"
    }
  }

  Write-Host "`nInstallation summary:" -ForegroundColor Cyan
  Write-Host "  Installed: $($installed.Count)" -ForegroundColor Green
  Write-Host "  Skipped:   $($skipped.Count)" -ForegroundColor Yellow
  Write-Host "  Failed:    $($failed.Count)" -ForegroundColor Red
  if ($failed.Count -gt 0) {
    Write-Host "  Failed apps: $($failed -join ', ')" -ForegroundColor Red
  }

  # System configuration. Elevation consent comes from the gsudo cache session
  # started in install-depend.ps1, so these gsudo calls do not prompt again.
  Write-Host "Configuring system settings..."

  Write-Host "Enabling Long Paths support..."
  gsudo Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1

  Write-Host "Enabling Developer Mode..."
  gsudo Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -Value 1

  Write-Host "Ensuring Git SSL verification is enabled..."
  git config --global http.sslverify true

  Write-Host "System configuration complete."

  # Close the gsudo credentials cache now that the install chain is done.
  Write-Host "Closing gsudo credentials cache..."
  gsudo cache off
}

Install-Software
