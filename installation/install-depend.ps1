# Required software to install scoop.
function Install-Depend {

    # --- Added: Smart Proxy Detection Logic ---
    Write-Host "Determining fastest Git proxy URL by running get-fastestgiturl.ps1..." -ForegroundColor Cyan
    
    # Default fallback address
    $GHPROXY = 'https://gh-proxy.com'

    try {
        # Check if the speed test script exists
        if (Test-Path "$PSScriptRoot\get-fastestgiturl.ps1") {
            # Load the script
            . "$PSScriptRoot\get-fastestgiturl.ps1" -ErrorAction Stop    
            
            # Call the speed test function (New version automatically uses TCP serial test in no-Git environment)
            $FastestGitUrl = Get-FastestGitUrl
            
            if (-not [string]::IsNullOrWhiteSpace($FastestGitUrl)) {
                Write-Host "Successfully found fastest URL: $FastestGitUrl" -ForegroundColor Green
                $GHPROXY = $FastestGitUrl
            }
            else {
                Write-Warning "Speed test returned no result. Using default fallback."
            }
        } else {
             Write-Warning "get-fastestgiturl.ps1 not found. Skipping speed test."
        }
    }
    catch {
        Write-Warning "Failed to run proxy detection. Error: $_. Falling back to default."
    }

    Write-Host "Using Proxy URL: $GHPROXY" -ForegroundColor Yellow
    # --- Detection Logic End ---

    #$GSUDO = "$GHPROXY/https://raw.githubusercontent.com/duzyn/scoop-cn/refs/heads/master/bucket/gsudo.json"
    #$7ZIP = "$GHPROXY/https://raw.githubusercontent.com/duzyn/scoop-cn/refs/heads/master/bucket/7zip.json"
    #$GIT = "$GHPROXY/https://raw.githubusercontent.com/duzyn/scoop-cn/refs/heads/master/bucket/git.json"
    $GSUDO = "https://cdn.jsdelivr.net/gh/duzyn/scoop-cn@master/bucket/gsudo.json"
    $7ZIP = "https://cdn.jsdelivr.net/gh/duzyn/scoop-cn@master/bucket/7zip.json"
    $GIT = "https://cdn.jsdelivr.net/gh/duzyn/scoop-cn@master/bucket/git.json"
    $REPO = "https://github.com/ScoopInstaller/Scoop"
    $ICONTEXT = "$GHPROXY/https://raw.githubusercontent.com/duzyn/scoop-cn/master/scripts/7-zip/install-context.reg"
    $UCONTEXT = "$GHPROXY/https://raw.githubusercontent.com/duzyn/scoop-cn/master/scripts/7-zip/uninstall-context.reg"

    # Solve the problem of 7zip error due to lack of directory
    $BucketPath = "$env:USERPROFILE\scoop\buckets\scoop-cn\bucket"
    $ScriptsPath = "$env:USERPROFILE\scoop\buckets\scoop-cn\scripts\7-zip"
    $ZipJsonPath = "$BucketPath\7zip.json"
    $InstallRegPath = "$ScriptsPath\install-context.reg"
    $UninstallRegPath = "$ScriptsPath\uninstall-context.reg"

    if (-not (Test-Path $BucketPath)) {
        New-Item -ItemType "directory" -Path $BucketPath
    }
    if (-not (Test-Path $ScriptsPath)) {
        New-Item -ItemType "directory" -Path $ScriptsPath
    }
    
    # Add progress prompts when downloading files
    if (-not (Test-Path $ZipJsonPath)) {
        Write-Host "Downloading 7zip.json..." -ForegroundColor Gray
        Invoke-RestMethod -Uri $7ZIP -OutFile $ZipJsonPath
    }
    if (-not (Test-Path $InstallRegPath)) {
        Write-Host "Downloading install-context.reg..." -ForegroundColor Gray
        Invoke-RestMethod -Uri $ICONTEXT -OutFile $InstallRegPath
    }
    if (-not (Test-Path $UninstallRegPath)) {
        Write-Host "Downloading uninstall-context.reg..." -ForegroundColor Gray
        Invoke-RestMethod -Uri $UCONTEXT -OutFile $UninstallRegPath
    }

    # Installation.
    # Per-tool dependency check so a single missing tool does not force a full reinstall.
    $toolStatus = @{
        '7z'      = '7-Zip'
        'git'     = 'git'
        'aria2c'  = 'aria2'
        'dark'    = 'dark'
        'gsudo'   = 'gsudo'
        'innounp' = 'innounp'
    }
    $missing = @()
    foreach ($tool in $toolStatus.GetEnumerator()) {
        if (Get-Command $tool.Key -ErrorAction SilentlyContinue) {
            Write-Host "$($tool.Value)  Installed" -ForegroundColor Green
        } else {
            Write-Host "$($tool.Value)  Missing" -ForegroundColor Yellow
            $missing += $tool.Value
        }
    }

    # Only bootstrap (gsudo + 7zip + git) if a required core tool is missing.
    # aria2/dark/innounp are installed later by install-software.ps1, so missing
    # optional tools alone do not trigger the bootstrap path.
    $needsBootstrap = ($missing -contains 'gsudo') -or ($missing -contains '7-Zip') -or ($missing -contains 'git')
    if ($needsBootstrap) {
        Write-Host "Required dependencies missing ($($missing -join ', ')). Starting installation..." -ForegroundColor Yellow
        scoop install ${GSUDO}
        
        # Check if the gsudo command was successfully installed and is available
        if (-not (Get-Command gsudo -ErrorAction SilentlyContinue)) {
            Write-Host "Error: gsudo failed to install successfully or was not added to the PATH environment variable." -ForegroundColor Red
            Write-Host "Please check the scoop output messages to confirm if gsudo was installed correctly." -ForegroundColor Red
            Read-Host "Press Enter to exit the script..."
            exit 1
        }

        # Start a gsudo credentials cache session: the FIRST elevation shows one UAC
        # prompt, every later gsudo call in this console is silent for up to 1 hour
        # of idle time (covers the whole install chain). install-software.ps1 closes
        # the cache with 'gsudo cache off' when the chain finishes.
        Write-Host "Starting gsudo credentials cache (one UAC prompt for this session)..." -ForegroundColor Cyan
        gsudo cache on -d 01:00:00
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to start the gsudo cache session (UAC declined?)." -ForegroundColor Red
            Read-Host "Press Enter to exit..."
            exit 1
        }

        gsudo powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\install-githubhosts.ps1"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to execute 'install-githubhosts.ps1'." -ForegroundColor Red
            gsudo cache off
            Read-Host "Press Enter to exit..."
            exit 1
        }

        gsudo scoop install ${7ZIP} --global
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to execute '7ZIP'." -ForegroundColor Red
            gsudo cache off
            Read-Host "Press Enter to exit..."
            exit 1
        }

        gsudo scoop install ${GIT} --global
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to execute 'GIT'." -ForegroundColor Red
            gsudo cache off
            Read-Host "Press Enter to exit..."
            exit 1
        }
    }
    else {
        if ($missing.Count -gt 0) {
            Write-Host "Optional dependencies will be installed later by install-software.ps1: $($missing -join ', ')" -ForegroundColor Yellow
        }
        else {
            Write-Host "All required dependencies are installed." -ForegroundColor Green
        }
    }
    
    scoop config scoop_repo ${REPO}
    
    # Reload variables in current window.
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Install-Depend

. "$PSScriptRoot\install-bucket.ps1"
