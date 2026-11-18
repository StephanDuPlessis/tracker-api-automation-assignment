Clear-Host
# Starts the Positions API for local testing.
# Settings (API_KEY and the database) come from .env, see .env.example.

# Work from the repo root (the project path below is relative to it), then load the settings.
Set-Location (Join-Path $PSScriptRoot '..')
. "$PSScriptRoot\load-env.ps1"
Import-DotEnv

dotnet run --project src/PositionsApi
