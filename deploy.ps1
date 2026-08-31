# Deploy SAM to Hostinger via FTP
# Usage: .\deploy.ps1 index.html    (deploy single file)
#        .\deploy.ps1               (deploy all files)
#
# Uses .NET's FtpWebRequest rather than curl.exe. curl on this machine uses the
# Schannel TLS backend, which has an intermittent-to-persistent bug against this
# host's FTPS server: the file transfers completely, but curl fails to read the
# final "226 Transfer complete" control-channel response and reports exit 56 —
# so a run that LOOKS successful (100% uploaded) can silently not have taken
# effect on the server at all. FtpWebRequest doesn't hit this issue.

$creds = @{}
Get-Content "$PSScriptRoot\.ftp-credentials" | ForEach-Object {
    if ($_ -match "^(\w+)=(.+)$") { $creds[$Matches[1]] = $Matches[2] }
}
$ftpHost    = $creds["FTP_HOST"]
$ftpUser    = $creds["FTP_USER"]
$ftpPass    = $creds["FTP_PASS"]
$ftpPort    = $creds["FTP_PORT"]
$remotePath = $creds["FTP_REMOTE_PATH"]
$local      = $PSScriptRoot
$appUrl     = "https://etccapps.com/apps/sam/"

# Accept the server's cert without validation (matches curl's old --insecure).
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$exclude = @(".git", ".ftp-credentials", "deploy.ps1", "CLAUDE.md", "README.md", "node_modules", "run-tests.js", "package.json", "package-lock.json")

function Should-Exclude($path) {
    foreach ($ex in $exclude) {
        if ((Split-Path $path -Leaf) -like $ex) { return $true }
        if ($path -like "*\$ex\*") { return $true }
    }
    return $false
}

# Creates each intermediate remote directory (mkdir -p equivalent — curl's
# --ftp-create-dirs did this implicitly; FtpWebRequest does not).
function New-RemoteDir($relDir) {
    if (-not $relDir) { return }
    $parts = $relDir -replace "\\", "/" -split "/"
    $built = ""
    foreach ($part in $parts) {
        if (-not $part) { continue }
        $built = if ($built) { "$built/$part" } else { $part }
        $dirUrl = if ($remotePath) { "ftp://${ftpHost}:${ftpPort}/${remotePath}/${built}" } else { "ftp://${ftpHost}:${ftpPort}/${built}" }
        try {
            $req = [System.Net.FtpWebRequest]::Create($dirUrl)
            $req.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
            $req.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
            $req.EnableSsl = $true
            $req.UsePassive = $true
            $resp = $req.GetResponse()
            $resp.Close()
        } catch {
            # Directory already exists (or other benign error) — ignore, mirrors --ftp-create-dirs.
        }
    }
}

function Deploy-File($rel) {
    $localPath  = Join-Path $local $rel
    $relForward = $rel -replace "\\", "/"
    $relDir     = Split-Path $relForward -Parent
    if ($relDir) { New-RemoteDir $relDir }
    $url = if ($remotePath) { "ftp://${ftpHost}:${ftpPort}/${remotePath}/${relForward}" } else { "ftp://${ftpHost}:${ftpPort}/${relForward}" }
    Write-Host "Uploading $rel ..." -ForegroundColor Cyan
    try {
        $req = [System.Net.FtpWebRequest]::Create($url)
        $req.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $req.EnableSsl = $true
        $req.UsePassive = $true
        $req.UseBinary = $true
        $bytes = [System.IO.File]::ReadAllBytes($localPath)
        $req.ContentLength = $bytes.Length
        $stream = $req.GetRequestStream()
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Close()
        $resp = $req.GetResponse()
        $resp.Close()
        Write-Host "  OK" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Bake the deploy date directly into the footer span at deploy time.
# This is the authoritative source the app reads — no JS/Settings sync needed.
function Update-Version {
    $indexPath = Join-Path $local "index.html"
    $content = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
    $deployDate = Get-Date -Format "MMM d, yyyy h:mm tt"
    # Footer span (authoritative): <span id="app-deploy-date">...</span>
    $content = $content -replace '(?<=id="app-deploy-date">)[^<]*', $deployDate
    # Note: the deployed version (<span id="app-version">) is bumped at CHECKPOINT
    # time, not on every deploy — see bump-version.ps1.
    # Keep the Settings input data attribute in sync too
    $content = $content -replace '(inp-deploy-date.*?data-deploy-date=")[^"]*', "`${1}$deployDate"
    # Test environment marker — ensure the home title ends with " - Test"
    # (idempotent: strips any existing " - Test" first, so re-deploys don't stack)
    $content = $content -replace '(>Silent Auction Manager \(SAM\))( - Test)?(</h1>)', '${1} - Test${3}'
    [System.IO.File]::WriteAllText($indexPath, $content, [System.Text.Encoding]::UTF8)
    Write-Host "  Deployed: $deployDate" -ForegroundColor Cyan
}

# Cache-bust the local CSS/JS asset links so browsers pick up changes to
# table.css/toolbar.css/table.js/toolbar.js immediately after deploy, instead
# of serving a stale cached copy. Uses a single epoch-seconds value per
# deploy, stamped onto (or replacing any existing) ?v=... query string.
function Update-CacheBust {
    $indexPath = Join-Path $local "index.html"
    $content = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
    $v = [int][double]::Parse((Get-Date -UFormat %s))
    $assets = @("css/table.css", "css/toolbar.css", "js/table.js", "js/toolbar.js")
    foreach ($asset in $assets) {
        $escaped = [regex]::Escape($asset)
        $content = $content -replace "$escaped(\?v=\d+)?(?=[`"'])", "$asset`?v=$v"
    }
    [System.IO.File]::WriteAllText($indexPath, $content, [System.Text.Encoding]::UTF8)
    Write-Host "  Cache-bust: v=$v" -ForegroundColor Cyan
}

# Single file mode
if ($args.Count -gt 0) {
    if ($args[0] -eq "index.html") { Update-Version; Update-CacheBust }
    Deploy-File $args[0]
    Write-Host "URL: $appUrl" -ForegroundColor Cyan
    exit
}

# Full deploy
Update-Version
Update-CacheBust
Write-Host "Deploying all SAM files to $ftpHost/$remotePath ..." -ForegroundColor Yellow
$files = Get-ChildItem -Path $local -Recurse -File | Where-Object { -not (Should-Exclude $_.FullName) }
$i = 0
foreach ($file in $files) {
    $i++
    $rel = $file.FullName.Substring($local.Length + 1)
    Write-Progress -Activity "Deploying" -Status "$i of $($files.Count): $rel" -PercentComplete (($i / $files.Count) * 100)
    Deploy-File $rel
    # Brief pause between files — rapid back-to-back FTP connections have
    # triggered a transient "450 File unavailable (file busy)" from this host.
    Start-Sleep -Milliseconds 300
}
Write-Host "Deploy complete." -ForegroundColor Green
Write-Host "URL: $appUrl" -ForegroundColor Cyan
