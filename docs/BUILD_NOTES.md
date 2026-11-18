# Build Notes

Running record of decisions, trade-offs, issues and AI usage while building this assignment. Source for SOLUTION.md, README.md and the video.

## Decisions

| # | Decision | Why | Alternatives / trade-off |
|---|----------|-----|--------------------------|
| D1 | Test runner: Postman + Newman | Named in the brief, and the recruiter confirmed that submissions must use Postman/Newman or ReadyAPI as they are used to assess them; headless; JUnit reporter built in; easy to run in Azure DevOps | ReadyAPI (heavier setup); code-based frameworks such as C# or Playwright (asked the recruiter, not accepted) |
| D2 | Target: own .NET 9 minimal API backed by SQL Server | Tests real data setup and cleanup end to end; matches Tracker's C#/.NET stack | Mock or virtual service (simpler, but the DB step would only be a demonstration) |
| D3 | OData: hand-written parser for the subset in the brief | Small, explainable, returns 400 for anything unsupported | Full OData library (heavier, hides behaviour) |
| D4 | Local DB: SQL Server LocalDB. Pipeline: SQL Server Docker container | No Docker needed locally; same scripts and env-var connection string in both places | Docker everywhere (needs Docker Desktop/WSL2 locally) |
| D5 | Test data isolated by prefix (TEST-, pos-test-) | Cleanup by prefix makes the suite re-runnable with no manual steps | Truncate tables (unsafe on shared databases) |
| D6 | Results: JUnit XML (pipeline) + HTML report (humans) | Brief asks for machine-readable and human-readable output | Other formats; JUnit is published natively by PublishTestResults@2 |
| D7 | Config via environment variables (baseUrl, apiKey, DB connection) | Brief requires configurable values; no secrets committed | Hard-coded values |
| D8 | `$filter` dates: accept unquoted (standard OData) and tolerate quoted | The brief shows both forms | Accept only one form (stricter, but risks a mismatch with expectations) |
| D9 | Missing or invalid `X-Api-Key` returns 401 | One simple behaviour to test and defend | 401 for missing and 403 for invalid (conventional, but two behaviours) |
| D10 | `$top=0` returns an empty list; negative, non-numeric or above 1000 returns 400 | Explicit limits; bad input is not hidden | Silently cap at 1000 (friendlier, but hides bad input) |
| D11 | Database name PositionsDb, created by 01_schema.sql if missing | Single consistent name across scripts, API and pipeline | Separate DB per environment (more setup) |
| D12 | All seven position fields are required (SpeedKph and HeadingDeg NOT NULL) | Matches the brief's example; simplest contract | Optional speed and heading (more edge cases) |
| D13 | POST auto-registers an unknown deviceId | Realistic for IoT ingest; tests need no extra device setup; keeps the FK intact | Reject unknown devices with 400 (an extra negative test, but more setup per test) |
| D14 | Timestamps are returned in UTC as whole seconds with a Z suffix (2025-01-15T12:34:56Z), with fractional seconds only when non-zero | Matches the format in the brief, so clients and string comparisons behave as expected | Default .NET output with seven fractional digits (valid ISO 8601, but differs from the brief) |
| D15 | The API refuses to start if API_KEY is missing or blank; the database connection falls back to LocalDB PositionsDb when DB_CONNECTION_STRING is not set (an empty value is rejected) | No secret lives in code, and a missing key fails loudly instead of silently accepting requests | A built-in default key (convenient, but easy to leave in by mistake) |
| D16 | POST returns 400 with a clear message for: id over 100 characters, deviceId over 50, speedKph outside 0 to 1000, headingDeg outside 0 to 360. Both ends of each range are allowed. | My before-fix run showed oversized speed and heading crashed with a 500 (database column overflow) and nonsense values that fit the column were saved with a 201. The id and deviceId limits match the column sizes; the speed and heading ranges are realistic limits. A bad input should be a clear 400, never a 500 or bad data in the table. | Let the database reject it (a 500 and silent bad data, the old behaviour); silently clamp or truncate values (hides bad input, same reasoning as D10) |
| D17 | Every valid prompt given to an AI tool (Copilot, Claude Code, Claude chat) is logged in docs/AI_PROMPTS.md, and the rule is in the shared instructions file so both coding assistants follow it | The brief asks for the prompts used and my reasoning. One file with one rule for all tools avoids gaps and lets me show what I accepted, changed or rejected | Rebuild the log from chat exports at the end (prompts get lost or truncated, as one Copilot export was); put prompts only in this file |

## Assumptions (contract ambiguities)

