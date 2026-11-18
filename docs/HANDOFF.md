# Handoff

Shared status file for Claude Code and GitHub Copilot. Read it at the start of a session and update it at the end of every task. No dates or times. Git history is the real record; this file is the quick summary.

## Rules for both agents

- Follow `.github/copilot-instructions.md`.
- One small task at a time. Do not start the next step unless asked.
- Never edit `docs/BUILD_NOTES.md` unless asked. Suggest the entry instead.
- Run `git status` first. If it disagrees with this file, trust git.

## Current state (what is done and verified)

- **SQL**: `db/01_schema.sql`, `02_seed.sql`, `99_cleanup.sql` (LocalDB, database `PositionsDb`; seed = 3 devices, 12 positions, 5 / 4 / 3 per device, on 15 and 16 January 2025).
- **API** (`src/PositionsApi`, .NET 9 minimal API): API key auth, `POST /positions`, `GET /positions/{id}`, `GET /positions` with hand-written OData (`ODataQuery.cs`, `ODataParser.cs`, `QueryAsync` in `PositionRepository.cs`). Feature complete and code-reviewed. D16 limits (id over 100 characters, deviceId over 50, speedKph outside 0 to 1000, headingDeg outside 0 to 360 return 400). All errors use `{ "error": "..." }`, including the 404.
- **Postman suite** (the real one): `tests/authored/`. Small source files in `src/<n>-<group>/` (one file per request, `_folder.json` for the folder name, `bodies/` for request bodies as plain files inlined by the build via `rawFile`), `src/base.json` (collection settings), `src/helpers.js` (shared test helpers, inlined via `execFile`), `build-collection.js` merges everything into `positions.postman_collection.json` (generated, committed, never edited by hand), `environments/local.postman_environment.json` (placeholders only: `apiKey` is `CHANGE_ME`). All five folders are done: Auth 3, POST 46, GET by id 5, OData 43, Data integrity 14. Helpers: expectStatus, expectError, expectStored, expectPosition, expectIds, expectCount, expectNoCount, expectSortedByOccurredAt, expectCountMatchesItems. The POST folder uses its own device `TEST-P-40001`, the integrity folder `TEST-I-50001`, so the seeded counts stay intact.
- **Frozen reference**: `tests/postman-export/` is the original Postman export (Auth folder only). It is not run by the pipeline and contains `Date` headers in saved example responses (documented exception).
- **Run script**: `scripts/tests/run-tests.ps1` is verified: resets the DB (cleanup then seed; Windows auth), starts the API if it is not already running and always stops the one it started, builds the collection, runs Newman with reporters cli, junit and htmlextra into the gitignored `tests/reports/`, and exits with Newman's exit code. Last verified result: exit code 0, 127 requests (111 collection requests plus 16 round-trip GETs), 246 assertions, 0 failed, run twice in a row; reports written; API stopped and port 5080 free afterwards.
- **Formatting**: `.editorconfig` and `.gitattributes` added; test sources formatted once (2 spaces, LF).
- **Tools**: Node v26.13.1, npm 11.20.0, Newman 6.2.3 and newman-reporter-htmlextra 1.23.1 installed globally. Postman desktop is installed (authoring and viewing only).
- **Docs**: `docs/AI_PROMPTS.md` is up to date (entries 1 to 25). `docs/BUILD_NOTES.md` has D16, A4 and the validation issues only; the later decisions are not in it yet (suggest entries, write only when asked).

## In progress

- Uncommitted: `scripts/tests/run-tests.ps1` (start and stop the API, reporters, exit code) and this file. Everything else is committed and pushed.
- Under discussion, not started: one settings file. Plan: a committed `.env.example` (BASE_URL, API_KEY, DB_SERVER, DB_NAME, optional DB_USER and DB_PASSWORD), a gitignored `.env`, a small loader in the scripts that sets each value only when the variable is not already set (so pipeline variables win), update `start-api.ps1` and `validation-check.ps1` to use it, then retire `scripts/set-env.local.ps1`. Open question: keep `DB_CONNECTION_STRING` for the API as an optional override and build it from the four DB variables otherwise.
- Local-only (gitignored): `scripts/set-env.local.ps1` (holds the API key and moves to the repo root), `docs/CODE_NOTES.md` and the `docs/notes/` folder. The notes are the owner's private study notes for the video and interview: never commit them and never reference them from committed docs.

## Next steps, in order

