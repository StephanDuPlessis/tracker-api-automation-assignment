# Solution

Design, trade-offs and assumptions for the Tracker Connect API automation assignment. How to run everything is in [README.md](README.md). Decisions are numbered D1 to D24 in "Key decisions" below, and the rest of the file refers to them by number.

## Approach

The brief asks for an automated test suite for a Positions API, test data managed in SQL Server, and an Azure DevOps pipeline. No API was provided, so I built a small one to test: a .NET 9 minimal API with SQL Server behind it (D2). That way the database setup and cleanup are real, not a demonstration, and the suite is tested end to end.

| Part | Choice | Why |
|---|---|---|
| Test runner | Postman collection run with Newman | The recruiter confirmed submissions must use Postman/Newman or ReadyAPI. Newman is headless and has JUnit and HTML reporters (D1, D6). |
| API under test | .NET 9 minimal API in `src/PositionsApi` | Matches Tracker's C#/.NET stack (D2). |
| OData | A hand-written parser for only the subset in the brief | Small enough to explain line by line, and anything unsupported returns 400 instead of being half-handled (D3). |
| Database | SQL Server: LocalDB locally, a Docker service container in the pipeline | No Docker needed for a local run, and the same scripts and settings work in both places (D4). A `docker-compose.yml` starts the same SQL Server image for anyone without LocalDB. |
| Settings | Environment variables, loaded from a gitignored `.env` locally | No secrets in the repository (D7, D18). |

## Key decisions

| # | Decision | Why | Alternative I did not take |
|---|---|---|---|
| D1 | Postman with Newman | Named in the brief and confirmed by the recruiter; headless; JUnit reporter built in | ReadyAPI (heavier setup); a code-based framework (not accepted) |
| D2 | Test our own .NET 9 minimal API backed by SQL Server | The data setup and cleanup are real, and it matches Tracker's stack | A mock service (simpler, but the database step would only be a demonstration) |
| D3 | A hand-written OData parser for the subset in the brief | Small and explainable; anything unsupported returns 400 | A full OData library (heavier, hides behaviour) |
| D4 | LocalDB locally, a SQL Server container in the pipeline | No Docker needed for a local run; same scripts and settings in both | Docker everywhere |
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
| D17 | Every prompt that led to real work is logged in `docs/AI_PROMPTS.md` | The brief asks for the prompts and my reasoning | Keep no log and only summarise the AI use at the end |
| D18 | One `.env` file with a committed `.env.example`; the API builds its connection string from the DB variables unless `DB_CONNECTION_STRING` is set | `sqlcmd` cannot use a connection string, so the scripts need the separate variables anyway | Connection string only |
| D19 | Both Postman suites cover the same test cases | Otherwise a difference in size or effort could be a difference in what is tested | Keep them different |
| D20 | Keep a second collection in the plain Postman export style next to the authored suite | Lets me compare the two ways of building a suite with evidence | Only the authored suite |
| D21 | Install `sqlcmd` on the agent from the standalone go-sqlcmd release | The agent has no `sqlcmd`, and the apt package is documented only for older Ubuntu versions | The apt package; running `sqlcmd` inside the container |
| D22 | Pin the .NET 9 SDK with `UseDotNet@2` | The agent has several SDKs and `dotnet` picks the newest | Rely on the image |
| D23 | SQL Server as a service container with the password in a secret variable; cleanup and publishing under `condition: always()` | Nothing is left behind, secrets stay out of logs and the repo, and a failed run still publishes its report | `docker run` in a script; a shared database |
| D24 | `run-tests-2.ps1` is a separate copy of `run-tests.ps1` | The two options are compared, so each has its own complete run script. The cost is about 85 duplicated lines | A shared `common.ps1`; one script with a switch |

## Test strategy

The suite has five folders. The authored suite (the one the pipeline runs) has 139 requests and 311 assertions in a run. Newman's run summary shows 155 requests, because it also counts the GET requests that the helpers send.

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

The secrets `API_KEY` and `DB_PASSWORD` exist only in the pipeline's own variables and are mapped into the steps with `env:`. Plain settings (base URL, server, database name, user) are variables in the YAML.

