clear
# Starts the Positions API for local testing.
# The dev API key comes from scripts/set-env.local.ps1, which is gitignored.
$envScript = Join-Path $PSScriptRoot 'set-env.local.ps1'

if (-not (Test-Path $envScript)) {
    throw "Missing $envScript. Create it with: `$env:API_KEY = 'your-dev-key'"
}

# Dot-source so the key stays set. The script also moves to the repo root,
# which is why the relative project path below works.
. $envScript
dotnet run --project src/PositionsApi
