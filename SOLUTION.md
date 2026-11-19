# Solution

Design, trade-offs and assumptions for the Tracker Connect API automation assignment. How to run everything is in [README.md](README.md). Decisions are numbered D1 to D24 in "Key decisions" below, and the rest of the file refers to them by number.

## Approach

The brief asks for an automated test suite for a Positions API, test data managed in SQL Server, and an Azure DevOps pipeline. No API was provided, so I built a small one to test: a .NET 9 minimal API with SQL Server behind it (D2). That way the database setup and cleanup are real, not a demonstration, and the suite is tested end to end.

| Part | Choice | Why |
|---|---|---|
| Test runner | Postman collection run with Newman | The recruiter confirmed submissions must use Postman/Newman or ReadyAPI. Newman is headless and has JUnit and HTML reporters (D1, D6). |
| API under test | .NET 9 minimal API in `src/PositionsApi` | Matches Tracker's C#/.NET stack (D2). |
| OData | A hand-written parser for only the subset in the brief | Small enough to explain line by line, and anything unsupported returns 400 instead of being half-handled (D3). |
| Database | SQL Server: LocalDB locally, a Docker service container in the pipeline | No Docker needed on my machine, and the same scripts and settings work in both places (D4). |
| Settings | Environment variables, loaded from a gitignored `.env` locally | No secrets in the repository (D7, D18). |

## Key decisions

| # | Decision | Why | Alternative I did not take |
|---|---|---|---|
| D1 | Postman with Newman | Named in the brief and confirmed by the recruiter; headless; JUnit reporter built in | ReadyAPI (heavier setup); a code-based framework (not accepted) |
| D2 | Test our own .NET 9 minimal API backed by SQL Server | The data setup and cleanup are real, and it matches Tracker's stack | A mock service (simpler, but the database step would only be a demonstration) |
| D3 | A hand-written OData parser for the subset in the brief | Small and explainable; anything unsupported returns 400 | A full OData library (heavier, hides behaviour) |
| D4 | LocalDB locally, a SQL Server container in the pipeline | No Docker needed on my machine; same scripts and settings in both | Docker everywhere |
| D5 | Test data isolated by the prefixes `TEST-` and `pos-test-` | Cleanup by prefix makes the suite re-runnable and safe | Truncate the tables (unsafe on a shared database) |
| D6 | JUnit XML for the pipeline and an HTML report for people | The brief asks for machine-readable and human-readable output | Other formats |
| D7 | Settings come from environment variables | No secrets in the repository | Hard-coded values |
| D8 | `$filter` dates accepted unquoted and quoted | The brief shows both forms | Accept only one form |
| D9 | A missing or invalid key returns 401 | One behaviour to test and defend | 401 for missing and 403 for invalid |
| D10 | `$top=0` returns an empty list; negative, non-numeric or above 1000 returns 400 | Explicit limits; bad input is not hidden | Silently cap at 1000 |
| D11 | Database `PositionsDb`, created by `01_schema.sql` if missing | One name across scripts, API and pipeline | A database per environment |
| D12 | All seven position fields are required | Matches the brief's example; simplest contract | Optional speed and heading |
| D13 | POST registers an unknown `deviceId` | Realistic for device ingest; tests need no extra setup | Reject unknown devices with 400 |
| D14 | Timestamps returned in UTC as whole seconds with a `Z` | Matches the format in the brief | Default .NET output with seven fractional digits |
| D15 | The API refuses to start without `API_KEY` | A missing key fails loudly instead of accepting requests | A built-in default key |
| D16 | POST returns 400 for an id over 100 characters, a deviceId over 50, speedKph outside 0 to 1000 and headingDeg outside 0 to 360 | A before-fix run showed oversized values crashing with a 500 and nonsense values saved with a 201 | Let the database reject it; silently clamp values |
| D17 | Every prompt that led to real work is logged in `docs/AI_PROMPTS.md` | The brief asks for the prompts and my reasoning | Rebuild the log from chat exports at the end |
| D18 | One `.env` file with a committed `.env.example`; the API builds its connection string from the DB variables unless `DB_CONNECTION_STRING` is set | `sqlcmd` cannot use a connection string, so the scripts need the separate variables anyway | Connection string only |
| D19 | Both Postman suites cover the same test cases | Otherwise a difference in size or effort could be a difference in what is tested | Keep them different |
| D20 | Keep a second collection in the plain Postman export style next to the authored suite | Lets me compare the two ways of building a suite with evidence | Only the authored suite |
| D21 | Install `sqlcmd` on the agent from the standalone go-sqlcmd release | The agent has no `sqlcmd`, and the apt package is documented only for older Ubuntu versions | The apt package; running `sqlcmd` inside the container |
| D22 | Pin the .NET 9 SDK with `UseDotNet@2` | The agent has several SDKs and `dotnet` picks the newest | Rely on the image |
| D23 | SQL Server as a service container with the password in a secret variable; cleanup and publishing under `condition: always()` | Nothing is left behind, secrets stay out of logs and the repo, and a failed run still publishes its report | `docker run` in a script; a shared database |
| D24 | `run-tests-2.ps1` is a separate copy of `run-tests.ps1` | The two options are compared, so each has its own complete run script. The cost is about 70 duplicated lines | A shared `common.ps1`; one script with a switch |