**Showing a failing run.** The real suite is fully green, so to show what a failure looks like there is a small separate collection, `tests/demo/failure-demo.postman_collection.json`, with two tests that fail on purpose and one that is skipped. It is not part of the suite. The pipeline has a yes/no option, "Also run the failure demo", which is off by default, so pushes behave as above. When someone runs the pipeline by hand with it ticked, the demo runs after the real tests, the pipeline fails on Newman's exit code, and the failures appear on the Tests tab and in the HTML report. The same demo runs locally with `bash scripts/tests/run-tests.sh demo`.

**Skipped tests.** Newman supports skipping a test (`pm.test.skip`) and shows it as `[skipped]` in the console and the HTML report. Its JUnit export, however, writes a skipped test as an ordinary passing test, so the pipeline's Tests tab counts it as passed. For that reason the real suite has no skipped tests, and the one in the demo is labelled clearly.

## Assumptions and behaviours the brief does not state

The brief does not say what unsupported or invalid input returns, and it does not fix the date format in `$filter` or the error status codes. For each I chose one simple rule and tested it. These are the assumptions.

- **Status codes**: 401 for a missing or invalid key (D9), 400 for validation errors, 404 for an unknown id, 409 for a duplicate id, 201 for a successful POST. Every error body is `{ "error": "..." }`, including the 404.
- **Unsupported input**: anything outside the OData subset in the brief returns 400, never a guess.
- **`$filter` dates**: accepted unquoted (standard OData) and also quoted (D8).
- **`$top`**: 0 returns an empty list; 1 to 1000 is allowed; negative, non-numeric or above 1000 returns 400 (D10).
- **Order**: without `$orderby`, results come back by `OccurredAt` ascending, then `Id` ascending, so the order is always predictable.
- **Fields**: all seven position fields are required (D12). A POST with an unknown `deviceId` registers the device (D13). Limits: id up to 100 characters, deviceId up to 50, speedKph 0 to 1000, headingDeg 0 to 360, both ends allowed (D16).
- **Timestamps** are returned in UTC as whole seconds with a `Z` suffix, with fractions only when they are not zero (D14). POST echoes `occurredAt` converted to UTC.
- **Device matching ignores letter case**, because that is SQL Server's default collation. A test pins this.
- **Option names**: `IQueryCollection` matches keys without regard to case, so `$TOP=5` is accepted as `$top=5`. Values are case-sensitive: `$count=True` returns 400.

## Deviations from the contract

The brief says to document any deviation I introduce on purpose and why. The API follows the contract for the three resources, the `X-Api-Key` header, the OData options and the response shape. These are the places where it goes beyond the contract or differs from the examples in the brief:

| Deviation | Why |
|---|---|
| **Extra input limits** on POST: id up to 100 characters, deviceId up to 50, speedKph 0 to 1000, headingDeg 0 to 360. The contract gives ranges only for latitude and longitude. | The columns have fixed sizes, and without limits oversized values crashed with a 500 while nonsense values were saved (D16). A clear 400 is better than either. |
| **All seven fields are required.** | The example body has all seven, and the contract does not mark any as optional (D12). |
| **`$top` above 1000 returns 400**, and a negative or non-numeric `$top` returns 400. The contract sets no maximum. | An explicit limit is easier to test and defend than silently capping (D10). |
| **Anything outside the supported OData subset returns 400**, for example an unknown option, an unsupported operator or a malformed filter. | The contract does not say what unsupported input returns. One rule is simple to test (D3). |
| **Dates in `$filter` are accepted quoted and unquoted.** | The brief's description shows quotes (`occurredAt ge '...'`) and its example request shows none (D8). |
| **A POST with an unknown `deviceId` creates the device.** | Realistic for device ingest, and the tests need no extra setup for each new device (D13). |
| **Timestamps are returned in UTC** as whole seconds with a `Z`, even when the request used another offset (D14). | Matches the format in the brief's examples, so string comparisons behave. |
| **Latitude and longitude are stored with 6 decimals, speed and heading with 2.** More decimals are rounded, not rejected. | A fixed column precision. See "Known limitations" below. |
| **Every error body is `{ "error": "..." }`**, including the 404. | The contract does not define an error shape. One shape keeps the assertions simple. |
| **Test device ids carry a `TEST-` prefix** (for example `TEST-D-10001`), not `D-10001` as in the brief's examples. | The prefix is how cleanup finds the test data without touching anything else (D5). |
| **The target is an API I wrote**, not a service provided with the brief. | The brief allows a lightweight local target, and it makes the SQL setup and cleanup real (D2). |

