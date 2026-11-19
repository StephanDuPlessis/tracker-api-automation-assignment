# Tracker API automation assignment

An automated test suite for a telematics Positions API. It has four parts:

- **The API under test** (`src/PositionsApi`): a .NET 9 minimal API backed by SQL Server, with a small hand-written OData parser.
- **The tests**: a Postman collection run headless with Newman. There are two versions of it, compared in [SOLUTION.md](SOLUTION.md).
- **Test data**: SQL scripts in `db/` that create the schema, seed known data and clean up after a run.
- **The pipeline** (`azure-pipelines.yml`): builds and starts the API, runs the tests on every push to `main`, and publishes the results.

For the design, the trade-offs and the assumptions, read [SOLUTION.md](SOLUTION.md).

## What the API does

All requests need the header `X-Api-Key`.

| Request | What it does |
|---|---|
| `POST /positions` | Creates a position (`id`, `deviceId`, `occurredAt`, `latitude`, `longitude`, `speedKph`, `headingDeg`). 201 on success, 409 if the id exists, 400 if invalid. |
| `GET /positions/{id}` | Returns one position, or 404. |
| `GET /positions` | Lists positions. Supports `$filter` (`eq` on `deviceId`, `ge`/`le` on `occurredAt`, `startswith` and `contains` on `deviceId`), `$orderby=occurredAt asc\|desc`, `$top` and `$count=true`. Anything else returns 400. |

A missing or wrong key returns 401. Lists come back as `{ "value": [...], "@odata.count": N }` (the count only when `$count=true`).

## Prerequisites

- [.NET 9 SDK](https://dotnet.microsoft.com/download)
- SQL Server. On Windows the scripts default to LocalDB (`(localdb)\MSSQLLocalDB`). Any SQL Server works if you change the settings below.
- `sqlcmd` on your PATH
- [Node.js](https://nodejs.org/), then Newman and the HTML reporter:

  ```
  npm install --global newman newman-reporter-htmlextra
  ```

  The versions used here are Newman 6.2.3 and newman-reporter-htmlextra 1.23.1.

## Settings

All settings are environment variables. Locally they come from a `.env` file, which is gitignored. Variables that are already set in your terminal win over `.env`.

1. Copy `.env.example` to `.env`.
2. Replace `CHANGE_ME` in `API_KEY` with a key of your own. The API refuses to start without one.

| Variable | Meaning |
|---|---|
| `BASE_URL` | Where the API listens. Default `http://localhost:5080`. |
| `API_KEY` | The key the API requires in `X-Api-Key`. |
| `DB_SERVER`, `DB_NAME` | The database server and name. Defaults: LocalDB on Windows (`localhost` in the bash script) and `PositionsDb`. |
| `DB_USER`, `DB_PASSWORD` | Leave both blank for Windows authentication. Set both for SQL authentication (the pipeline does this). |
| `DB_CONNECTION_STRING` | Optional override for the API's connection string. Leave blank normally. |

Never commit `.env` or put a real key in `.env.example`.

## Create the database (once)

`db/01_schema.sql` creates the `PositionsDb` database and its tables if they do not exist, so it is safe to run again. On Windows with LocalDB:

```
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -i db\01_schema.sql
```

You do not need to seed by hand. Each test run resets the data itself.

## Start the API by hand (how testing started)

Testing began by hand, before any automation existed: start the API, then send requests to it with `curl.exe` or Postman and check the answers. `scripts/start-api.ps1` is the script for that. It loads `.env` and runs the API in the foreground at `BASE_URL` (default `http://localhost:5080`):

```
.\scripts\start-api.ps1
```

Leave it running in one terminal and send requests from another. Stop it with Ctrl+C. To start from exactly the seed data (3 devices, 12 positions), clean and then seed. A test run leaves the positions it created in the database until the next reset, so seeding alone can leave extra rows:

```
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d PositionsDb -i db\99_cleanup.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d PositionsDb -i db\02_seed.sql
```

You do not need this script to run the suite, because `run-tests.ps1` starts and stops the API itself. If the API is already running, the run scripts use that one and leave it running.

## Run the tests

From the repository root, in a normal PowerShell terminal (not the PowerShell ISE):

```
.\scripts\tests\run-tests.ps1
```

The script resets the test data, starts the API if it is not already running (and stops it afterwards), builds the collection, runs Newman, and exits with Newman's exit code: 0 when every test passed, 1 when any failed. It can be run again straight away with no manual steps.

Reports are written to `tests/reports/` (gitignored): a JUnit XML file for machines and an HTML report for people.

On Linux or in Git Bash, use the bash equivalent, which does the same steps and is what the pipeline runs:

```
bash scripts/tests/run-tests.sh
```

### The second option

`scripts/tests/run-tests-2.ps1` runs the Postman-export version of the suite the same way. It has no build step, and its reports are named `newman-export-*`. The pipeline does not run it.

## How test data is kept apart

All test data uses the prefixes `TEST-` for device ids and `pos-test-` for position ids. Cleanup (`db/99_cleanup.sql`) deletes by those prefixes, then the seed (`db/02_seed.sql`) reloads 3 devices and 12 positions over two days, so counts and ordering are the same on every run.

## The pipeline

`azure-pipelines.yml` runs on every push to `main` on a Microsoft-hosted Ubuntu agent. It starts SQL Server as a service container, applies the schema and seed, builds and starts the API, installs Newman and the HTML reporter, and runs `scripts/tests/run-tests.sh`. A failing test fails the pipeline. Cleanup always runs, the JUnit results appear on the Tests tab, and the HTML report is published as an artifact.

The secrets `API_KEY` and `DB_PASSWORD` are stored in the pipeline's own variables, never in the repository.

## Layout

```
src/PositionsApi/                     the API under test
db/                                   01_schema.sql, 02_seed.sql, 99_cleanup.sql
tests/authored/                       the suite the pipeline runs
  src/                                one small file per request, plus helpers.js
  build-collection.js                 merges the small files into one collection
  positions.postman_collection.json   generated, never edited by hand
tests/postman-export/                 the second option: one collection file
tests/reports/                        test reports (gitignored)
scripts/tests/                        run-tests.ps1, run-tests.sh, run-tests-2.ps1
azure-pipelines.yml                   the pipeline
docs/                                 build notes and the AI prompt log
```

To change the authored suite, edit only the files under `tests/authored/src/` and run the tests again, because the run script rebuilds the collection.

## More

- [SOLUTION.md](SOLUTION.md): design, trade-offs and assumptions.
- [docs/BUILD_NOTES.md](docs/BUILD_NOTES.md): decisions, issues and fixes.
- [docs/AI_PROMPTS.md](docs/AI_PROMPTS.md): the prompts used with AI tools.
