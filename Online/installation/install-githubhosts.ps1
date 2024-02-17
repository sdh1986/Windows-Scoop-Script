function Install-Githubhosts {
    # Parameters for the function
    param(
        [string]$DownloadUrl = 'https://hosts.gitcdn.top/hosts.txt',
        [string]$HostsFilePath = 'C:\Windows\System32\drivers\etc\hosts',
        [string]$BackupSuffix = '.backup'
    )

    # Function to download a file from a URL to a destination
    function Download-File([string]$Url, [string]$Destination) {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Destination
            return $true
        }
        catch {
            Write-Host "Download Failed: $_"
            return $false
        }
    }

    # Function to check if a file is in use by another process
    function Check-FileInUse([string]$FilePath) {
        try {
            $file = [System.io.File]::Open($FilePath, 'Open', 'Read', 'None')
            $file.Close()
            return $false
        }
        catch {
            return $true
        }
    }

    # Function to validate if a line is a valid entry for a hosts file
    function IsValid-HostEntry([string]$Line) {
        $pattern = '^\d{1,3}(\.\d{1,3}){3}\s+\S+'
        return $Line -match $pattern
    }

    # Function to merge the downloaded content with the existing hosts file
    function Merge-HostsFile([string]$DownloadPath, [string]$HostsPath) {
        $originalContent = Get-Content $HostsPath
        $downloadedContent = Get-Content $DownloadPath

        # Filter and collect valid new entries
        $validNewEntries = $downloadedContent | Where-Object { IsValid-HostEntry -Line $_ } | Where-Object { $originalContent -notcontains $_ }

        # Check if there are any valid new entries to add
        if ($validNewEntries.Count -gt 0) {
            # Check if the hosts file is not in use
            if (-not (Check-FileInUse -FilePath $HostsPath)) {
                # Backup the original hosts file before making changes
                $backupPath = "$HostsPath$BackupSuffix"
                Copy-Item -Path $HostsPath -Destination $backupPath -Force

                # Append new valid entries to the hosts file
                $originalContent += "`n# Begin New Content`n" + ($validNewEntries -join "`n")
                $originalContent | Set-Content $HostsPath
                Write-Host "hosts file updated. Backup stored in: $backupPath"
            }
            else {
                Write-Host "Unable to update hosts file because it is occupied."
            }
        }
        else {
            Write-Host "No valid new content needs to be added to the hosts file."
        }
    }

    # Main script logic
    $downloadPath = Join-Path -Path $env:TEMP -ChildPath 'hosts.txt'
    # Download the file and proceed if successful
    if (Download-File -Url $DownloadUrl -Destination $downloadPath) {
        Merge-HostsFile -DownloadPath $downloadPath -HostsPath $HostsFilePath
    }
    else {
        Write-Host "File download failed."
    }
    # Clean up by removing the downloaded file
    Remove-Item -Path $downloadPath -Force
}

# Call the function to start the installation process
Install-Githubhosts