## Test strategy

The suite has five folders. The authored suite (the one the pipeline runs) has 139 requests and 311 assertions in a run.

| Folder | Requests | What it proves |
|---|---|---|
| 1. Auth | 3 | A missing key, an invalid key and a valid key. |
| 2. POST | 54 | A valid create; each required field missing; latitude and longitude at and just beyond their bounds; invalid timestamps; wrong types; the length and range limits (D16); a duplicate id. |
| 3. GET by id | 8 | Found, not found, and a round trip after a POST. |
| 4. OData | 59 | `eq` on deviceId; date ranges with inclusive boundaries; combined device and range; `startswith` and `contains`; `$orderby` ascending and descending checked against the timestamps; `$top` of 0, 1, 5, above the dataset size, negative, non-numeric and above 1000; `$count` present and absent; unsupported and malformed filters; quoted and unquoted dates. |
| 5. Data integrity | 15 | A created position appears in queries; `@odata.count` matches the total matching rows even when `$top` limits the items; sort order is consistent; the seeded data is untouched by the earlier folders. |

Shared assertion helpers (`expectStatus`, `expectError`, `expectPosition`, `expectIds`, `expectCount` and so on) live in one place, so a rule such as "an error body is `{ "error": "..." }`" is written once. The POST folder uses its own device (`TEST-P-40001`) and the integrity folder uses `TEST-I-50001`, so the seeded counts stay exact.

## Test data management

- **Schema** (`db/01_schema.sql`): `Devices` and `Positions` with a foreign key and an index on `(DeviceId, OccurredAt)`. It creates the database if it is missing and can be run again safely.
- **Seed** (`db/02_seed.sql`): 3 devices and 12 positions (5, 4 and 3 per device) on 15 and 16 January 2025, with known timestamps so counts and ordering are the same on every run.
- **Isolation**: all test data uses the prefixes `TEST-` for device ids and `pos-test-` for position ids (D5).
- **Cleanup** (`db/99_cleanup.sql`): deletes by those prefixes, so it never touches data that is not test data.
- **Re-runnable**: the run scripts clean and then seed before every run, so the suite runs again straight away with no manual steps. The pipeline also cleans up at the end of a run, even when tests fail.

## The pipeline

`azure-pipelines.yml` runs on every push to `main` on a Microsoft-hosted Ubuntu agent, in about 1.5 minutes:

1. Start SQL Server 2022 as a service container (D23).
2. Pin the .NET 9 SDK (D22), install `sqlcmd` (D21), Newman and the htmlextra reporter, all at fixed versions held in one place at the top of the file.
3. Wait for SQL Server, then apply the schema and seed.
4. Run `scripts/tests/run-tests.sh`, which builds and starts the API, runs Newman and exits with Newman's exit code. A failed test fails the pipeline.
5. Always (`condition: always()`): clean up the data, publish the JUnit results to the Tests tab and publish the HTML report as an artifact.

The secrets `API_KEY` and `DB_PASSWORD` exist only in the pipeline's own variables and are mapped into the steps with `env:`. Plain settings (server, database name, user) are in the YAML. Not tried: a deliberately failing pipeline run. A failing local run gives exit code 1, which is what fails the pipeline.

## Assumptions and behaviours the brief does not state

The brief does not say what unsupported or invalid input returns, so I chose one simple rule and tested it. I asked the recruiter about the date format in `$filter` and the error status codes and did not get an answer, so I proceeded on these assumptions.

- **Status codes**: 401 for a missing or invalid key (D9), 400 for validation errors, 404 for an unknown id, 409 for a duplicate id, 201 for a successful POST. Every error body is `{ "error": "..." }`, including the 404.
- **Unsupported input**: anything outside the OData subset in the brief returns 400, never a guess.
- **`$filter` dates**: accepted unquoted (standard OData) and also quoted (D8).
- **`$top`**: 0 returns an empty list; 1 to 1000 is allowed; negative, non-numeric or above 1000 returns 400 (D10).
- **Order**: without `$orderby`, results come back by `OccurredAt` ascending, then `Id` ascending, so the order is always predictable.
- **Fields**: all seven position fields are required (D12). A POST with an unknown `deviceId` registers the device (D13). Limits: id up to 100 characters, deviceId up to 50, speedKph 0 to 1000, headingDeg 0 to 360, both ends allowed (D16).
- **Timestamps** are returned in UTC as whole seconds with a `Z` suffix, with fractions only when they are not zero (D14). POST echoes `occurredAt` converted to UTC.
- **Device matching ignores letter case**, because that is SQL Server's default collation. A test pins this.
- **Option names**: `IQueryCollection` matches keys without regard to case, so `$TOP=5` is accepted as `$top=5`. Values are case-sensitive: `$count=True` returns 400.

