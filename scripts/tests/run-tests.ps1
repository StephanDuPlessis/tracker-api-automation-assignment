# Builds the authored collection and runs it with Newman.

# Sets API_KEY from the local, gitignored file (and moves to the repo root).
. "$PSScriptRoot\..\set-env.local.ps1"

# Reset the test data so the suite can be re-run: delete everything with the TEST- and pos-test- prefixes, then reload the seed.
$sqlServer = if ($env:DB_SERVER) { $env:DB_SERVER } else { '(localdb)\MSSQLLocalDB' }
$database = if ($env:DB_NAME) { $env:DB_NAME }   else { 'PositionsDb' }

sqlcmd -S $sqlServer -d $database -E -i db\99_cleanup.sql
if ($LASTEXITCODE -ne 0) { throw 'Cleanup failed. Is the database reachable?' }

sqlcmd -S $sqlServer -d $database -E -i db\02_seed.sql
if ($LASTEXITCODE -ne 0) { throw 'Seed failed.' }


# Merge the small source files into one collection.
node tests/authored/build-collection.js

# Run it. The backtick at the end of a line means "the command continues on the next line".
newman run tests/authored/positions.postman_collection.json `
    -e tests/authored/environments/local.postman_environment.json `
    --env-var "apiKey=$env:API_KEY"
