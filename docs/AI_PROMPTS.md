# AI prompts log

The prompts I gave to the AI tools on this assignment, in the order the work happened, with what came back and what I did with it. Prompts are quoted from the chat exports. Long prompts are trimmed with "[...]" and the intent is unchanged. No dates; the commit history shows timing.

Related files:
- `AI_CHAT_LOG.md` covers the Claude chat (claude.ai) side: planning, reviews, debugging help.
- `docs/BUILD_NOTES.md` holds the decisions (D1 to D16), assumptions and issues.

Tools used:
- **Claude chat (claude.ai):** planning, drafting the prompts for the coding tools, reviewing pasted code. See `AI_CHAT_LOG.md`.
- **GitHub Copilot (agent mode, VS Code):** generated the SQL scripts and the API code.
- **Claude Code (VS Code):** checked the repo state, kept the handoff notes, and coached me through writing the validation script.

---

## Part 1: GitHub Copilot

### 1. SQL scripts

**Prompt:**
> Create db/01_schema.sql, db/02_seed.sql and db/99_cleanup.sql following the instructions file. Schema: Devices and Positions tables with the columns, keys and index described. Make 01_schema.sql idempotent (create the database and tables only if they don't exist). Seed: 3 devices and about 12 positions over 2 days with known timestamps, all with TEST- / pos-test- prefixes. Write a comment block at the top of 02_seed.sql listing the exact expected counts per device and per date range, so tests can rely on them. Cleanup: delete by prefix, positions first, then devices. Don't create anything else yet. Afterwards, explain each script in a few lines.

**What the AI gave:** The three scripts. It chose the database name `PositionsDb` because the instructions did not give one, and said it had not run the scripts.
**What I did:** Ran them against LocalDB (schema twice to check it is repeatable, then seed, cleanup, seed again) and checked the counts: 5 / 4 / 3 per device, 12 in total. No changes needed.
**Outcome:** D11, D12, D13.

### 2. API step 1

**Prompt (full text, from Copilot's own copy because the export cut it short):**
> Create the .NET 9 minimal API in src/PositionsApi following the instructions file. Only this step: project setup, API key auth, POST /positions and GET /positions/{id}. Do NOT implement GET /positions (OData) yet.
>
> - Use plain Microsoft.Data.SqlClient with parameterised SQL (no EF, no Dapper). Keep it in a small PositionRepository class; models in their own file.
> - Config from environment variables: API_KEY and DB_CONNECTION_STRING (default connection string for LocalDB database PositionsDb if the variable is not set). Listen on http://localhost:5080 unless ASPNETCORE_URLS is set. No secrets in code or appsettings.
> - Auth: every endpoint requires the X-Api-Key header; missing or wrong key returns 401.
> - POST /positions: all seven fields required (id, deviceId, occurredAt, latitude, longitude, speedKph, headingDeg). Return 400 with a short error message for missing or wrong-type fields, latitude outside -90..90, longitude outside -180..180, occurredAt that is not a valid ISO 8601 timestamp with a timezone. Return 409 for a duplicate id. If the deviceId does not exist, insert it into Devices first (Name = deviceId). Return 201 with the created position.
> - GET /positions/{id}: 200 with the position, or 404.
> - Serialise occurredAt in UTC with a Z suffix (e.g. 2025-01-15T12:34:56Z), and use camelCase JSON field names as in the brief.
> - Add a short comment on anything non-obvious.
>
> Afterwards run dotnet build and tell me the exact command to start the API. Then explain each file in a few lines.

**Note:** The prompt asked for `...56Z`, but the first version returned `56.0000000Z`. I only saw this in my hand tests, which is why item 3 exists. Also, the prompt did not ask for a speed, heading or length check, which is the gap item 4 closes.

**What the AI gave:** `Program.cs`, `Position.cs`, `PositionRepository.cs` and the project file. It removed the template appsettings and launch settings so environment variables control the configuration. Build: 0 warnings, 0 errors. It also ran its own smoke test.
**What I did:** Tested six calls by hand (201, 200, 401, 409, 400, 404). Had the code reviewed in Claude chat (see `AI_CHAT_LOG.md`).
**Outcome:** Working API for auth, POST and GET by id.

### 3. Timestamp format fix

**Prompt:**
> Small fix in src/PositionsApi, nothing else. Serialise occurredAt as UTC ISO 8601 without trailing fractional zeros: 2025-01-15T12:34:56Z, adding fractional seconds only when they are non-zero. Apply it to both the POST and GET responses. Run dotnet build and explain the change in a few lines.

**Why I sent it:** My hand tests showed timestamps coming back as `56.0000000Z`, but the brief uses `56Z`.
**What the AI gave:** A change to the shared `DateTimeOffset` JSON converter. The first build failed because a leftover API process from its own smoke test had locked the files; it stopped that process and rebuilt.
**Outcome:** D14.

### 4. Validation limits (D16)

**Prompt:**
> Small fix in src/PositionsApi/Position.cs only. Add validation so that bad input returns 400 with a clear message instead of failing in SQL or being silently changed: id longer than 100 characters, deviceId longer than 50, speedKph below 0 or above 1000, headingDeg below 0 or above 360 (inclusive). Keep the existing style and messages. Run dotnet build and explain the change in a few lines.

**Why I sent it:** My before-fix test run showed out-of-range speed and heading caused a 500, and nonsense values that fit the column were saved (`docs/evidence/validation-before-fix.txt`).
**What the AI gave:** The four checks in `Position.cs`. Build: 0 warnings, 0 errors.
**Note:** I sent this same prompt twice. The second time the AI found the checks already in place, changed nothing and rebuilt.
**What I did:** Proved the fix with `scripts/validation-check.ps1` (see Part 2): 14 cases, 0 failures.
**Outcome:** D16. Evidence in `docs/evidence/validation-after-fix.txt`.

### 5. Evidence query (cancelled)

I pasted two `sqlcmd` commands into Copilot to save the truncation check to `docs/evidence/truncation-check.txt`. That turn was cancelled, so there is no Copilot response. The output file exists in `docs/evidence/`.

### 6. Exporting this chat

Turns about how to export the Copilot chat are left out of this log because they are not about the project. Copilot's first instructions for the export were wrong: it described the Claude Code menu as if it were Copilot's.

---

## Part 2: Claude Code

### 7. Applying D16

**Prompt:**
> Read CLAUDE.md, docs/HANDOFF.md and git status. Then apply decision D16 in src/PositionsApi/Position.cs only, explain what you changed, and tell me how to test it.

**What the AI gave:** It found all four D16 checks already in `Position.cs` (they came from Copilot, item 4) and made no code change. It confirmed the build and gave a test plan.
**What I did:** Noticed HANDOFF.md said the fix was not applied, which was wrong. Git could not show it because `src/` was untracked. Logged this as an issue in BUILD_NOTES: commit `src/` so git can be trusted.

### 8. Updating the handoff

**Prompt:**
> Read CLAUDE.md, docs/HANDOFF.md and git status. Do not change any code. Update docs/HANDOFF.md only, with these facts: [...] I am writing the test script myself, in pieces, at scripts/validation-check.ps1. [...] The API listens on http://localhost:5080 by default. I run it in a normal terminal, never in the PowerShell ISE. I run the scripts in the ISE, which is Windows PowerShell 5.1, so do not use PowerShell 7 features such as -SkipHttpErrorCheck. Use curl.exe with a body file. [...]

**What the AI gave:** An updated HANDOFF.md with these facts and the working rules.
**What I did:** Kept the rule that I write scripts myself in small pieces, so I can explain every line.

### 9. Review of the build notes

**Prompts:**
> What is missing from the build notes?
> Do you think we should update the file?

**What the AI gave:** A list of gaps (D16, the validation issue, the rounding limitation, an AI usage row for Claude Code). It advised waiting until the validation had actually been run, so the notes record what was proven.
**What I did:** Agreed and waited. After the run, had the entries added (D16, A4, four issues, a video talking point, an AI usage row).

### 10. Token usage

**Prompts:**
> How can I view my token usage here?
> Also, don't run multiple agents and help me keep the token usage optimized

**What the AI gave:** `/context`, `/cost`, `/usage` and `/clear` advice. It also wrote a private memory note, then tried to index it.
**What I did:** Rejected the index command and asked why it was needed. The AI explained, I chose to keep the rule in `docs/HANDOFF.md` instead, because Copilot reads that file too, and the memory note was deleted.

### 11. Writing `scripts/validation-check.ps1`

**Prompts (short):**
> Now, lets start with the ps script from scratch, I have not added anything or started anything
> Give me the script to run for the API key, add it to gitignore so that I can run it when needed
> Should we not add this to the script to ensure that we don't run into this issue? 99_cleanup.sql
> Also add this to seed the data, so we don't have to manually do it each time: 02_seed.sql

**What the AI gave:** The script in small pieces, each with a reason: settings and key check, a base body with one field changed per case (`New-Body`), the 14 cases as data, a `curl.exe` helper that sends a body file (`Send-Position`), the loop with PASS/FAIL, cleanup and seed at the start, and saving the results.
**What I did:** Typed and ran each piece. Caught that the ISE showed a stale copy of the file after an outside edit, and that a second run returned 409 for rows saved by the first, which led me to add cleanup and seed to the script. Decided to keep the key in a gitignored `scripts/set-env.local.ps1`, and to have `scripts/start-api.ps1` load it.
**Outcome:** `Failures: 0 of 14`, saved to `docs/evidence/validation-after-fix.txt`. Re-runnable with no manual SQL (D5).

### 12. Notes, commits and push

**Prompts:**
> Should we add the Build Notes and commit what we have?
> Lets do smaller commits and one push, leave out the co-auth part

**What I did:** Declined to let the AI commit and said I would do it myself. Asked for small commits, one push, and no co-author line. Ran them myself.

### 13. Tooling and a reality check on the API

**Prompts:**
> Should I install Postman so I can test from there the tests that we write as well? Just to be safe?
> Hold on. Is the API "Program" side done? For example, is this a completed feature that a dev would give me?

**What the AI gave:** Advice to use Postman only for building the collection and Newman as the real runner. It installed nothing. On the second question it said honestly that the API is incomplete: `GET /positions` with OData is not built, and `Program.cs` and `PositionRepository.cs` have not been code-reviewed.
**What I did:** Installed Node and Newman myself (Newman 6.2.3, htmlextra 1.23.1, both working on Node 26). Held off the six basic calls until the OData endpoint exists, so each test is written once against a stable API.

### 14. Planning and the recruiter's feedback

**Prompts:**
> What work is still left to be done, and how long will it take?
> Keep this in mind as well [screenshots of the recruiter's messages]
> And what about the message I sent requesting for more time?
> Okay, so what still needs to be done? And what would the prompts look like when we save them?
> How can I show you all the prompts I have used for another chat and copilot?

**What the AI gave:** A task list with estimates (its own estimates, not from the brief). It summarised the recruiter's replies: stick to Postman/Newman or ReadyAPI, include the AI prompts and my reasoning, and explain the choices I made and the ones I decided against. It said it could not see a reply to my request for more time. It also proposed this file.
**What I did:** Sent exports of the Copilot chat, the Claude chat log and the Claude Code sessions. This file was built from them.

### 15. OData approach and the first piece

**Prompts:**
> I started a new chat, what needs to be done?
> Why are we writing our own OData?
> But does that not go against what the assignment says? [brief attached]
> yes
> What does the "sealed" do?
> Why are they not meant for inheritance?
> Keep it. Give me the stuff I need to create again, I have not done anything yet
> Can we add notes somewhere so that I can do quick references for the video and the interview thereafter?

**What the AI gave:** A summary of the repo state from `HANDOFF.md` and git. The reasons for a hand-written OData parser, then a check of that decision against the brief (allowed: own target, "OData-style", deviations documented). A proposed grammar and plan, and piece 1 (`ODataQuery` record) to type. Explanations of `sealed` and inheritance. A private notes file for quick-reference explanations (kept out of the repo).
**What I did:** Questioned the decision against the brief, confirmed the grammar, decided to keep `sealed`, and asked for explanation notes for the video and interview.

### 16. Building `GET /positions` with OData

**Prompts:**
> Can we add notes somewhere so that I can do quick references for the video and the interview thereafter?
> Give me 2c-2 / 2c-3 [and the other pieces, one at a time]
> Check the class and make sure I've done everything correctly so far
> Should we add a editor config?
> I want it to look professional, so fix the cosmetics
> Build succeeded, give me 4b
> [screenshots of manual curl results]

**What the AI gave:** The OData parser (`ODataQuery.cs`, `ODataParser.cs`), `QueryAsync` and its helpers in `PositionRepository.cs`, and the `GET /positions` route in `Program.cs`, one small piece at a time with a short "why" for each. A review of the finished parser (no bugs found, three cosmetic points), a view on `.editorconfig` (not needed now), and ten manual `curl.exe` calls to check the endpoint.
**What I did:** Typed each piece myself and built after each one. Found that the first three calls returned 401 because the API key was not set in that terminal, fixed it, and re-ran. All ten manual calls then gave the expected results. Questioned the `sealed` keyword and the `.editorconfig` idea, and decided to keep the first and skip the second for now. Caught that the formatter had changed the indentation of a line in `Position.cs` and had it restored. The AI's first version of the date helper pointed at the wrong class name (`Position` instead of `PositionRequest`); the compiler error showed it and it was corrected.

### 17. Handover readiness and code review

**Prompts:**
> Is the code that a dev would give me to test complete?
> So what is missing before this is handed over for testing?
> yes, start the review

**What the AI gave:** An honest list of what is and is not done (the README is two lines, no `.env.example`, `Program.cs` and `PositionRepository.cs` never reviewed as a whole). Then a review of `Position.cs`, `PositionRepository.cs`, `Program.cs` and the schema: no blocking bugs, one small fix (a lookup id longer than 100 characters is silently truncated in `GetByIdAsync`) and several behaviours to document.
**What I did:** Asked for the review before starting the Postman work, so the tests are written against reviewed code.

### 18. Postman collection, authored suite and run script

**Prompts:**
> Give me the apikey / Does the api key need to have the single quates mark?
> Create the collection [then: environment, helper script, first request, export and run with Newman]
> Can we not add it to different collections so it is easier to read and write
> Is there not a better way than having everything in one class?
> I think we need 2, so that I can explain something. Keep one as is where it is imported from Postman, and one where it is created in VS code newman [...]
> We need to split it by folders in VS Code so it is easier to follow
> Have another folder with the environment file in it, incase there will be more than one in future uses
> Why is the newman command so long? Is there a different way to run the tests that is easier?
> We need different sub folders in the scripts folder to seperate the tests from the others
> Add it to the explination for my video

**What the AI gave:** Step-by-step Postman setup (environment with placeholders, collection-level API key, shared helper script loaded with `eval`, first Auth requests), the export and Newman run, a comparison of ways to organise a large collection (one file, several collections, small source files merged by a script), a build script design, a `scripts/tests/` layout that avoids moving the key file, and a one-command run script. It created the boilerplate JSON files and moved files; the notes for the video were written by the AI into a private, gitignored folder.
**What I did:** Created the Postman environment and collection and the first Auth requests, exported and ran them with Newman, and hit and diagnosed an empty-environment export (`Invalid URI "http:///positions"`). Questioned the one-big-file approach and chose the two-suite layout (frozen export plus an authored suite), asked for the folder-per-group split, the environments folder and the scripts folder. Typed the first pieces of the build script and the run script and ran them; the AI wrote the final folder-based version of the build script when I asked it to update the file. The run was green: 3 requests, 5 assertions, 0 failed.

### 19. POST folder and readable request bodies

**Prompts:**
> Okay, I am going to start with adding the folder and the json file
> Build succeeded, give me the second POST request
> Before we continue, why are we using raw and not json?
> The reason I am asking is because this can be difficult to read [the escaped body string]
> yes, go ahead on that basis but change the build script too and add an explination as to why in my notes as well

**What the AI gave:** Instructions for the first two POST requests, an explanation of Postman's `raw` mode versus the `json` language label, and a design for keeping request bodies as plain `.json` files that the build script inlines (`rawFile`). It changed the build script, converted my first two requests to the new style, and generated the other 44 POST requests and all body files with a throwaway script kept outside the repo. It also pointed out that the POST folder should use its own device so the seeded counts stay intact.
**What I did:** Wrote the first two POST requests myself and ran the suite. Asked why `raw` is used, found the escaped body string hard to read and asked for a better way, and approved the body-file design. Ran the suite after generation: 49 requests, 84 assertions, 0 failed. (The AI's early estimate of about 93 assertions was wrong; 84 is the correct count.)

### 20. Round-trip check for accepted POSTs

**Prompts:**
> yes, give me the first piece [expectStored helper]
> I think there is already a helper [the existing expectStatus and expectError]
> I am confused, give me what this helper should look like
> What does this mean? returns the stored position
> Build succeeded, run the tests
> yes, give me piece 2 [compare every stored field]

**What the AI gave:** Moved the helper script out of `base.json` into a plain `src/helpers.js` (inlined by the build via `execFile`), then designed `expectStored` in two pieces: first a GET by id that checks the id, then a comparison of every field with rounding for latitude, longitude, speed and heading and an instant-based comparison for the timestamp. Found and fixed a file-name bug in the files it had generated (a minus sign was dropped from names like `latitude -90`). Ran the suite on request and, after I confirmed the first pieces worked, added the same one-line call to the other accepted POST requests.
**What I did:** Typed the helper and the first uses myself, asked what was unclear (an existing helper, what a test label means), and ran the suite after each change. Results: 85 assertions with the id check, 87 with the two tricky cases (offset timestamp and 8-decimal latitude), 97 with all 13 accepted POST requests, 0 failed.

### 21. GET by id folder

**Prompts:**
> yes, give me the first piece [seeded position found]
> Build succeeded, run the tests

**What the AI gave:** The first GET by id request (the seeded position with its exact values) and a second helper, `expectPosition`, then the other four requests: unknown id, a 101-character id that starts with a stored 100-character id (regression test for the truncation bug from the code review), an id with encoded special characters, and a missing key.
**What I did:** Typed the helper and the first request myself, ran the suite (63 requests, 99 assertions, 0 failed). The rest of the folder was written by the AI; the final run gave 67 requests, 107 assertions, 0 failed.

### 22. Consistency across the test folders

**Prompts:**
> Before we continue with anything. Should the tests' structures not match? For example, in 2-post we have a bodies folder, but we don't have it in the others. Things should be consistent
> yes, go ahead with all three

**What the AI gave:** A check of the three test folders that found more than the `bodies/` difference (mixed array style, one file indented with 4 spaces, mixed line endings), with a recommendation: write the layout rule down, do a one-time formatting pass and add `.editorconfig` and `.gitattributes`. It ran the pass, proved the merged collection was byte-for-byte identical afterwards and that the suite still passed (67 requests, 107 assertions, 0 failed).
**What I did:** Spotted the inconsistency myself and asked for it to be fixed before building more, then approved all three changes.

### 23. OData folder

**Prompts:**
> yes, give me the first piece [first OData request and the expectIds helper]
> Build succeeded, run the tests

**What the AI gave:** The first OData request (filter by device, expecting the five seeded ids in order) and the `expectIds` helper for me to type. After it passed, it read the seed data, added the `expectCount` and `expectNoCount` helpers and generated the other 42 OData requests (devices, date ranges with inclusive boundaries, string functions, ordering, `$top`, `$count`, and unsupported or malformed input), each asserting an exact list of ids. It explained which cases it left out on purpose and which assumptions the tests pin.
**What I did:** Typed the first request and the `expectIds` helper myself and ran the suite (68 requests, 109 assertions, 0 failed). The final run with the whole folder gave 110 requests, 208 assertions, 0 failed.

### 24. Data integrity folder and the build guard

**Prompts:**
> yes, give me the first piece [create a position then find it with a query]
> Failed [screenshot of the run]
> Add this to the file please [the empty-body check in the build script]

**What the AI gave:** The first two data-integrity requests for me to write (a POST and a query that must find what was created). When the run failed, it read the output and found the cause (my body file was empty, so the POST had no body and everything after it failed), proposed a build check that fails with the file name, and after I pasted the code into the chat it added it to the build script. It then added two helpers (sorting and count-versus-items) and generated the other 12 requests: count versus `$top`, ordering that follows timestamps rather than creation order, a rejected duplicate and a rejected invalid position leaving no trace, and the seeded data staying untouched.
**What I did:** Created the folder, the body file and the first two requests, and ran the suite. The first run failed because I had not saved the body file; I saved it and the run passed (113 requests, 213 assertions). The finished folder ran twice in a row to prove it can be re-run: 127 requests, 246 assertions, 0 failed both times.

### 25. The run script: start and stop the API, reporters, exit code, one settings file

**Prompts:**
> yes, give me the first piece [start and stop the API from the script]
> Build succeeded, run the tests
> Where should I add piece 2? / I made the first change
> Give me what the whole script should look like rather than piecing it bit by bit and an explanation I can use in my video and interview
> Should we have a file with these values and settings so that it is changed in one place
> Okay so what do I still need to do?
> Remember where we are so I can start a new chat

**What the AI gave:** The start and stop logic for the API (use a running one, otherwise build and start the built dll, always stop the one it started), then the reporters and exit code. It spotted that my edit had spaces after the commas in `--reporters cli, junit, htmlextra`, which PowerShell turns into separate arguments, and had me quote it. At my request it gave the complete script plus an explanation for the video and interview, and added two guards (a failed collection build stops the script; Newman gets the same base URL the script checked). It proposed a `.env.example` and `.env` for one settings file. It ran the finished script to check the exit code, reports and cleanup before rewriting the handoff.
**What I did:** Typed the start and stop piece and the reporter change myself, ran the script both with and without my own API running, asked for the whole script instead of more pieces, and asked about one settings file and what was still left.

---

## What I reviewed or corrected myself

- Found the validation gap with my own before-fix test, before any AI suggested it (`docs/evidence/`).
- Found a timestamp format mismatch in my hand tests and had it fixed (D14).
- Found that a 400 that looked wrong was PowerShell mangling quotes in `curl.exe`, not an API bug.
- Found that Claude chat's prediction about long `id` and `deviceId` values was wrong: they were saved as 201, not a 500, because the SQL driver silently truncates strings (see `AI_CHAT_LOG.md`, item 6).
- Caught the stale HANDOFF.md claim that D16 was not applied.
- Built the validation script in small pieces that I typed and ran, and decided it should clean and seed the database itself so it can be re-run.
- Decided where the API key lives, and kept the memory-note rule in a shared file instead of a private one.
- Stopped the AI from committing; I commit and push myself.

## Not covered

- The Claude chat conversations are summarised in `AI_CHAT_LOG.md`, not quoted word for word.
- Prompts used after this export (OData and later) are not in this file yet.
