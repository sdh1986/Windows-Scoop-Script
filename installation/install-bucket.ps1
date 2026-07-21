# Add available bucket.
function Install-Bucket {

    function Get-InstalledBuckets {
        $buckets = @()
        try {
            $buckets = @(scoop bucket list | ForEach-Object {
                if ($_.PSObject.Properties.Match('Name')) {
                    $_.Name
                } else {
                    $_.ToString()
                }
            } | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
        } catch {
            Write-Warning "Could not get installed bucket list. Error: $_"
        }
        return $buckets
    }

    function Get-InstalledBucketSources {
        $sources = @{}
        try {
            scoop bucket list | ForEach-Object {
                $name = $null
                $source = $null
                if ($_.PSObject.Properties.Match('Name')) {
                    $name = $_.Name
                } else {
                    $name = $_.ToString()
                }
                if ($_.PSObject.Properties.Match('Source')) {
                    $source = $_.Source
                }
                if ($name) {
                    $sources[$name.Trim()] = $source
                }
            }
        } catch {
            Write-Warning "Could not get installed bucket sources. Error: $_"
        }
        return $sources
    }

    function Test-GitRepo([string]$Url) {
        # Lightweight reachability probe for the bucket URL.
        git ls-remote $Url HEAD 2> $null
        return ($LASTEXITCODE -eq 0)
    }

    Write-Host "Adding buckets serially on the main thread." -ForegroundColor Magenta

    Write-Host "Determining fastest Git proxy URL by running get-fastestgiturl.ps1..." -ForegroundColor Cyan
    
    $GHPROXY = $null
    try {
        # Dot-source the script to load the function.
        if (Test-Path "$PSScriptRoot\get-fastestgiturl.ps1") {
            . "$PSScriptRoot\get-fastestgiturl.ps1" -ErrorAction Stop    
            # Call the function and capture the output
            # Increase timeout to 20s because we switched to SERIAL testing for reliability
            $FastestGitUrl = Get-FastestGitUrl -TimeoutSeconds 20
            
            if (-not [string]::IsNullOrWhiteSpace($FastestGitUrl)) {
                Write-Host "Successfully found fastest URL: $FastestGitUrl" -ForegroundColor Green
                $GHPROXY = $FastestGitUrl
            }
            else {
                Write-Warning "Could not determine fastest Git URL. Falling back to default."
            }
        } else {
            Write-Warning "get-fastestgiturl.ps1 not found."
        }
    }
    catch {
        Write-Warning "Failed to load or run 'get-fastestgiturl.ps1'. Error: $_. Falling back to default."
    }

    if ([string]::IsNullOrWhiteSpace($GHPROXY)) {
        # FIXED: Use public proxy as fallback instead of unreachable internal URL
        $GHPROXY = 'https://gh-proxy.com'
        Write-Host "Using fallback URL: $GHPROXY" -ForegroundColor Yellow
    }

    # Data Consolidation: Store bucket names and URLs in a hashtable for easier management.
    $bucketsToAdd = @{
        "main"         = "$GHPROXY/https://github.com/ScoopInstaller/Main"
        "sparkebucket" = "$GHPROXY/https://github.com/sdh1986/sparkebucket"
        "scoop-cn"     = "$GHPROXY/https://github.com/duzyn/scoop-cn"
        "scoop-bucket" = "https://bucket.company.shgryl.com/shendonghu/scoop-bucket"
    }
    
    Write-Host "Checking for existing buckets to manage..."
    $installedBuckets = Get-InstalledBuckets
    $installedSources = Get-InstalledBucketSources
    if ($installedBuckets.Count -gt 0) {
        Write-Host "Found installed buckets: $($installedBuckets -join ', ')" -ForegroundColor Gray
    } else {
        Write-Host "No existing buckets found."
    }

    $proxiedBuckets = @("main", "scoop-cn")

    # Resolve the buckets root directory (needed for snapshot/restore and debris cleanup).
    $bucketsRoot = $null
    if ($env:SCOOP -and (Test-Path (Join-Path $env:SCOOP 'buckets'))) {
        $bucketsRoot = Join-Path $env:SCOOP 'buckets'
    } elseif (Test-Path "$env:USERPROFILE\Scoop\buckets") {
        $bucketsRoot = "$env:USERPROFILE\Scoop\buckets"
    } elseif (Test-Path "$env:USERPROFILE\scoop\buckets") {
        $bucketsRoot = "$env:USERPROFILE\scoop\buckets"
    }

    # Adds a bucket with retry + direct-GitHub fallback. Before each attempt it clears
    # $ProtectedDir if that path exists: it is only ever passed AFTER the original bucket
    # directory has been snapshotted away, so anything sitting there is failed-clone debris.
    function Add-BucketWithFallback {
        param(
            [string]$Name,
            [string]$Url,
            [string]$GHPROXY,
            [string]$ProtectedDir
        )
        $candidates = @($Url)
        if ($Url.StartsWith("$GHPROXY/")) {
            # github.com direct works via the hosts entries installed earlier.
            $candidates += $Url.Substring($GHPROXY.Length + 1)
        }
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            $candidate = $candidates[$i]
            if ($i -gt 0) {
                Write-Host "Trying direct GitHub URL for '$Name': $candidate" -ForegroundColor Cyan
            }
            # Retry the same candidate once before moving to the next one.
            for ($try = 1; $try -le 2; $try++) {
                if ($try -eq 2) {
                    Write-Warning "Retrying add of '$Name' in 3 seconds..."
                    Start-Sleep -Seconds 3
                }
                if ($ProtectedDir -and (Test-Path $ProtectedDir)) {
                    Remove-Item -LiteralPath $ProtectedDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                try {
                    scoop bucket add $Name $candidate -ErrorAction Stop
                    if ($LASTEXITCODE -ne 0) {
                        throw "scoop bucket add failed with exit code $LASTEXITCODE"
                    }
                    return $true
                } catch {
                    Write-Warning "Attempt $try to add '$Name' from '$candidate' failed. Error: $_"
                }
            }
        }
        return $false
    }

    $added = @()
    $updated = @()
    $skipped = @()
    $failed = @()

    Write-Host "Starting serial bucket installation (no background jobs) ..." -ForegroundColor Cyan
    # Background jobs were removed because they proved unreliable for network access in this
    # environment (e.g., DNS resolution failures inside jobs), as documented in get-fastestgiturl.ps1.

    foreach ($bucket in $bucketsToAdd.GetEnumerator()) {
        $bucketName = $bucket.Key
        $bucketUrl = $bucket.Value

        if ($installedBuckets -contains $bucketName) {
            if ($proxiedBuckets -contains $bucketName) {
                # Proxied bucket already installed: force its source onto the fastest proxy.
                # Strategy depends on the bucket type:
                #  - git repo (normal case): re-point the git remote and pull. No re-clone and no
                #    deletion; on any failure the old remote is restored and the bucket keeps working.
                #  - plain directory (scoop-cn pre-seeded by install-depend.ps1, or a zip-bootstrapped
                #    main): must be replaced by a real clone. The old directory is moved OUTSIDE the
                #    buckets dir first (scoop treats every subdir of buckets\ as a bucket, so a
                #    snapshot left inside breaks bucket discovery) and restored on failure.
                if (-not (Test-GitRepo -Url $bucketUrl)) {
                    Write-Warning "New URL for proxied bucket '$bucketName' is not reachable; keeping existing bucket unchanged."
                    $skipped += $bucketName
                    continue
                }
                if (-not $bucketsRoot) {
                    Write-Warning "Could not resolve the buckets root directory; skipping update of '$bucketName'."
                    $skipped += $bucketName
                    continue
                }
                $bucketDir = Join-Path $bucketsRoot $bucketName
                if (-not (Test-Path $bucketDir)) {
                    # Registered but no directory on disk: treat as a fresh add.
                    if (Add-BucketWithFallback -Name $bucketName -Url $bucketUrl -GHPROXY $GHPROXY -ProtectedDir $bucketDir) {
                        $added += $bucketName
                        Write-Host "Successfully added bucket: $bucketName" -ForegroundColor Green
                    } else {
                        $failed += $bucketName
                    }
                    continue
                }
                if (Test-Path (Join-Path $bucketDir '.git')) {
                    $oldRemote = (& git -C $bucketDir remote get-url origin 2>$null)
                    if ($oldRemote -eq $bucketUrl) {
                        Write-Host "Bucket '$bucketName' already uses $bucketUrl; nothing to do." -ForegroundColor Gray
                        $skipped += $bucketName
                        continue
                    }
                    Write-Host "Re-pointing bucket '$bucketName' remote to $bucketUrl ..." -ForegroundColor Yellow
                    & git -C $bucketDir remote set-url origin $bucketUrl
                    & git -C $bucketDir pull 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $updated += $bucketName
                        Write-Host "Successfully updated bucket: $bucketName" -ForegroundColor Green
                    } else {
                        Write-Warning "git pull via the new URL failed for '$bucketName'; restoring previous remote."
                        if ($oldRemote) { & git -C $bucketDir remote set-url origin $oldRemote }
                        $skipped += $bucketName
                    }
                    continue
                }
                # Non-git directory: replace with a real clone, snapshot outside buckets\ first.
                Write-Host "Replacing non-git bucket '$bucketName' with a real clone of $bucketUrl ..." -ForegroundColor Yellow
                $snapshotRoot = Join-Path (Split-Path $bucketsRoot -Parent) 'scoop-bucket-snapshots'
                if (-not (Test-Path $snapshotRoot)) {
                    New-Item -ItemType Directory -Path $snapshotRoot -Force | Out-Null
                }
                $snapshotDir = Join-Path $snapshotRoot "$bucketName-$PID"
                try {
                    Move-Item -LiteralPath $bucketDir -Destination $snapshotDir -ErrorAction Stop
                } catch {
                    Write-Warning "Failed to snapshot bucket '$bucketName' before replacement; leaving it untouched. Error: $_"
                    $skipped += $bucketName
                    continue
                }
                if (Add-BucketWithFallback -Name $bucketName -Url $bucketUrl -GHPROXY $GHPROXY -ProtectedDir $bucketDir) {
                    Remove-Item -LiteralPath $snapshotDir -Recurse -Force -ErrorAction SilentlyContinue
                    $updated += $bucketName
                    Write-Host "Successfully updated bucket: $bucketName" -ForegroundColor Green
                } else {
                    # Total failure: clear any debris and restore the previous directory exactly.
                    if (Test-Path $bucketDir) {
                        Remove-Item -LiteralPath $bucketDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    try {
                        Move-Item -LiteralPath $snapshotDir -Destination $bucketDir -ErrorAction Stop
                        Write-Warning "Replacement of '$bucketName' failed; the previous bucket was restored unchanged."
                    } catch {
                        Write-Warning "Replacement of '$bucketName' failed AND restoring the snapshot at '$snapshotDir' also failed. Error: $_"
                    }
                    $failed += $bucketName
                }
            } else {
                Write-Host "Skipping bucket '$bucketName' (already installed)." -ForegroundColor Gray
                $skipped += $bucketName
            }
        } else {
            # New bucket: add with retry and optional direct-URL fallback.
            if (Add-BucketWithFallback -Name $bucketName -Url $bucketUrl -GHPROXY $GHPROXY -ProtectedDir '') {
                $added += $bucketName
                Write-Host "Successfully added bucket: $bucketName" -ForegroundColor Green
            } else {
                $failed += $bucketName
            }
        }
    }

    Write-Host "`nBucket installation summary:" -ForegroundColor Cyan
    Write-Host "  Added ($($added.Count)): $($added -join ', ')" -ForegroundColor Green
    Write-Host "  Updated ($($updated.Count)): $($updated -join ', ')" -ForegroundColor Green
    Write-Host "  Skipped ($($skipped.Count)): $($skipped -join ', ')" -ForegroundColor Gray
    Write-Host "  Failed ($($failed.Count)): $($failed -join ', ')" -ForegroundColor Red
    if ($failed.Count -gt 0) {
        Write-Host "Hint: Some buckets failed. This script is idempotent; re-run it to try again." -ForegroundColor Yellow
    }
}

# Execute the function to install buckets.
Install-Bucket

# Continue with the rest of your script.
Write-Host "Proceeding to install-software.ps1..."

. "$PSScriptRoot\install-software.ps1"