## Known limitations

These are deliberate or known, and documented rather than hidden.

- Latitude and longitude with more than 6 decimals are accepted and rounded to 6 when stored, with no error. The POST response echoes the input, so only a GET shows the stored value (A4).
- The filter parser splits on the text ` and `, so a device id that contains ` and ` inside quotes gives 400.
- A raw `+02:00` in a URL does not work, because `+` means a space in a query string. A client has to send `%2B`, so no test covers a raw one.
- The items and the `@odata.count` come from two separate queries, so a write between the two could make them disagree. Tests run one request at a time, so this does not show up.
- The Content-Type header is not checked, and a database outage returns a plain 500.

## Two ways to build the Postman suite

I built the same test plan twice to compare two ways of authoring a Postman collection.

- **Option A (authored):** the collection is generated from many small source files, one per request. A build script, `build-collection.js`, merges them into `tests/authored/positions.postman_collection.json`. This is the suite the pipeline runs.
- **Option B (Postman export):** a single collection file made the way Postman normally saves one. Test scripts sit inside each request, the shared helpers live in a collection-level script, and request bodies are inline. It lives in `tests/postman-export/`.

Both cover the same test cases, and both were verified against a freshly reset database.

| | A: authored | B: Postman export |
|---|---|---|
| Requests | 139 | 145 |
| Assertions in a run | 311 | 323 |
| Files to edit | 204 small source files, plus `helpers.js` (110 lines) and `build-collection.js` (63 lines) | 1 file (4,090 lines) |
| Build step | Yes: `node build-collection.js` before every run | None |
| Generated file in git | Yes, 6,092 lines, never edited by hand | Not applicable, the one file is the source |
| Where the shared helpers live | `helpers.js`, a normal JS file | A collection-level script inside the JSON |
| Run script | `run-tests.ps1` and `run-tests.sh` (used by the pipeline) | `run-tests-2.ps1` (not used by the pipeline) |

The request and assertion counts differ a little because wording and some test variants differ. The coverage is the same.

### What was easier in each

**Option A (authored)**

- A change to one request is a small, readable diff in a single file, so code review is easy.
- The helpers are a normal `.js` file, so an editor can highlight and check them. In B the same code is text inside JSON.
- Request bodies are plain files, so a body change does not touch the test code.

**Option B (export)**

- It needs no build step or extra tooling beyond Postman and Newman. Anyone can open it in Postman and run it.
- Everything is in one file, so there is nothing to explain about layout or a build.
- It matches how most teams actually work with Postman.

### What was harder in each

**Option A (authored)**

- 204 files and a build step are more to explain and keep consistent.
- The generated collection is committed, so a reviewer sees a very large file change alongside the real source change.

**Option B (export)**

- Every change touches one 4,000-line JSON file where scripts are stored as quoted strings, so diffs are hard to read.
- Test scripts live inside the JSON, so an editor will not check them.
- Merge conflicts are more likely if two people edit it.

### The two run scripts

`run-tests.ps1` and `run-tests-2.ps1` are about 97 lines each. I kept them as separate copies on purpose so the options compare like for like. The only differences are the build step, the collection and environment files, and the report names. The cost is about 70 duplicated lines.

### Which one the pipeline runs

Option A. Small source files give readable diffs and a shared helpers file, and I accepted the build step in exchange. The export is the kept alternative, and it would be the simpler choice for a team that does not want a build step.

### Not measured

How long each option took to write, and run time (both finish in about 15 seconds locally, so there is no real difference).

## How I used AI tools

I used three AI tools: Claude in chat for planning and the decision log, GitHub Copilot in VS Code for the SQL scripts, the first version of the API and the validation limits (D16), and Claude Code in VS Code for the test suites, the run scripts, the pipeline and the documentation. I read, ran and tested what they produced, and several things came from my own checks rather than a suggestion: the validation gap (found with a before-fix test, with evidence in `docs/evidence/`), the timestamp format mismatch, and a real API key that I had committed by mistake in `.env.example`, which I replaced and rotated. For some parts I typed the code myself in small pieces so I could explain it, for example the pipeline file and the first requests of each kind.

Every prompt that led to real work is logged in [docs/AI_PROMPTS.md](docs/AI_PROMPTS.md), with what the AI gave, what I did with it and the outcome.
## Decided not to do

- **A full OData library**: heavier and hides the behaviour I want to test (D3).
- **Unit tests for the API**: the brief asks for API automation, and the Postman suite covers the behaviour from the outside.
- **Swagger and logging**: not needed to test the API, and more to explain.
- **A 415 for a wrong Content-Type**, and **handling a database outage** with a friendly error: edge cases outside the brief.
- **A shared run-script file** for the two PowerShell scripts: they are kept separate on purpose so the two Postman options compare like for like (D24).
