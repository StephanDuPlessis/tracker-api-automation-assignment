# Handoff

Shared status file for Claude Code and GitHub Copilot. Read it at the start of a session and update it at the end of every task. No dates or times. Git history is the real record; this file is the quick summary.

## Rules for both agents

- Follow `.github/copilot-instructions.md`.
- One small task at a time. Do not start the next step unless asked.
- Never edit `docs/BUILD_NOTES.md` unless asked. Suggest the entry instead.
- Run `git status` first. If it disagrees with this file, trust git.

## Current state

- Done: SQL scripts (`db/01_schema.sql`, `02_seed.sql`, `99_cleanup.sql`), run and verified on LocalDB (database PositionsDb, 12 seeded positions: 5 / 4 / 3 per device).
- Done: API step 1 in `src/PositionsApi` (API key auth, POST /positions, GET /positions/{id}), checked by hand: 201, 200, 401, 409, 400, 404. Timestamps serialise as `...56Z`.
- Evidence of a validation gap is saved in `docs/evidence/` (before-fix output and truncation check).
- API status: feature complete and code-reviewed (`Position.cs`, `PositionRepository.cs`, `Program.cs`, `db/01_schema.sql`). No blocking bugs. Fixed after the review: `GetByIdAsync` no longer sets a size on `@Id` (a fixed size of 100 silently cut longer lookup ids), and the 404 now returns `{ "error": "Position not found." }` like the other errors. Both built, and both check calls (unknown id, 101-character id) returned 404 on the restarted API. Observations to document or decide: POST echoes `occurredAt` normalised to UTC; `UtcDateTimeOffsetJsonConverter.Read` is unused (POST parses by hand); leading or trailing spaces in ids are stored as-is and SQL ignores trailing spaces when comparing; Content-Type is not checked; a database outage returns a plain 500.
- Done: GET /positions with OData (`ODataQuery.cs`, `ODataParser.cs`, `QueryAsync` in `PositionRepository.cs`, route in `Program.cs`). Typed and built by the owner in small pieces. Ten manual calls passed: top+count+orderby desc, deviceId eq, `$skip` 400, no key 401, inclusive date range (quoted and unquoted), LIKE wildcard escaping, startswith, `$top=0`, `$top=-1` 400. `PositionRequest.IsoTimestampWithTimeZone` in `Position.cs` changed from private to internal so the parser reuses the POST timestamp rule.
- Parked decision: OData option names (`$TOP`) are accepted case-insensitively (see the memory note on the pre-submission re-check). Document in SOLUTION.md or reject uppercase.
- Done: Node v26.13.1 and npm 11.20.0 installed. Newman 6.2.3 and newman-reporter-htmlextra 1.23.1 installed globally and `newman -v` works. Postman desktop is not installed yet (needed only to build the collection).
- Done: BUILD_NOTES has D16, A4 (rounding limitation), the validation issues and the AI usage row.
- Done: decision D16 in `src/PositionsApi/Position.cs` (id over 100 characters, deviceId over 50, speedKph outside 0 to 1000, headingDeg outside 0 to 360 each return 400 with a clear message). Verified against the running API with `scripts/tests/validation-check.ps1` (built by the owner in small pieces): 14 cases, all pass (`Failures: 0 of 14`). Cases 1 to 7 return 400, case 8 returns 201 (known limitation: extra latitude decimals are rounded), cases 9 to 14 (boundaries) return 201. Output saved in `docs/evidence/validation-after-fix.txt`.
- The validation script resets the database itself at the start (`99_cleanup.sql`, then `02_seed.sql`), so it can be re-run with no manual SQL. It leaves the seed rows plus the validation rows from cases 8 to 14 in the database; the next run's cleanup removes them.
- Helper scripts: `scripts/start-api.ps1` starts the API (loads the key from the gitignored `scripts/set-env.local.ps1`). `scripts/set-env.local.ps1` sets `API_KEY` and moves to the repo root; run it with F5 in the ISE or dot-sourced.

- Done: `docs/AI_PROMPTS.md` drafted from the Copilot, Claude Code and Claude chat exports (prompts up to the end of the validation work). Add later prompts (OData onwards) as they happen. `AI_CHAT_LOG.md` (Claude chat log) is referenced from it but is not in the repo yet.

## In progress

