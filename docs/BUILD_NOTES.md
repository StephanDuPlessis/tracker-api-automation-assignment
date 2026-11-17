# Build Notes

Running record of decisions, trade-offs, issues and AI usage while building this assignment. Source for SOLUTION.md, README.md and the video.

## Decisions

| # | Decision | Why | Alternatives / trade-off |
|---|----------|-----|--------------------------|
| D1 | Test runner: Postman + Newman | Named in the brief; headless; JUnit reporter built in; easy to run in Azure DevOps | ReadyAPI (heavier setup); code-based frameworks such as C# or Playwright (outside the stated tools; asked the recruiter) |
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

## Assumptions (contract ambiguities)

- A1: `$filter` dates: see D8.
- A2: Status codes: 401 missing or invalid key, 400 validation errors, 404 unknown id, 409 duplicate id, 201 on successful POST.
- A3: `$top` limits: see D10.
- Questions sent to the recruiter (date format and status codes; other frameworks): status pending. Proceeding on the assumptions above.

## Test plan coverage

(Filled in as the collection is built: folder, cases, what each proves.)

## AI usage

| Date | Tool | What I used it for | What I reviewed / corrected / rejected |
|------|------|--------------------|-----------------------------------------|
| 17 Nov | Claude (chat) | Planning, test plan draft, architecture options, decision log | Chose Postman over code-based frameworks; adjusted the plan to my setup (LocalDB, no Docker locally) |
| | GitHub Copilot (agent mode, VS Code) | Code generation for scripts, API, collection and pipeline | (Add an entry for each piece: what I changed or rejected) |
| 17 Nov | GitHub Copilot (agent, VS Code) | Generated db/01_schema.sql, 02_seed.sql and 99_cleanup.sql from my instructions file | Read all three scripts and checked the types, the Positions-to-Devices foreign key and the child-first cleanup order. Ran them against LocalDB: schema twice (idempotent), seed, cleanup, seed again, then confirmed 5/4/3 positions per device and 12 in total, matching the seed header. No changes needed to the generated scripts. Chose the database name PositionsDb (D11) and the required-field and device rules (D12, D13) myself. Also had the scripts reviewed in Claude chat. |

## Issues hit and fixes

(Anything that broke and how it was solved. Good material for the video.)

## Video talking points

- Architecture overview
- Why Postman + own target API
- Data setup and cleanup flow
- Pipeline walkthrough
- Trade-offs and what I'd do with more time