- A1: `$filter` dates: see D8.
- A2: Status codes: 401 missing or invalid key, 400 validation errors, 404 unknown id, 409 duplicate id, 201 on successful POST.
- A3: `$top` limits: see D10.
- A4 (known limitation): latitude and longitude with more than 6 decimals return 201 and are rounded to 6 decimals when stored, with no error. The POST response echoes the input, so only a GET shows the stored value. Left as is and documented; not part of D16.
- Questions to the recruiter: (1) other frameworks, answered: stick to Postman/Newman or ReadyAPI (D1). (2) Date format in `$filter` and error status codes: not sent / no answer yet. Proceeding on A1 to A3.

## Test plan coverage

(Filled in as the collection is built: folder, cases, what each proves.)

## AI usage

| Step | Tool | What I used it for | What I reviewed / corrected / rejected |
|------|------|--------------------|-----------------------------------------|
| Planning | Claude (chat) | Planning, test plan draft, architecture options, decision log | Chose Postman over code-based frameworks; adjusted the plan to my setup (LocalDB, no Docker locally) |
| SQL scripts | GitHub Copilot (agent, VS Code) | Generated db/01_schema.sql, 02_seed.sql and 99_cleanup.sql from my instructions file | Read all three scripts and checked the types, the Positions-to-Devices foreign key and the child-first cleanup order. Ran them against LocalDB: schema twice (idempotent), seed, cleanup, seed again, then confirmed 5/4/3 positions per device and 12 in total, matching the seed header. No changes needed to the generated scripts. Chose the database name PositionsDb (D11) and the required-field and device rules (D12, D13) myself. Also had the scripts reviewed in Claude chat. |
| API step 1 | GitHub Copilot (agent, VS Code) | Generated the .NET 9 minimal API: API key auth, POST /positions, GET /positions/{id}, repository and models | Read the code and tested six calls by hand (201, 200, 401, 409, 400, 404). Found that timestamps serialised as 56.0000000Z instead of the brief's 56Z, and had it fixed in the JSON converter. A 400 that looked wrong turned out to be PowerShell mangling quotes in curl.exe, not an API bug. Left two code-analyser hints (namespace and GeneratedRegex) alone to keep the code simple. |
| Validation fix (D16) | GitHub Copilot (agent, VS Code) | Added the length and range checks to Position.cs from my prompt (id 100, deviceId 50, speedKph 0 to 1000, headingDeg 0 to 360). I sent the same prompt twice; the second time it found the checks already there and only rebuilt | Found the gap myself with a before-fix test run, wrote the limits in the prompt, and proved the fix with the 14-case check below. |
| D16 check script | Claude Code (VS Code) | Read the D16 code in Position.cs against the handoff notes, and coached me through scripts/validation-check.ps1 in small pieces, each with a reason | Built the script in small pieces that I typed and ran, each before the next. Evidence before the fix (docs/evidence/validation-before-fix.txt) versus after (validation-after-fix.txt): 7 bad inputs now return 400, 6 boundary values and the known-limitation case still return 201. Caught that the handoff file said D16 was not applied when the code already had it (git could not show it because src/ was untracked), the ISE showing a stale copy of the script after an outside edit, and a re-run returning 409 for saved test rows, which led me to decide the script should clean and seed the database itself. Decided to keep the API key in a gitignored local file and have a start script for the API. |

## Issues hit and fixes

- Timestamps first came back as `...56.0000000Z`. Fixed in the shared DateTimeOffset JSON converter so POST and GET both return `...56Z`.
- PowerShell mangled the quotes in a JSON body passed to curl.exe, so the API correctly answered "Request body must be valid JSON". Not an API bug. Sending the body from a file fixed it. Worth remembering when writing the run script.
- The first build after the timestamp fix failed because the running API had locked the output files. Stopping the API before building fixed it.
- Validation gap: POST accepted or crashed on bad input. A speedKph of 1000000 and a headingDeg of 10000 returned a 500; speedKph 5000 or -10, headingDeg 500, an id of 101 characters and a deviceId of 51 characters all returned 201 and were saved. Found with a before-fix check, fixed with D16. After the fix all 14 cases in scripts/validation-check.ps1 pass (7 return 400, 7 return 201).
- The handoff file said D16 was not applied, but the code was already in Position.cs. Git could not show it because src/ was untracked. Confirmed by reading the file and building. Lesson: commit src/ so git can be trusted as the source of truth.
- Re-running the check script returned 409 for the cases saved by the previous run. Fixed by making the script run 99_cleanup.sql and 02_seed.sql first, so it is re-runnable with no manual SQL (decision D5).
- The PowerShell ISE kept showing an old copy of the script after it was edited in VS Code, and saving from there would have overwritten the edit. Fixed by closing and reopening the file; edit and run the script in one place only.

## Video talking points

- Architecture overview
- Why Postman + own target API
- Data setup and cleanup flow
- Found a validation gap, fixed it, and proved it with before and after evidence
- Pipeline walkthrough
- Trade-offs and what I'd do with more time