- Postman: the real suite is `tests/authored/` (small source files in `src/<n>-<group>/`: one file per request, `_folder.json` for the folder name, `bodies/` for request bodies as plain files that the build inlines via `rawFile`, `base.json` for the collection settings and helper; `build-collection.js` merges them; environments in `environments/`). `tests/postman-export/` is the frozen GUI export (Auth only, not run by the pipeline, contains Date headers in saved examples). `scripts/tests/run-tests.ps1` builds, resets the DB (cleanup + seed, defaults LocalDB, `DB_SERVER`/`DB_NAME` override, Windows auth only so far) and runs Newman. The POST folder has 46 requests (generated once, the owner wrote the first two) using the device `TEST-P-40001` so seeded counts stay intact. Run with Newman: 67 requests (54 collection requests plus 13 round-trip GETs), 107 assertions, 0 failed (Auth 3, POST 46, GET by id 5). The 13 accepted POSTs use the `expectStored` helper (written by the owner in `src/helpers.js`; the helper script is a plain file inlined by the build via `execFile`). Next: OData and data integrity folders; grow `run-tests.ps1` (SQL auth, start and stop the API, reporters, cleanup, exit code). Uncommitted: the new POST files, build script change, docs. Do not commit `docs/notes/`. Layout rule: every test group has `_folder.json` and numbered request files; a group whose requests have bodies also has `bodies/`. The src files were formatted once (2 spaces, LF, expanded arrays) and `.editorconfig` and `.gitattributes` were added.
- Local-only (gitignored): `scripts/set-env.local.ps1`, `docs/CODE_NOTES.md` and the `docs/notes/` folder.
- `docs/CODE_NOTES.md` (general topics) and `docs/notes/<Class>.md` (one file per class) are the owner's private study notes for the video and interview. They are gitignored on purpose: never commit them, never reference them from committed docs. Claude writes these notes (the owner types the code); `docs/notes/ODataParser.md` exists and gets a section per piece.
- Notes for the owner's video and interview are up to date for every piece built so far (`docs/notes/ODataQuery.md`, `ODataParser.md`, `PositionRepository.md`, `Program.md`). Keep adding a section per piece.
- Behaviours to document in SOLUTION.md as assumptions or limitations: 400 for anything unsupported; the parser splits on ` and ` (a device id containing that text inside quotes gives 400); raw `+02:00` in a URL fails (use `%2B`); device matching follows SQL Server's case-insensitive collation; count and items come from two separate queries; default order is `OccurredAt ASC, Id ASC`.

## Next steps, in order

1. Done: OData work and review fixes committed and pushed.
2. Optional: re-run the six basic calls (201, 200, 401, 409, 400, 404) once against the finished API. For a clean seed-only state run `db\99_cleanup.sql` then `db\02_seed.sql`.
3. Install Postman (authoring only; Newman is the runner). Build the Postman collection in `tests/`, run script in `scripts/tests/`, pipeline `azure-pipelines.yml`, README.md, SOLUTION.md.

## Things to remember

- When the owner asks for a script, give it in small pieces with a short "why" for each, so they can type it themselves and run it after each piece. Do not hand over a finished file.
- Do not spawn multiple agents or workflows. Keep token usage low: read only the files the task needs, keep replies short.
- The API listens on `http://localhost:5080` by default. The owner runs it in a normal terminal, never in the PowerShell ISE.
- The owner runs scripts in the PowerShell ISE, which is Windows PowerShell 5.1. Do not use PowerShell 7 features such as `-SkipHttpErrorCheck`. Use `curl.exe` with a body file.
- The API refuses to start without the `API_KEY` environment variable. Local dev key used in manual tests: set `$env:API_KEY` in the terminal that runs the API; the value is never committed.
- Stop the running API before building, or the build fails on a file lock.
- Send JSON bodies from a file or build them in PowerShell objects; quoting JSON on the `curl.exe` command line breaks it.
- The POST response echoes the input; assert on GET responses for stored values.
- `occurredAt` uses a UTC `Z` format; decimals are stored with 6 (lat/lon) and 2 (speed/heading) decimal places.

### How the owner wants to work

- The owner is a QA/SDET and must be able to explain every line in an interview and in the video. Explain in simple terms what is built and why, in a few lines.
- One small step at a time. Wait for the owner to run and check the result before the next step.
- Say exactly what to run (PowerShell on Windows) and what the result should look like. If something fails, help work out why instead of just fixing it.
- Flag ambiguity or risk instead of guessing. Say when unsure. Be honest if the owner's idea is weaker than an alternative.
- After each step, suggest a BUILD_NOTES entry (decision, issue and fix, or correction) and what was reviewed or got wrong. Write it only when asked.
- The owner commits and pushes themselves: small commits, one push, no co-author line. Give the commit messages when it is time.
- If the owner edits a script in the ISE, do not edit the same file from VS Code at the same time (the ISE keeps a stale copy). Edit and run in one place.

### Notes for the Postman collection

- Port the 14 validation cases from `scripts/tests/validation-check.ps1` into the POST folder (D16 limits and boundaries are not in the plan yet). Use a data file or a pre-request script to change one field per case.
- After each successful POST, assert stored values with a GET by id (the POST only echoes the input).
- Keep the API key out of the exported environment file (placeholder only).
- Pin Newman 6.2.3 and newman-reporter-htmlextra 1.23.1 in the pipeline.
- Cleanup and seed belong in `run-tests.ps1` and the pipeline, not in the collection.