## Known limitations

These are deliberate or known, and documented rather than hidden.

- Latitude and longitude with more than 6 decimals are accepted and rounded to 6 when stored, with no error. The POST response echoes the input, so only a GET shows the stored value.
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
| Files to edit | about 200 small source files (including `helpers.js`, 110 lines), plus `build-collection.js` (63 lines) | 1 file (4,090 lines) |
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

`run-tests.ps1` and `run-tests-2.ps1` are about 97 lines each. I kept them as separate copies on purpose so the options compare like for like. The only differences are the build step, the collection and environment files, and the report names. The cost is about 85 duplicated lines.

### Which one the pipeline runs

Option A. Small source files give readable diffs and a shared helpers file, and I accepted the build step in exchange. The export is the kept alternative, and it would be the simpler choice for a team that does not want a build step.

### Not measured

How long each option took to write, and run time (I timed both locally at about 18 seconds for A and 15 for B, including starting the API, so there is no real difference).

## How I used AI tools

**What I used AI for.** Three tools: Claude in chat for planning and the decision log; GitHub Copilot in VS Code for the SQL scripts, the first version of the API and the validation limits (D16); and Claude Code in VS Code for the test suites, the run scripts, the pipeline and the documentation. For many parts I copied the code in small pieces and went through every line with the AI's explanation so I could explain it, for example the pipeline file, the run scripts and the first requests of each kind. I kept the log of prompts as I went and tidied it at the end from the chat exports.

**What I reviewed and ran.** I read and ran what the tools produced: the SQL scripts against LocalDB (schema twice, seed, cleanup, seed again, with the counts checked), the API with hand-made requests, and every suite and run script before relying on it.

**What I corrected.**
- The API returned timestamps as `...56.0000000Z` instead of the brief's `...56Z`. I found it in my own hand tests and had it fixed (D14).
- I found the validation gap myself with a before-fix test run (oversized values returned a 500, nonsense values were saved), had Copilot add the limits and proved the fix with before and after evidence in `docs/evidence/` (D16).
- Claude chat predicted that a very long id or deviceId would cause a 500. My check showed they were silently truncated and saved with a 201 (`docs/evidence/truncation-check.txt`), so that prediction was wrong.
- A real API key had been committed by mistake in `.env.example`. I replaced it with a placeholder and rotated the key. The pipeline's secret was a different value and was never exposed.

**What I rejected.**
- Claude Code proposed moving the shared steps of the two run scripts into one common file. I rejected it and kept two separate scripts, because the scripts are part of the comparison of the two Postman options (D24).
- I left two code-analyser hints in the API alone (a namespace style and `GeneratedRegex`), because the plainer code is easier for me to explain.
- I chose a hand-written parser over a full OData library (D3), and I do not let the AI tools commit for me: I review and commit myself.

Every prompt that led to real work is logged in [docs/AI_PROMPTS.md](docs/AI_PROMPTS.md), with what the AI gave, what I did with it and the outcome.

## Decided not to do

- **A full OData library**: heavier and hides the behaviour I want to test (D3).
- **Unit tests for the API**: the brief asks for API automation, not tests of the API's own code. The Postman suite tests the behaviour from the outside, including the hand-written OData parser through the results a client sees.
- **Swagger and logging**: not needed to test the API. The contract is fixed by the brief and pinned by the tests, and failures are already visible in the Newman, JUnit and HTML reports. Both would add code outside the brief.
- **A 415 for a wrong Content-Type**, and **handling a database outage** with a friendly error: edge cases outside the brief.
- **A shared run-script file** for the two PowerShell scripts: they are kept separate on purpose so the two Postman options compare like for like (D24).
- **A Dockerfile, and running the API in a container.** The database uses the official SQL Server image as it is, so there is nothing to build, and `docker-compose.yml` only starts that image. The API runs directly with `dotnet`, locally and on the pipeline agent. Containerising it would add a Dockerfile and a second compose service that the brief does not ask for, and that is more to explain and maintain.
