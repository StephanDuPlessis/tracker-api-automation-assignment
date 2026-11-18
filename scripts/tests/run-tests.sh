#!/usr/bin/env bash
# Runs the whole API test suite with one command (the bash version of run-tests.ps1).
# Used on the Linux pipeline agent; it also works in Git Bash on your own machine.

# -e: stop at the first failing command. -u: an unset variable is an error. pipefail: a failure inside a pipe counts.
set -euo pipefail

# Work from the repo root (the paths below are relative to it).
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# --- Settings -------------------------------------------------------------------------------
# Load .env when it exists (the pipeline agent has none, so there it does nothing).
# Same rules as load-env.ps1: skip comments and blank lines, skip blank values,
# and never overwrite a variable that is already set (so pipeline variables win).
# Write NAME=value with no spaces around the "=".
if [ -f .env ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"                          # drop a Windows carriage return, if any
    case "$line" in ''|\#*) continue ;; esac      # blank line or comment
    name="${line%%=*}"                            # everything before the FIRST "="
    value="${line#*=}"                            # everything after it
    [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    [ -n "$value" ] || continue                   # blank values stay unset
    [ -z "${!name:-}" ] || continue               # already set: it wins
    export "$name=$value"
  done < .env
fi

# Where the API is and which database to reset. Linux has no LocalDB, so the default server is a local SQL Server.
BASE_URL="${BASE_URL:-http://localhost:5080}"
DB_SERVER="${DB_SERVER:-localhost}"
DB_NAME="${DB_NAME:-PositionsDb}"

export BASE_URL DB_SERVER DB_NAME   # the API reads these too, so they must be exported

# The API refuses to start without a key, so stop early with a clear message.
: "${API_KEY:?API_KEY is not set. Put it in .env or set it as a pipeline variable.}"

# --- 1. Reset the test data so the suite can be re-run ---------------------------------------
# Delete everything with the TEST- and pos-test- prefixes, then reload the seed.
# Windows authentication when there is no DB_USER (your own machine). SQL authentication when there
# is one (the pipeline's SQL Server container). -C trusts the container's self-signed certificate.
if [ -n "${DB_USER:-}" ]; then
  export SQLCMDPASSWORD="${DB_PASSWORD:-}"   # sqlcmd reads the password from here, so it is not on the command line
  sql_auth=(-U "$DB_USER" -C)
else
  sql_auth=(-E)
fi

sqlcmd -S "$DB_SERVER" -d "$DB_NAME" "${sql_auth[@]}" -i db/99_cleanup.sql \
  || { echo 'Cleanup failed. Is the database reachable?' >&2; exit 1; }

sqlcmd -S "$DB_SERVER" -d "$DB_NAME" "${sql_auth[@]}" -i db/02_seed.sql \
  || { echo 'Seed failed.' >&2; exit 1; }

# --- 2. Make sure the API is running -----------------------------------------------------------
# True when something answers at the URL. We send no key, so a 401 is a good answer: the API is up.
# curl only fails when it cannot connect at all.
api_up() { curl -s -o /dev/null --max-time 2 "$BASE_URL/positions"; }

# Only stop the API if we started it. An API a developer is running is left alone.
api_pid=""
stop_api() {
  if [ -n "$api_pid" ] && kill "$api_pid" 2>/dev/null; then
    echo 'API stopped.'
  fi
}
trap stop_api EXIT      # runs when the script ends for any reason, even a failure

mkdir -p tests/reports  # the reports folder (gitignored); the API log goes there too

if api_up; then
  echo "API already running at $BASE_URL, using it."
else
  dotnet build src/PositionsApi --configuration Release --nologo --verbosity quiet

  # Run the built dll directly in the background (&), and remember its process id ($!).
  dotnet src/PositionsApi/bin/Release/net9.0/PositionsApi.dll > tests/reports/api.log 2>&1 &
  api_pid=$!

  # Wait up to 30 seconds (60 x 0.5) for it to answer.
  for _ in $(seq 1 60); do
    api_up && break
    kill -0 "$api_pid" 2>/dev/null || { echo 'The API stopped right after starting. Is API_KEY set?' >&2; exit 1; }
    sleep 0.5
  done
  api_up || { echo 'The API did not start within 30 seconds.' >&2; exit 1; }
  echo "API started at $BASE_URL."
fi

# --- 3. Build the collection and run it -----------------------------------------------------------
# Merge the small source files into one collection.
node tests/authored/build-collection.js

# JUnit is for machines (the pipeline), HTML is for people. The reports folder already exists (created above).
# "|| newman_exit=$?" keeps the script going when Newman fails, so we can still return its exit code below.
newman_exit=0
newman run tests/authored/positions.postman_collection.json \
  -e tests/authored/environments/local.postman_environment.json \
  --env-var "baseUrl=$BASE_URL" \
  --env-var "apiKey=$API_KEY" \
  --reporters "cli,junit,htmlextra" \
  --reporter-junit-export tests/reports/newman-junit.xml \
  --reporter-htmlextra-export tests/reports/newman-report.html \
  || newman_exit=$?

# --- 4. The result ---------------------------------------------------------------------------------
# Newman's exit code is the script's exit code: 0 when every test passed, 1 when any failed.
# The trap above stops the API we started on the way out.
exit "$newman_exit"
