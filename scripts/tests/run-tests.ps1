# Runs the whole API test suite with one command:
# reset the test data, start the API if it is not running, build the collection,
# run it with Newman, write the reports, stop the API, and exit with Newman's result.

# Work from the repo root (the paths below are relative to it), then load the settings from .env.
Set-Location (Join-Path $PSScriptRoot '..\..')
. "$PSScriptRoot\..\load-env.ps1"
Import-DotEnv

# Where the API is. Comes from BASE_URL (the environment or .env), with a local default.
$baseUrl = if ($env:BASE_URL) { $env:BASE_URL } else { 'http://localhost:5080' }

# --- 1. Reset the test data so the suite can be re-run -----------------------------------
# Delete everything with the TEST- and pos-test- prefixes, then reload the seed.
$sqlServer = if ($env:DB_SERVER) { $env:DB_SERVER } else { '(localdb)\MSSQLLocalDB' }
$database = if ($env:DB_NAME) { $env:DB_NAME }   else { 'PositionsDb' }

# Windows authentication when there is no DB_USER (LocalDB). SQL authentication when there is one
# (the pipeline's SQL Server container). -C trusts the container's self-signed certificate.
if ($env:DB_USER) {
    $env:SQLCMDPASSWORD = $env:DB_PASSWORD   # sqlcmd reads the password from here, so it is not on the command line
    $sqlAuth = @('-U', $env:DB_USER, '-C')
}
else {
    $sqlAuth = @('-E')
}

sqlcmd -S $sqlServer -d $database @sqlAuth -i db\99_cleanup.sql
if ($LASTEXITCODE -ne 0) { throw 'Cleanup failed. Is the database reachable?' }

sqlcmd -S $sqlServer -d $database @sqlAuth -i db\02_seed.sql
if ($LASTEXITCODE -ne 0) { throw 'Seed failed.' }

# --- 2. Make sure the API is running ------------------------------------------------------
# True when something answers at the URL. We send no key, so a 401 is a good answer: the API is up.
function Test-ApiUp($url) {
    try {
        Invoke-WebRequest -Uri "$url/positions" -UseBasicParsing -TimeoutSec 2 | Out-Null
        return $true
    }
    catch {
        return ($null -ne $_.Exception.Response)
    }
}

# Start the API only if it is not already running, and remember that we started it.
$startedApi = $null
if (Test-ApiUp $baseUrl) {
    Write-Host "API already running at $baseUrl, using it."
}
else {
    dotnet build src/PositionsApi --configuration Release --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { throw 'API build failed.' }

    # Run the built dll directly (one process), so stopping it really frees the port.
    $startedApi = Start-Process dotnet -ArgumentList 'src\PositionsApi\bin\Release\net9.0\PositionsApi.dll' -PassThru -WindowStyle Hidden

    $deadline = (Get-Date).AddSeconds(30)
    while (-not (Test-ApiUp $baseUrl)) {
        if ($startedApi.HasExited) { throw 'The API stopped right after starting. Is API_KEY set?' }
        if ((Get-Date) -gt $deadline) { throw 'The API did not start within 30 seconds.' }
        Start-Sleep -Milliseconds 500
    }
    Write-Host "API started at $baseUrl."
}

# --- 3. Build the collection and run it ---------------------------------------------------
try {
    # Merge the small source files into one collection.
    node tests/authored/build-collection.js
    if ($LASTEXITCODE -ne 0) { throw 'Building the collection failed.' }

    # Folder for the reports (gitignored). JUnit is for machines (the pipeline), HTML is for people.
    New-Item -ItemType Directory -Force tests\reports | Out-Null

    # The backtick at the end of a line means "the command continues on the next line".
    newman run tests/authored/positions.postman_collection.json `
        -e tests/authored/environments/local.postman_environment.json `
        --env-var "baseUrl=$baseUrl" `
        --env-var "apiKey=$env:API_KEY" `
        --reporters "cli,junit,htmlextra" `
        --reporter-junit-export tests/reports/newman-junit.xml `
        --reporter-htmlextra-export tests/reports/newman-report.html
    $newmanExit = $LASTEXITCODE
}
finally {
    # --- 4. Always stop the API we started, even if the tests failed ------------------------
    # An API we did not start (one a developer is running) is left alone.
    if ($startedApi -and -not $startedApi.HasExited) {
        Stop-Process -Id $startedApi.Id -Force
        Write-Host 'API stopped.'
    }
}

# --- 5. The result ------------------------------------------------------------------------
# Newman's exit code is the script's exit code: 0 when every test passed, 1 when any failed.
exit $newmanExit
