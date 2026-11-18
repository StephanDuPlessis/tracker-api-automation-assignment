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