1. Commit and push `run-tests.ps1` (suggested message: `Start and stop the API, write reports and return Newman's exit code in the run script`).
2. Settings in one place (see In progress).
3. SQL authentication in the reset step (`DB_USER` and `DB_PASSWORD`, `-U` and `-P` when set, Windows auth otherwise) and read `API_KEY` from the environment when no local file exists (the pipeline agent has none).
4. `scripts/tests/run-tests.sh`, the bash equivalent for the Linux agent (same five steps; LF line endings are enforced by `.gitattributes`).
5. Optional `docker-compose.yml` (SQL Server container).
6. `azure-pipelines.yml`: Microsoft-hosted Ubuntu agent, SQL Server service container, apply schema and seed, build and start the API, install Newman 6.2.3 and htmlextra 1.23.1 pinned, run the suite, cleanup under `condition: always()`, `PublishTestResults@2` for `tests/reports/newman-junit.xml`, `PublishPipelineArtifact@1` for the HTML report, fail on test failures. It cannot be run from this machine; verify the YAML syntax and run its steps locally.
7. `README.md` (how to run locally, the two suites, the layout rule), `SOLUTION.md` (design, trade-offs, assumptions, AI usage, "decided not to do").
8. BUILD_NOTES entries, when asked.
9. Pre-submission re-check (below), then the Loom video and sharing the repository.

## Open items before submission

- Decide the case of OData option names: `$TOP` is accepted because `IQueryCollection` matches keys case-insensitively, while values are case-sensitive. Document in SOLUTION.md or reject uppercase.
- Decide whether to keep or remove `scripts/tests/validation-check.ps1` (the Postman POST folder now covers its 14 cases).
- Decide about the AI-tooling files in the repo (`docs/HANDOFF.md`, `CLAUDE.md`, `.github/copilot-instructions.md`): keep all three (HANDOFF cleaned up) or remove all three; hiding only HANDOFF leaves a broken `CLAUDE.md` link.
- Re-read the attribution wording in `docs/AI_PROMPTS.md` and the BUILD_NOTES AI rows.
- `AI_CHAT_LOG.md` is referenced by the prompt log but is not in the repo. Chat exports and transcripts must stay out of the repo.
- Ask whether the recruiter confirmed the extended deadline.
- Behaviours to document in SOLUTION.md: 400 for anything unsupported (the brief does not say what unsupported input returns); `$top` rules (0 returns empty, 1 to 1000 allowed, above 1000 or negative or non-numeric returns 400); default order is `OccurredAt ASC, Id ASC`; device matching ignores letter case (SQL Server's default collation, pinned by a test); extra latitude decimals are rounded (A4); POST echoes `occurredAt` in UTC; the parser splits on ` and ` (a device id containing that text inside quotes gives 400); a raw `+02:00` in a URL fails (use `%2B`), so no test covers it; count and items come from two separate queries; Content-Type is not checked; a database outage returns a plain 500; `UtcDateTimeOffsetJsonConverter.Read` is never used (required by the base class).
- Decided not to do (for SOLUTION.md): a full OData library, unit tests, Swagger, logging, a 415 for the wrong Content-Type, error handling for a database outage.
- Submission: repository public or shared with the address in the brief, plus the Loom video (5 to 10 minutes). The owner must be able to explain every line, including the lines an AI tool wrote.

## Things to remember

- Work in small pieces: give a short "why", say exactly what to run and what the result should look like, and let the owner type the first few of each kind (requests, scripts). Give a whole finished file only after the pieces are done and the owner asks.
- Keep token usage low: read only the files the task needs. Do not spawn multiple agents or workflows.
- The API listens on `http://localhost:5080` by default. Run it in a normal terminal, never in the PowerShell ISE or the "PowerShell Extension" terminal (the play button there fails).
- Windows PowerShell 5.1: no PowerShell 7 features (no `??`, no `-SkipHttpErrorCheck`). Use `curl.exe` with a body file. The editor's formatter turns `a,b,c` into `a, b, c` (an array); quote such values.
- The API refuses to start without `API_KEY`. Never commit the key. Environment variables are per terminal.
- Stop a dev API before a normal `dotnet build` (file lock); the run script builds Release into a different folder.
- The POST response echoes the input; assert on GET responses for stored values. Decimals are stored with 6 (lat/lon) and 2 (speed/heading) decimals.
- Layout rule for the test sources: every group has `_folder.json` and numbered request files; a group whose requests have bodies also has `bodies/`. Edit only `tests/authored/src/`, never the generated collection. A body file must be saved (an empty one fails the build with its path).
- The owner commits and pushes themselves: small commits, one push, no co-author line. Give the commit messages when it is time. Do not commit `docs/notes/`.
- If the owner edits a script in the ISE, do not edit the same file from VS Code at the same time.
- Notes for the video and interview go into `docs/notes/` (gitignored): `PostmanExport.md`, `PostmanAuthored.md`, `ODataQuery.md`, `ODataParser.md`, `PositionRepository.md`, `Program.md`, plus `docs/CODE_NOTES.md`. Claude writes them; the owner types the code.
- After each step, suggest a BUILD_NOTES entry and add valid prompts to `docs/AI_PROMPTS.md`.
