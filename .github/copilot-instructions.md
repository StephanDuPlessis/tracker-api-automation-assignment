# Project context

Take-home assignment for Tracker Connect (API Automation Tester). Goal: automated API test suite for a telematics Positions API, SQL Server test data management, and an Azure DevOps YAML pipeline. Deliverables: this repo (code, README.md, SOLUTION.md) plus a Loom video. The author must be able to explain every line, so keep code simple, readable and commented where the "why" is not obvious.

# Stack and decisions

- Test runner: Postman collection run headless with Newman. Reporters: cli, junit, htmlextra.
- Target API under test: our own .NET 9 minimal API in `src/PositionsApi`, backed by SQL Server.
- OData: hand-written parser for only the subset in the brief. Anything else returns 400. Do not add a full OData library.
- Database: SQL Server. Local = LocalDB (`(localdb)\MSSQLLocalDB`). Pipeline (Linux agent) = SQL Server Docker service container. Optional `docker-compose.yml`.
- SQL scripts run with `sqlcmd` from the run script.
- Config only via environment variables: `BASE_URL`, `API_KEY`, `DB_CONNECTION_STRING` (and DB credentials where needed). Never commit secrets. Provide `.env.example` with placeholders.
- Test data isolation: all test data uses the prefixes `TEST-` (device ids) and `pos-test-` (position ids). Cleanup deletes by prefix so the suite is re-runnable with no manual steps.
- Host is Windows with PowerShell. Provide `scripts/tests/run-tests.ps1` and a bash equivalent for the pipeline agent.

# API contract

- Auth: header `X-Api-Key`.
- `POST /positions` body: id, deviceId, occurredAt (ISO 8601), latitude [-90..90], longitude [-180..180], speedKph, headingDeg.
- `GET /positions/{id}`.
- `GET /positions` with OData: `$filter` (eq on deviceId; occurredAt ge/le; startswith and contains on deviceId), `$orderby=occurredAt asc|desc`, `$top`, `$count=true`.
- Response shape: `{ "value": [...], "@odata.count": N }` (`@odata.count` only when `$count=true`).

# Agreed behaviour (assumptions, documented in SOLUTION.md)

- Dates in `$filter`: accept unquoted (standard OData) and also tolerate quoted values.
- Missing or invalid `X-Api-Key`: 401.
- Validation errors (out-of-range lat/lon, bad timestamp, missing or wrong-type fields, unsupported or malformed `$filter`, invalid `$top`): 400.
- Unknown id: 404. Duplicate id on POST: 409. Successful POST: 201.
- `$top=0`: 200 with empty list. Negative or non-numeric `$top`: 400. `$top` above 1000: 400.

# Planned layout

```
README.md  SOLUTION.md  docker-compose.yml  azure-pipelines.yml  .env.example
docs/notes/BUILD_NOTES.md
src/PositionsApi/
db/01_schema.sql  db/02_seed.sql  db/99_cleanup.sql
tests/positions.postman_collection.json  tests/local.postman_environment.json
scripts/tests/run-tests.ps1  scripts/tests/run-tests.sh  scripts/tests/validation-check.ps1
```

Schema: `Devices` (DeviceId PK, Name) and `Positions` (Id PK, DeviceId FK, OccurredAt datetimeoffset, Latitude, Longitude, SpeedKph, HeadingDeg), index on (DeviceId, OccurredAt).

# Seed data

3 devices (`TEST-D-10001`, `TEST-D-10002`, `TEST-X-20001`), about 12 positions over 2 days with known timestamps so counts and ordering are deterministic.

# Test plan (Postman folders)

1. Auth: missing key, invalid key, valid key.
2. POST: valid; each required field missing; lat/lon at and just beyond bounds; invalid timestamps; wrong types; duplicate id.
3. GET by id: found, not found, round trip after POST.
4. OData: eq on deviceId; date range with inclusive boundaries; combined device and range; startswith; contains; orderby asc and desc verified; $top of 0, 1, 5, above dataset size, negative, non-numeric, above 1000; $count present and absent; unsupported filter; malformed filter; quoted and unquoted dates.
5. Data integrity: created position appears in queries; `@odata.count` matches total matching rows even when `$top` limits items; sort consistent with timestamps; suite re-runnable.

Use shared helper functions in collection-level scripts to keep assertions maintainable.

# Pipeline requirements

Microsoft-hosted Ubuntu agent. Steps: start SQL Server, apply schema and seed, build and start the API, install Newman and htmlextra reporter, run Newman with env vars and JUnit export, run cleanup under `condition: always()`, `PublishTestResults@2` for JUnit, `PublishPipelineArtifact@1` for the HTML report. Newman's exit code fails the pipeline. baseUrl, API key and DB settings come from pipeline variables or secrets.

# Working rules

- Work in small steps and only do what is asked in the current prompt. After each step, summarise what was built and why in a few lines, and suggest a matching entry for `docs/notes/BUILD_NOTES.md` (decision, issue and fix, or correction). Do not edit BUILD_NOTES.md unless asked.
- Prefer simple, explainable code over clever code. Explain any non-obvious choice.
- Run and verify what you build (`dotnet build`, `sqlcmd`, `newman run`) and report real output.
- Flag anything in the brief that is ambiguous instead of silently guessing.
- Do not commit secrets or generated reports (`tests/reports/` is gitignored).
- Prompt log: every valid prompt the owner gives an AI tool (Copilot, Claude Code, Claude chat) that leads to real work on this repo must be added to `docs/AI_PROMPTS.md`. Valid means it changed, checked or decided something in the project. Skip chit-chat, tool-usage questions and exact duplicates (note a duplicate in one line instead). For each entry record the tool, the prompt (trim long ones with "[...]"), what the AI gave, what the owner did with it and the outcome. Never write that the owner did something the AI did. Never put secrets or personal details in the log. Add the entry in the same task, before finishing.

## Handoff
At the start of a task read `docs/notes/HANDOFF.md`, and at the end update it. Do not edit `docs/notes/BUILD_NOTES.md` unless asked.