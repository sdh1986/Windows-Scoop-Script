# Enable TLSv1.2 for compatibility with older clients
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

$DownloadURL = 'https://codeload.github.com/sdh1986/Windows-Scoop-Script/zip/refs/heads/master'

$FilePath = "$env:TEMP\Windows-Scoop-Script-master.zip"
$MasterPath = "$env:TEMP\Windows-Scoop-Script-master"
$ScriptArgs = "$args "

try {
    Invoke-WebRequest -Uri ${DownloadURL} -UseBasicParsing -OutFile ${FilePath} -ErrorAction Stop
}
catch {
    Write-Error $_
    Return
}

if (Test-Path ${FilePath}) {
    Expand-Archive -Path ${FilePath} -DestinationPath ${env:TEMP} -Force
    Set-Location -Path "${MasterPath}"
    Start-Process "${MasterPath}\scoop-install.cmd" ${ScriptArgs} -Wait
    $Item = Get-Item -LiteralPath ${FilePath}
    ${Item}.Delete()
}
