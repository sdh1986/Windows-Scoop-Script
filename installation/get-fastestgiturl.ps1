function Get-FastestGitUrl {
    # --- Parameters ---
    param(
        [int]$TimeoutSeconds = 20
    )

    # Add your repository URLs here.
    $RepositoryUrls = @(
        "https://gh-proxy.com/https://github.com/ScoopInstaller/Main",
        "https://hk.gh-proxy.com/https://github.com/ScoopInstaller/Main",
        "https://cdn.gh-proxy.com/https://github.com/ScoopInstaller/Main",
        "https://ghproxy.home.sdhsparke.com/https://github.com/ScoopInstaller/Main"
    )

    # --- Script Body ---

    # Ensure TLS 1.2 is enabled for the HTTPS probes on older .NET Frameworks.
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    # Suppress the Invoke-WebRequest progress bar (noticeably slows PS 5.1).
    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $results = @()

    # === UNIFIED PROBE: timed small-file HTTPS GET through each proxy prefix ===
    # Why not git clone or git ls-remote:
    #   - A full clone of the Main repo is tens of MB.
    #   - `git ls-remote` fetches the ENTIRE ref advertisement; on GitHub that includes
    #     thousands of pull/N/head refs, so it is also MBs of data.
    #   Both are heavy enough to be throttled or cut by free proxy services, so the
    #   probe itself would time out even on the fastest reachable proxy.
    # A few-KB raw-file GET exercises the exact same HTTPS path the installer actually
    # uses (zip downloads, raw manifest downloads, git clones) while being too small
    # to be throttled. It also needs no git, so the old no-git TCP branch is gone and
    # the install-time and bucket-time speed tests now measure the same thing.
    # Sustained-transfer survival is handled separately by install-bucket.ps1's
    # retry/fallback/snapshot logic.
    Write-Host "Starting proxy speed test (small-file HTTPS GET, ${TimeoutSeconds}s timeout per URL)..." -ForegroundColor Yellow

    foreach ($url in $RepositoryUrls) {
        # Derive the probe URL: same proxy prefix, but a few-KB raw file instead of the repo.
        $probeUrl = $url -replace '/https://github\.com/ScoopInstaller/Main$', '/https://raw.githubusercontent.com/ScoopInstaller/Main/master/README.md'
        $success = $false
        $elapsed = [double]::MaxValue

        $hostName = ([System.Uri]$url).Host
        Write-Host -NoNewline " -> Checking $hostName ... "

        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri $probeUrl -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
            $stopwatch.Stop()

            if ($response.StatusCode -eq 200) {
                $success = $true
                $elapsed = $stopwatch.Elapsed.TotalSeconds
                Write-Host "OK ($($elapsed.ToString('N2'))s)" -ForegroundColor Green
            } else {
                Write-Host "Failed (HTTP $($response.StatusCode))" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "Failed" -ForegroundColor Red
        }

        $results += [PSCustomObject]@{ Url = $url; Success = $success; TimeInSeconds = $elapsed }
    }

    # === FINAL OUTPUT ===
    $ProgressPreference = $oldProgressPreference

    $bestUrl = $results | Where-Object { $_.Success } | Sort-Object TimeInSeconds | Select-Object -First 1

    if ($bestUrl) {
        Write-Host "`nRecommended Fastest URL:" -ForegroundColor Cyan
        Write-Host " $($bestUrl.Url)" -ForegroundColor Green
        
        $proxyPrefix = $bestUrl.Url -replace "/https://github.com/ScoopInstaller/Main$", ""
        return $proxyPrefix
    } else {
        Write-Host "`n[WARNING] All connections failed. Using default." -ForegroundColor Red
        return $null
    }
}
