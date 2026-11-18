# Builds the authored collection and runs it with Newman.

# Sets API_KEY from the local, gitignored file (and moves to the repo root).
. "$PSScriptRoot\..\set-env.local.ps1"

# Merge the small source files into one collection.
node tests/authored/build-collection.js

# Run it. The backtick at the end of a line means "the command continues on the next line".
newman run tests/authored/positions.postman_collection.json `
    -e tests/authored/environments/local.postman_environment.json `
    --env-var "apiKey=$env:API_KEY"
