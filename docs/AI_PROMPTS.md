# AI prompts log

The prompts I gave to the AI tools on this assignment, in the order the work happened, with what came back and what I did with it. Prompts are quoted from the chat exports with typos corrected (Claude chat is summarised in Part 0). Long prompts are trimmed with "[...]" and the intent is unchanged. Routine replies such as "yes" and "Build succeeded, give me the next piece" are not listed; where they carried meaning, the entry says what they were for. No dates; the commit history shows timing.

Tools used:
- **Claude chat (claude.ai):** planning, drafting the prompts for Copilot, reviewing pasted code and explaining errors. See Part 0.
- **GitHub Copilot (agent mode, VS Code):** generated the SQL scripts and the first version of the API, and added the validation limits.
- **Claude Code (VS Code):** did most of the rest: the test suites, run scripts, pipeline, Docker file and documentation, working with me in small steps.

**Contents** (click a part to open it)

<details>
<summary><strong>Part 0: Claude chat (claude.ai)</strong> (7 entries)</summary>

- [C1. Planning and tool choice](#c1-planning-and-tool-choice)
- [C2. OData explanation](#c2-odata-explanation)
- [C3. SQL scripts prompt](#c3-sql-scripts-prompt)
- [C4. API step 1 prompt and code review](#c4-api-step-1-prompt-and-code-review)
- [C5. Finding the validation gap](#c5-finding-the-validation-gap)
- [C6. Debugging help](#c6-debugging-help)
- [C7. Working with two coding assistants](#c7-working-with-two-coding-assistants)

</details>

<details>
<summary><strong>Part 1: GitHub Copilot</strong> (5 entries)</summary>

- [1. SQL scripts](#1-sql-scripts)
- [2. API step 1](#2-api-step-1)
- [3. Timestamp format fix](#3-timestamp-format-fix)
- [4. Validation limits (D16)](#4-validation-limits-d16)
- [5. Evidence query (cancelled)](#5-evidence-query-cancelled)

</details>

<details>
<summary><strong>Part 2: Claude Code</strong> (31 entries)</summary>

- [6. Applying D16](#6-applying-d16)
- [7. Updating the handoff](#7-updating-the-handoff)
- [8. Writing scripts/validation-check.ps1](#8-writing-scriptsvalidation-checkps1)
- [9. A reality check on the API](#9-a-reality-check-on-the-api)
- [10. Planning and the recruiter's feedback](#10-planning-and-the-recruiters-feedback)
- [11. OData approach and the first piece](#11-odata-approach-and-the-first-piece)
- [12. Building GET /positions with OData](#12-building-get-positions-with-odata)
- [13. Handover readiness and code review](#13-handover-readiness-and-code-review)
- [14. Postman collection, authored suite and run script](#14-postman-collection-authored-suite-and-run-script)
- [15. POST folder and readable request bodies](#15-post-folder-and-readable-request-bodies)
- [16. Round-trip check for accepted POSTs](#16-round-trip-check-for-accepted-posts)
- [17. GET by id folder](#17-get-by-id-folder)
- [18. Consistency across the test folders](#18-consistency-across-the-test-folders)
- [19. OData folder](#19-odata-folder)
- [20. Data integrity folder and the build guard](#20-data-integrity-folder-and-the-build-guard)
- [21. The run script: start and stop the API, reporters, exit code, one settings file](#21-the-run-script-start-and-stop-the-api-reporters-exit-code-one-settings-file)
- [22. Settings file: keep DB_CONNECTION_STRING as an override?](#22-settings-file-keep-db_connection_string-as-an-override)
- [23. Completing the Postman export collection as a second option](#23-completing-the-postman-export-collection-as-a-second-option)
- [24. Both Postman suites should cover the same test cases](#24-both-postman-suites-should-cover-the-same-test-cases)
- [25. One settings file for the scripts and the API](#25-one-settings-file-for-the-scripts-and-the-api)
- [26. SQL authentication in the reset step of the run script](#26-sql-authentication-in-the-reset-step-of-the-run-script)
- [27. The bash run script for the Linux pipeline agent](#27-the-bash-run-script-for-the-linux-pipeline-agent)
- [28. The Azure DevOps pipeline](#28-the-azure-devops-pipeline)
- [29. The second run script, run-tests-2.ps1](#29-the-second-run-script-run-tests-2ps1)
- [30. Comparison of the two Postman suites in SOLUTION.md](#30-comparison-of-the-two-postman-suites-in-solutionmd)
- [31. First draft of README.md](#31-first-draft-of-readmemd)
- [32. The rest of SOLUTION.md](#32-the-rest-of-solutionmd)
- [33. What to do next, and examples of failed and skipped tests](#33-what-to-do-next-and-examples-of-failed-and-skipped-tests)
- [34. The failure demo collection and pipeline parameter](#34-the-failure-demo-collection-and-pipeline-parameter)
- [35. docker-compose.yml for SQL Server](#35-docker-composeyml-for-sql-server)
- [36. Read-through of SOLUTION.md and four fixes](#36-read-through-of-solutionmd-and-four-fixes)

</details>

- [What I reviewed or corrected myself](#what-i-reviewed-or-corrected-myself)
- [Not covered](#not-covered)

---

## Part 0: Claude chat (claude.ai)

Claude chat did not write the project files. It planned, helped me draft the prompts I gave to Copilot (before I had Claude Code), reviewed code I pasted back, and helped me understand errors. These entries summarise what I used it for and what I did with the answers; the chats themselves are not reproduced here.

### C1. Planning and tool choice

**Used for:** Reading the brief, drafting the test plan, comparing Postman/Newman, ReadyAPI and code-based frameworks, and drafting the first decision log.

**What I did:** Chose Postman/Newman. Asked the recruiter whether other frameworks were allowed; the answer was to stick to Postman/Newman or ReadyAPI. Adapted the plan to my setup (LocalDB locally, Docker only in the pipeline).

**Outcome:**

| Decision | What it says |
|---|---|
| D1 | Postman with Newman as the test runner |
| D2 | Test my own .NET 9 minimal API backed by SQL Server |
| D3 | Hand-written OData parser for only the subset in the brief; anything else returns 400 |
| D4 | LocalDB locally, a SQL Server container in the pipeline |
| D5 | Test data isolated by the prefixes `TEST-` and `pos-test-`, so cleanup by prefix makes the suite re-runnable |
| D6 | JUnit XML for the pipeline and an HTML report for people |
| D7 | Settings come from environment variables, no secrets in the repository |

### C2. OData explanation

**Used for:** Explaining what OData is, which I had not used before.

**What I did:** Used the explanation to decide on a small hand-written parser for only the subset in the brief, returning 400 for anything else.

**Outcome:**

| Decision | What it says |
|---|---|
| D3 | Hand-written OData parser for only the subset in the brief; anything else returns 400 |
| D8 | `$filter` dates accepted unquoted and quoted |
| D10 | `$top=0` returns an empty list; negative, non-numeric or above 1000 returns 400 |

### C3. SQL scripts prompt

**Used for:** Helping me write the prompt for Copilot (entry 1), and later reviewing the three scripts I pasted back.

**What I did:** Ran the prompt in Copilot, ran the scripts against LocalDB and checked the counts myself. Chose the database name and the required-field and device rules myself.

**Outcome:** No changes to the generated scripts. Decisions:

| Decision | What it says |
|---|---|
| D11 | Database `PositionsDb`, created by `01_schema.sql` if missing |
| D12 | All seven position fields are required |
| D13 | POST registers an unknown `deviceId` |

### C4. API step 1 prompt and code review

**Used for:** Helping me write the prompt for Copilot (entry 2), and reviewing `Program.cs`, `Position.cs`, `PositionRepository.cs` and the project file that I pasted into the chat.

**What I did:** Tested six calls by hand and found the timestamp format mismatch (entry 3). Asked Copilot to make the API refuse to start without `API_KEY` and checked the code to confirm it did.

**Outcome:**

| Decision | What it says |
|---|---|
| D14 | Timestamps returned in UTC as whole seconds with a `Z` |
| D15 | The API refuses to start without `API_KEY` |

### C5. Finding the validation gap

**Used for:** Designing a before-fix test block of oversized and out-of-range values, and interpreting the results.

**What I did:** Ran it and saved the raw output in `docs/evidence/`. Out-of-range numbers caused 500 errors, and nonsense speeds and headings were saved. Claude predicted that over-long `id` and `deviceId` values would also give a 500. That was wrong: the API returned 201, because the SQL driver silently truncates strings to the parameter size. I confirmed this by reading the stored values back (100 and 50 characters).

**Outcome:** The fix and the boundary tests are in `docs/evidence/validation-after-fix.txt`. Decision:

| Decision | What it says |
|---|---|
| D16 | POST returns 400 for an id over 100 characters, a deviceId over 50, speedKph outside 0 to 1000 and headingDeg outside 0 to 360 |

### C6. Debugging help

**Used for:** Explaining errors: git push authentication, a build that failed because the running API had locked the files, `curl.exe` quote mangling in PowerShell, and `Tee-Object` writing UTF-16 output.

**What I did:** Applied the fixes and kept the lessons in the scripts.

### C7. Working with two coding assistants

**Used for:** Setting up shared context so Copilot and Claude Code can both work on the repo: the project instructions file, a short Claude Code file that imports it, and working notes for handing over between sessions.

**What I did:** Read the files, added the handover rule to the instructions file and committed them. Decided on small single-task prompts to keep token usage low.

---

## Part 1: GitHub Copilot

### 1. SQL scripts

**Prompt:**
> Create db/01_schema.sql, db/02_seed.sql and db/99_cleanup.sql following the instructions file. Schema: Devices and Positions tables with the columns, keys and index described. Make 01_schema.sql idempotent (create the database and tables only if they don't exist). Seed: 3 devices and about 12 positions over 2 days with known timestamps, all with TEST- / pos-test- prefixes. Write a comment block at the top of 02_seed.sql listing the exact expected counts per device and per date range, so tests can rely on them. Cleanup: delete by prefix, positions first, then devices. Don't create anything else yet. Afterwards, explain each script in a few lines.

**Note:** I wrote this prompt with help from Claude chat (C3), because I did not have Claude Code yet.

**What the AI gave:** The three scripts. It chose the database name `PositionsDb` because the instructions did not give one, and said it had not run the scripts.

**What I did:** Ran them against LocalDB (schema twice to check it is repeatable, then seed, cleanup, seed again) and checked the counts: 5 / 4 / 3 per device, 12 in total. No changes needed.

**Outcome:**

| Decision | What it says |
|---|---|
| D11 | Database `PositionsDb`, created by `01_schema.sql` if missing |
| D12 | All seven position fields are required |
| D13 | POST registers an unknown `deviceId` |

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

**Note:** The prompt asked for `...56Z`, but the first version returned `56.0000000Z`. I only saw this in my hand tests, which is why item 3 exists. Also, the prompt did not ask for a speed, heading or length check, which is the gap item 4 closes. I wrote this prompt with help from Claude chat (C4).

**What the AI gave:** `Program.cs`, `Position.cs`, `PositionRepository.cs` and the project file. It removed the template appsettings and launch settings so environment variables control the configuration. Build: 0 warnings, 0 errors. It also ran its own smoke test.

**What I did:** Tested six calls by hand (201, 200, 401, 409, 400, 404). Had the code reviewed in Claude chat (C4).

**Outcome:** Working API for auth, POST and GET by id.

### 3. Timestamp format fix

**Prompt:**
> Small fix in src/PositionsApi, nothing else. Serialise occurredAt as UTC ISO 8601 without trailing fractional zeros: 2025-01-15T12:34:56Z, adding fractional seconds only when they are non-zero. Apply it to both the POST and GET responses. Run dotnet build and explain the change in a few lines.

**Why I sent it:** My hand tests showed timestamps coming back as `56.0000000Z`, but the brief uses `56Z`.

**What the AI gave:** A change to the shared `DateTimeOffset` JSON converter. The first build failed because a leftover API process from its own smoke test had locked the files; it stopped that process and rebuilt.

**Outcome:**

| Decision | What it says |
|---|---|
| D14 | Timestamps returned in UTC as whole seconds with a `Z` |

### 4. Validation limits (D16)

**Prompt:**
> Small fix in src/PositionsApi/Position.cs only. Add validation so that bad input returns 400 with a clear message instead of failing in SQL or being silently changed: id longer than 100 characters, deviceId longer than 50, speedKph below 0 or above 1000, headingDeg below 0 or above 360 (inclusive). Keep the existing style and messages. Run dotnet build and explain the change in a few lines.

**Why I sent it:** My before-fix test run showed out-of-range speed and heading caused a 500, and nonsense values that fit the column were saved (`docs/evidence/validation-before-fix.txt`).

**What the AI gave:** The four checks in `Position.cs`. Build: 0 warnings, 0 errors.

**Note:** I sent this same prompt twice. The second time the AI found the checks already in place, changed nothing and rebuilt.

**What I did:** Proved the fix with `scripts/validation-check.ps1` (see Part 2): 14 cases, 0 failures.

**Outcome:** Evidence in `docs/evidence/validation-after-fix.txt`. Decision:

| Decision | What it says |
|---|---|
| D16 | POST returns 400 for an id over 100 characters, a deviceId over 50, speedKph outside 0 to 1000 and headingDeg outside 0 to 360 |

### 5. Evidence query (cancelled)

I pasted two `sqlcmd` commands into Copilot to save the truncation check to `docs/evidence/truncation-check.txt`. That turn was cancelled, so there is no Copilot response. The output file exists in `docs/evidence/`.

---

## Part 2: Claude Code

### 6. Applying D16

**Prompt:**
> Read CLAUDE.md, docs/HANDOFF.md and git status. Then apply decision D16 in src/PositionsApi/Position.cs only, explain what you changed, and tell me how to test it.

**What the AI gave:** It found all four D16 checks already in `Position.cs` (they came from Copilot, item 4) and made no code change. It confirmed the build and gave a test plan.

**What I did:** Noticed HANDOFF.md said the fix was not applied, which was wrong. Git could not show it because `src/` was untracked. Logged this as an issue in BUILD_NOTES: commit `src/` so git can be trusted.

### 7. Updating the handoff

**Prompt:**
> Read CLAUDE.md, docs/HANDOFF.md and git status. Do not change any code. Update docs/HANDOFF.md only, with these facts: [...] I am writing the test script myself, in pieces, at scripts/validation-check.ps1. [...] The API listens on http://localhost:5080 by default. I run it in a normal terminal, never in the PowerShell ISE. I run the scripts in the ISE, which is Windows PowerShell 5.1, so do not use PowerShell 7 features such as -SkipHttpErrorCheck. Use curl.exe with a body file. [...]

**What the AI gave:** An updated HANDOFF.md with these facts and the working rules.

**What I did:** Kept the rule that I write scripts myself in small pieces, so I can explain every line.

### 8. Writing `scripts/validation-check.ps1`

**Prompts (short):**
> Give me the script to run for the API key, add it to gitignore so that I can run it when needed
> Should we not add this to the script to ensure that we don't run into this issue? 99_cleanup.sql
> Also add this to seed the data, so we don't have to manually do it each time: 02_seed.sql

**What the AI gave:** The script in small pieces, each with a reason: settings and key check, a base body with one field changed per case (`New-Body`), the 14 cases as data, a `curl.exe` helper that sends a body file (`Send-Position`), the loop with PASS/FAIL, cleanup and seed at the start, and saving the results.

**What I did:** Typed and ran the pieces through the cleanup step. Caught that the ISE showed a stale copy of the file after an outside edit. The AI warned that a second run would return 409 for rows saved by the first, so I asked for cleanup and seed to be added to the script. Decided to keep the key in a gitignored `scripts/set-env.local.ps1`, and to have `scripts/start-api.ps1` load it.

**Outcome:** `Failures: 0 of 14`, saved to `docs/evidence/validation-after-fix.txt`. Re-runnable with no manual SQL. Decision:

| Decision | What it says |
|---|---|
| D5 | Test data isolated by the prefixes `TEST-` and `pos-test-`, so cleanup by prefix makes the suite re-runnable |

### 9. A reality check on the API

**Prompt:**
> Hold on. Is the API "Program" side done? For example, is this a completed feature that a dev would give me?

**What the AI gave:** An honest answer that the API is incomplete: `GET /positions` with OData is not built, and `Program.cs` and `PositionRepository.cs` have not been code-reviewed.

**What I did:** Held off the six basic calls until the OData endpoint exists, so each test is written once against a stable API.

### 10. Planning and the recruiter's feedback

**Prompts:**
> [...] And what would the prompts look like when we save them?
> How can I show you all the prompts I have used for another chat and copilot?

**Context:** I also asked what work was left and how long it would take, and shared the recruiter's guidance on using AI tools.

**What the AI gave:** A task list with estimates (its own estimates, not from the brief). It pointed out the recruiter's requirement to include the AI prompts and my reasoning, and proposed this file.

**What I did:** Sent exports of the Copilot chat, the Claude chat log and the Claude Code sessions. This file was built from them.

### 11. OData approach and the first piece

**Prompts:**
> Why are we writing our own OData?
> But does that not go against what the assignment says? [brief attached]
> What does the "sealed" do?
> Why are they not meant for inheritance?
> Keep it. Give me the stuff I need to create again, I have not done anything yet
> Can we add notes somewhere so that I can do quick references for the video and the interview thereafter?

**Context:** The session started with a question about what needed to be done, and I confirmed the proposed grammar with a short reply.

**What the AI gave:** A summary of the repo state from my handoff notes and git. The reasons for a hand-written OData parser, then a check of that decision against the brief (allowed: own target, "OData-style", deviations documented). A proposed grammar and plan, and piece 1 (`ODataQuery` record) to type. Explanations of `sealed` and inheritance. A private notes file for quick-reference explanations (kept out of the repo).

**What I did:** Questioned the decision against the brief, confirmed the grammar, decided to keep `sealed`, and asked for explanation notes for the video and interview.

### 12. Building `GET /positions` with OData

**Prompts:**
> Check the class and make sure I've done everything correctly so far
> Should we add an editor config?
> I want it to look professional, so fix the cosmetics

**Context:** I asked for the remaining pieces one at a time, built after each one, and shared screenshots of the manual `curl.exe` results.

**What the AI gave:** The OData parser (`ODataQuery.cs`, `ODataParser.cs`), `QueryAsync` and its helpers in `PositionRepository.cs`, and the `GET /positions` route in `Program.cs`, one small piece at a time with a short "why" for each. A review of the finished parser (no bugs found, three cosmetic points), a view on `.editorconfig` (not needed now), and ten manual `curl.exe` calls to check the endpoint.

**What I did:** Typed each piece myself and built after each one. Found that the first three calls returned 401 because the API key was not set in that terminal, fixed it, and re-ran. All ten manual calls then gave the expected results. Questioned the `sealed` keyword and the `.editorconfig` idea, and decided to keep the first and skip the second for now. Caught that the formatter had changed the indentation of a line in `Position.cs` and had it restored. The AI's first version of the date helper pointed at the wrong class name (`Position` instead of `PositionRequest`); the compiler error showed it and it was corrected.

### 13. Handover readiness and code review

**Prompts:**
> Is the code that a dev would give me to test complete?
> So what is missing before this is handed over for testing?

**What the AI gave:** An honest list of what is and is not done (the README is two lines, no `.env.example`, `Program.cs` and `PositionRepository.cs` never reviewed as a whole). Then a review of `Position.cs`, `PositionRepository.cs`, `Program.cs` and the schema: no blocking bugs, one small fix (a lookup id longer than 100 characters is silently truncated in `GetByIdAsync`) and several behaviours to document.

**What I did:** Asked for the review before starting the Postman work, so the tests are written against reviewed code.

### 14. Postman collection, authored suite and run script

**Prompts:**
> Give me the apikey / Does the api key need to have the single quotes mark?
> Create the collection [then: environment, helper script, first request, export and run with Newman]
> Can we not add it to different collections so it is easier to read and write
> Is there not a better way than having everything in one class?
> I think we need 2, so that I can explain something. Keep one as is where it is imported from Postman, and one where it is created in VS code newman [...]
> We need to split it by folders in VS Code so it is easier to follow
> Have another folder with the environment file in it, in case there will be more than one in future uses
> Why is the newman command so long? Is there a different way to run the tests that is easier?
> We need different sub folders in the scripts folder to separate the tests from the others
> Add it to the explanation for my video

**What the AI gave:** Step-by-step Postman setup (environment with placeholders, collection-level API key, shared helper script loaded with `eval`, first Auth requests), the export and Newman run, a comparison of ways to organise a large collection (one file, several collections, small source files merged by a script), a build script design, a `scripts/tests/` layout that avoids moving the key file, and a one-command run script. It created the boilerplate JSON files and moved files; the notes for the video were written by the AI into a private, gitignored folder.

**What I did:** Created the Postman environment and collection and the first Auth requests, exported and ran them with Newman, and hit and diagnosed an empty-environment export (`Invalid URI "http:///positions"`). Questioned the one-big-file approach and chose the two-suite layout (frozen export plus an authored suite), asked for the folder-per-group split, the environments folder and the scripts folder. Typed the first pieces of the build script and the run script and ran them; the AI wrote the final folder-based version of the build script when I asked it to update the file. The run was green: 3 requests, 5 assertions, 0 failed.

### 15. POST folder and readable request bodies

**Prompts:**
> Before we continue, why are we using raw and not json?
> The reason I am asking is because this can be difficult to read [the escaped body string]
> yes, go ahead on that basis but change the build script too and add an explanation as to why in my notes as well

**What the AI gave:** Instructions for the first two POST requests, an explanation of Postman's `raw` mode versus the `json` language label, and a design for keeping request bodies as plain `.json` files that the build script inlines (`rawFile`). It changed the build script, converted my first two requests to the new style, and generated the other 44 POST requests and all body files with a throwaway script kept outside the repo. It also pointed out that the POST folder should use its own device so the seeded counts stay intact.

**What I did:** Wrote the first two POST requests myself and ran the suite. Asked why `raw` is used, found the escaped body string hard to read and asked for a better way, and approved the body-file design. Ran the suite after generation: 49 requests, 84 assertions, 0 failed. (The AI's early estimate of about 93 assertions was wrong; 84 is the correct count.)

### 16. Round-trip check for accepted POSTs

**Prompts:**
> I think there is already a helper [the existing expectStatus and expectError]
> I am confused, give me what this helper should look like
> What does this mean? returns the stored position

**What the AI gave:** Moved the helper script out of `base.json` into a plain `src/helpers.js` (inlined by the build via `execFile`), then designed `expectStored` in two pieces: first a GET by id that checks the id, then a comparison of every field with rounding for latitude, longitude, speed and heading and an instant-based comparison for the timestamp. Found and fixed a file-name bug in the files it had generated (a minus sign was dropped from names like `latitude -90`). Ran the suite on request and, after I confirmed the first pieces worked, added the same one-line call to the other accepted POST requests.

**What I did:** Typed the helper and the first uses myself, asked what was unclear (an existing helper, what a test label means), and ran the suite after each change. Results: 85 assertions with the id check, 87 with the two tricky cases (offset timestamp and 8-decimal latitude), 97 with all 13 accepted POST requests, 0 failed.

### 17. GET by id folder

**Prompts:** Short replies asking for the first piece and then to run the tests.

**What the AI gave:** The first GET by id request (the seeded position with its exact values) and a second helper, `expectPosition`, then the other four requests: unknown id, a 101-character id that starts with a stored 100-character id (regression test for the truncation bug from the code review), an id with encoded special characters, and a missing key.

**What I did:** Typed the helper and the first request myself, ran the suite (63 requests, 99 assertions, 0 failed). The rest of the folder was written by the AI; the final run gave 67 requests, 107 assertions, 0 failed.

### 18. Consistency across the test folders

**Prompt:**
> Before we continue with anything. Should the tests' structures not match? For example, in 2-post we have a bodies folder, but we don't have it in the others. Things should be consistent

**What the AI gave:** A check of the three test folders that found more than the `bodies/` difference (mixed array style, one file indented with 4 spaces, mixed line endings), with a recommendation: write the layout rule down, do a one-time formatting pass and add `.editorconfig` and `.gitattributes`. It ran the pass, proved the merged collection was byte-for-byte identical afterwards and that the suite still passed (67 requests, 107 assertions, 0 failed).

**What I did:** Spotted the inconsistency myself and asked for it to be fixed before building more, then approved all three changes.

### 19. OData folder

**Prompts:** Short replies asking for the first piece and then to run the tests.

**What the AI gave:** The first OData request (filter by device, expecting the five seeded ids in order) and the `expectIds` helper for me to type. After it passed, it read the seed data, added the `expectCount` and `expectNoCount` helpers and generated the other 42 OData requests (devices, date ranges with inclusive boundaries, string functions, ordering, `$top`, `$count`, and unsupported or malformed input), each asserting an exact list of ids. It explained which cases it left out on purpose and which assumptions the tests pin.

**What I did:** Typed the first request and the `expectIds` helper myself and ran the suite (68 requests, 109 assertions, 0 failed). The final run with the whole folder gave 110 requests, 208 assertions, 0 failed.

### 20. Data integrity folder and the build guard

**Prompt:**
> Add this to the file please [the empty-body check in the build script]

**Context:** I also shared a screenshot of a failed run.

**What the AI gave:** The first two data-integrity requests for me to write (a POST and a query that must find what was created). When the run failed, it read the output and found the cause (my body file was empty, so the POST had no body and everything after it failed), proposed a build check that fails with the file name, and after I pasted the code into the chat it added it to the build script. It then added two helpers (sorting and count-versus-items) and generated the other 12 requests: count versus `$top`, ordering that follows timestamps rather than creation order, a rejected duplicate and a rejected invalid position leaving no trace, and the seeded data staying untouched.

**What I did:** Created the folder, the body file and the first two requests, and ran the suite. The first run failed because I had not saved the body file; I saved it and the run passed (113 requests, 213 assertions). The finished folder ran twice in a row to prove it can be re-run: 127 requests, 246 assertions, 0 failed both times.

### 21. The run script: start and stop the API, reporters, exit code, one settings file

**Prompts:**
> Give me what the whole script should look like rather than piecing it bit by bit and an explanation I can use in my video and interview
> Should we have a file with these values and settings so that it is changed in one place

**What the AI gave:** The start and stop logic for the API (use a running one, otherwise build and start the built dll, always stop the one it started), then the reporters and exit code. It spotted that my edit had spaces after the commas in `--reporters cli, junit, htmlextra`, which PowerShell turns into separate arguments, and had me quote it. At my request it gave the complete script plus an explanation for the video and interview, and added two guards (a failed collection build stops the script; Newman gets the same base URL the script checked). It proposed a `.env.example` and `.env` for one settings file. It ran the finished script to check the exit code, reports and cleanup before rewriting the handoff.

**What I did:** Typed the start and stop piece and the reporter change myself, ran the script both with and without my own API running, asked for the whole script instead of more pieces, and asked about one settings file and what was still left.

---

### 22. Settings file: keep `DB_CONNECTION_STRING` as an override?

**Prompts:**
> What do you recommend and why? [whether DB_CONNECTION_STRING stays as an optional override]
> Agreed, put that in our documents and notes

**What the AI gave:** A recommendation to keep `DB_CONNECTION_STRING` as an optional override, with the four DB variables as the default. Reasons: the shared instructions already name it, .NET reads a connection string directly, and it covers odd options such as a custom port or `TrustServerCertificate`. `sqlcmd` cannot use a connection string, so the scripts need the separate variables anyway. It also pointed out the risk that both are set and disagree, and suggested that only the API reads the override. It then recorded the decision in HANDOFF.md, BUILD_NOTES.md (D18) and this log.

**What I did:** Asked for the recommendation, agreed with it and asked for it to be written into the documents and notes. No code changed yet.

---

### 23. Completing the Postman export collection as a second option

**Prompts:**
> I want another thing in this solution, it creates double work, but I believe it to be valuable. In the postman export folder we need to write all the tests in the collection file and create another ps1 script called run tests 2 where we run those so that we can see the advantages and disadvantages of both of our options. Don't change anything yet, what do you think? [...]
> I am not going to type anything, what I mean by the Postman way, is that you saw what I did in the existing collection file and just add to it
> 2 [write each request fresh into the export file, not copied from the authored suite]
> Go ahead and complete the postman collection

**Decision:** Finish `tests/postman-export/positions.postman_collection.json` in the same style as my Auth folder (one file, test scripts inline, helpers in the collection-level script), as a second option next to the authored suite, so I can compare the two approaches and answer "why didn't you just do it the Postman way?" with evidence. A matching `run-tests-2.ps1` is the next step and is not built yet.

**Why:** The brief names Postman and Newman, and the assessors may expect a plain Postman collection. Having both lets me show the trade-offs (one importable file with no build step, against small source files, shared bodies and a build script) and that I considered more than one way.

**What the AI gave:** Its opinion first (worth doing, but only a fair comparison if the second file is genuinely written the Postman way, and best after the pipeline and docs). It then pointed out that the authored collection already looks like what the export would become, and offered to copy folders 2 to 5 from it; I chose to have them written fresh instead. It wrote the helpers and the POST, GET by id, OData and data integrity requests into the export file from the API contract and the seed data, reformatted the file, and ran it with Newman twice from a reset database: 139 requests, 282 assertions, 0 failed, exit code 0. One test failed on the first run because its expected ids were wrong (the API was right); it corrected the test.

**What I did:** Asked for the second option and its purpose, clarified what I meant by the Postman way, chose to have the requests written fresh and not copied, and asked for the work to be done. I did not type any of this file myself. I did not change `tests/authored/`.

**Outcome:** The export collection is complete and passes against a freshly reset database.

---

### 24. Both Postman suites should cover the same test cases

**Prompts:**
> Why do we not have the same tests in the authored and postman tests?
> Should not both have the all the tests? Explain why
> Yes, go ahead with the union

**Decision:** Both suites should hold the same set of test cases (the union of the two), so the comparison between them is about how the suites are built and maintained, not about what they test.

**Why:** The two suites were written independently, so each had cases the other lacked (for example extreme speed and heading values, the rounding case and the 101-character id on one side; null and boolean types, an empty body and just-outside-the-boundary values on the other). With different content, a difference in size or effort could not be blamed on the approach. It also means each suite is a full safety net on its own.

**What the AI gave:** An explanation of the gap (the export was written fresh from the contract, not copied), a list of the real differences between the suites, and the argument for merging them. After my go-ahead it added 28 requests to the authored sources (one file per request, bodies in `bodies/`, the collection rebuilt) and 18 to the export file, then ran both suites twice from a reset database: authored 311 assertions, export 323, 0 failed, exit code 0 each time. It also told me the request counts are not identical (139 against 145) because some cases are variants of each other, which is why the claim is "same cases covered", not "identical tests".

**What I did:** Asked why they differed, asked whether both should have everything, and approved the union, including changes under `tests/authored/src/`, which I had earlier said not to touch for the export work. I did not type the new requests.

**Outcome:** Both suites pass and cover the same cases.

---

### 25. One settings file for the scripts and the API

**Prompts:**
> why do we call it .env.example?
> do the values require '' or "" ?
> Check if my run tests is correct (the comments as well)

**Context:** I also pasted screenshots of the runs, including a failed run with a leftover `DB_NAME`, the API start and the optional `OtherDb` check.

**What the AI gave:** The contents of `.env.example` and why the `.example` name is used (the `.gitignore` already ignores `.env` and keeps `.env.example`). A loader function in `scripts/load-env.ps1` in small pieces (find the names, then set the values, skipping blank values and variables that are already set). The edits to `run-tests.ps1`, `start-api.ps1` and `validation-check.ps1`. A change to `Program.cs` so the API builds its connection string from the separate DB settings when `DB_CONNECTION_STRING` is not set (decision D18). It spotted the stale comment I had left on line 5 of `run-tests.ps1`, explained that the failed run was my own leftover `DB_NAME=OtherDb` being respected, and ran the `OtherDb` check itself because my attempt had a placeholder key and no API running. It checked that `.env` was ignored by git and that the key in it matched the old local script, without printing the key.

**What I did:** Created `.env.example` and `.env`, typed the loader, the script changes and the `Program.cs` edit, ran `run-tests.ps1` from fresh terminals (311 assertions, 0 failed, exit code 0, also after I deleted `scripts/set-env.local.ps1`), started the API with the new script, and sent my results back each time. I deleted the line 5 comment myself and deleted the old settings script.

**Outcome:** The API key and database settings now come from `.env` (or from real environment variables, which win), and the old local settings script is gone.

---

### 26. SQL authentication in the reset step of the run script

**Prompts:** A short reply to start with the SQL authentication step, then screenshots of the normal run and of a run with a fake `DB_USER` and `DB_PASSWORD`.

**What the AI gave:** The replacement for the two `sqlcmd` calls in `scripts/tests/run-tests.ps1`: Windows authentication (`-E`) when `DB_USER` is not set, SQL authentication (`-U`, with the password passed through the `SQLCMDPASSWORD` variable so it is not on the command line, and `-C` for the container's self-signed certificate) when it is. It gave two checks: a normal run, and a run with a fake login to prove the SQL branch is taken. It read the edited script afterwards to check the comments and the code, and updated `docs/HANDOFF.md`. It said plainly that the SQL branch against a real SQL login is not verified yet, because LocalDB normally allows only Windows authentication, and that the first real test will be the pipeline's SQL Server container.

**What I did:** Made the change in `run-tests.ps1`, ran both checks and sent the results. The normal run gave exit code 0 with 311 assertions and 0 failed; the fake login gave `Login failed for user 'nobody'` and `Cleanup failed. Is the database reachable?`, then I removed the test variables.

**Outcome:** The reset step supports both authentication modes. The SQL login path still needs a real test in the pipeline.

---

### 27. The bash run script for the Linux pipeline agent

**Prompts:** A short reply to start with `run-tests.sh`, then the results after each of the four pieces, including a run with a wrong key and a normal run.

**What the AI gave:** The script `scripts/tests/run-tests.sh` in four pieces, mirroring `run-tests.ps1`: a `.env` loader with the same rules as `load-env.ps1` (skip comments and blank values, never overwrite a variable that is already set); the database reset with `sqlcmd` (Windows authentication, or SQL authentication when `DB_USER` is set); starting the API only if it is not running and always stopping the one it started with a `trap`; and the Newman run that ends with Newman's exit code. It spotted before I hit it that the default `DB_SERVER` and `DB_NAME` had to be exported or the API would ignore them. It explained the bash parts I had not used before (`set -euo pipefail`, `${VAR:-default}`, arrays for the `sqlcmd` options, `trap ... EXIT`, `|| newman_exit=$?`). After my runs it checked the one result I had not shown (the exit code for a failing run, which gave 1), read the finished script, and updated `docs/HANDOFF.md`. It said which parts are not verified yet: `sqlcmd` on the Linux agent's PATH, the SQL authentication branch against a real login, and the file mode on Linux.

**What I did:** Typed each piece, ran it in Git Bash after each piece, and sent the results. The final checks were a failing run (a wrong key, 233 failed assertions, exit code 1) and a passing run (311 assertions, 0 failed, exit code 0, the API stopped, and the JUnit and HTML reports and the API log written to `tests/reports`).

**Outcome:** One command now runs the suite in bash, ready for the pipeline step, though it has only been run on Windows so far.

---

### 28. The Azure DevOps pipeline

**Prompts:** Short replies and questions as I went through the pieces (what to do next, where to insert the steps, the piece 3 file again), with screenshots of the runs, the repository selection, the GitHub app authorisation, the variable dialog and each step's log.

**What the AI gave:** The pipeline in five small pieces. Piece 1 showed what the Ubuntu agent already has; the log showed `sqlcmd` missing, several .NET SDKs (including an 11 preview that `dotnet` would pick) and Node 24, so piece 2 pinned the .NET 9 SDK, installed a standalone `sqlcmd` build and installed Newman and the htmlextra reporter at fixed versions. It looked up the release files on GitHub instead of guessing the download name, and explained why it avoided the apt route (not documented for the agent's very new Ubuntu version). Piece 3 added SQL Server as a service container, a wait loop, and the schema and seed, with the password in a secret variable. Piece 4 ran `scripts/tests/run-tests.sh`. Piece 5 added cleanup, the JUnit results and the report artifact, all under `condition: always()`. It explained the YAML and the parts I had not used before (`services`, `##vso[task.prependpath]`, mapping secret variables with `env:`), warned that a missing `API_KEY` variable would pass silently with a literal key, told me not to click the editor's Save when it would commit, and updated `docs/HANDOFF.md`.

**What I did:** Created the Azure DevOps organisation and project, connected the GitHub repository and authorised the Azure Pipelines app, typed each piece into `azure-pipelines.yml`, created the secret variables `DB_PASSWORD` and `API_KEY` (my own values), committed and pushed each piece, and sent the logs back. I renamed the file from `.yaml` to `.yml` to match the planned layout.

**Outcome:** Each push runs the whole suite on a Microsoft-hosted agent. The last run passed in about 1.5 minutes with 311 assertions and 0 failed, showed "100% passed" on the Tests tab, and published the reports as an artifact.

---

### 29. The second run script, run-tests-2.ps1

**Tool:** Claude Code

**Prompt:** "Start on run-tests-2.ps1", then "Because we are testing 2 different strategies, I think we need to keep them separate, this is also to compare the 2 solutions"

**What the AI gave:** A table of the three differences between the two options (no build step, its own collection and environment files, its own report names) and a plan that moved the shared steps into a common file. After my correction it dropped that plan and wrote `scripts/tests/run-tests-2.ps1` as a standalone copy of `run-tests.ps1` with only those three differences, and ran it twice.

**What I did:** Rejected the shared-file plan because the scripts are part of the comparison of the two options and should stay separate. `run-tests.ps1` was left untouched.

**Outcome:** Both runs gave exit code 0 with 323 assertions and 0 failed, and the API was started and stopped by the script. Reports go to `tests/reports/newman-export-*`.

---

### 30. Comparison of the two Postman suites in SOLUTION.md

**Tool:** Claude Code

**Prompt:** "Draft the comparison of the two suites", then "Put it in SOLUTION.md"

**What the AI gave:** Measured both suites in the repo (request counts, source files, line counts, build step) and drafted a comparison: a table, what was easier and harder in each option, the two run scripts, and which option the pipeline runs. It listed what was not measured and said I should confirm the stated reason for choosing the authored suite. After the second prompt it created `SOLUTION.md` with only that section and marked the file as work in progress.

**What I did:** Asked for the draft and then for it to be placed in `SOLUTION.md`.

**Outcome:** `SOLUTION.md` now exists with the comparison section.

---

### 31. First draft of README.md

**Tool:** Claude Code

**Prompt:** "Start on README.md"

**What the AI gave:** Read the old stub, `.env.example` and the schema script, then wrote a full first draft of `README.md`: what the API does, prerequisites, the settings table, creating the database once, running the tests with the PowerShell and bash scripts, the second option, how test data is kept apart, the pipeline, the folder layout and links to the other docs.

**What I did:** Asked for the start of the README.

**Outcome:** `README.md` replaced the stub with a draft. I then ran its first step in a fresh terminal (the schema script) and it worked. Later prompt: "Add the start api but state it as part of the testing phase for when we started", which added a "Start the API by hand" section describing `scripts/start-api.ps1` as the way testing started by hand.

---

### 32. The rest of SOLUTION.md

**Tool:** Claude Code

**Prompt:** "Start on the rest of SOLUTION.md"

**What the AI gave:** Read BUILD_NOTES (decisions D1 to D24, assumptions) and drafted the remaining sections around the existing comparison: approach, test strategy by folder, test data management, the pipeline, assumptions and behaviours the brief does not state, known limitations, how AI tools were used, and "decided not to do". It listed the claims that only I can confirm.

**What I did:** Asked for the draft.

**Outcome:** `SOLUTION.md` now has a full first draft.

---

### 33. What to do next, and examples of failed and skipped tests

**Tool:** Claude Code

**Prompt:** "1. What do you recommend and why? 2. We need examples of failed tests and skipped tests"

**What the AI gave:** A recommendation for each open decision (OData option-name case, `validation-check.ps1`, the AI-tooling file mentions, `docker-compose.yml`) with reasons. For failed and skipped tests it first tested Newman 6.2.3 with a throwaway collection outside the repo: `pm.test.skip` is supported and shows as `[skipped]` in the CLI output, but the JUnit export lists a skipped test as a normal passing test case, so the Azure DevOps Tests tab would count it as passed. It then proposed keeping the real suite green and adding a separate demo collection with a deliberately failing and a skipped test, run only through an optional pipeline parameter.

**What I did:** Asked the two questions.

**Outcome:** Nothing in the repo changed in this step.

---

### 34. The failure demo collection and pipeline parameter

**Tool:** Claude Code

**Prompt:** "Yes, do the demo collection and pipeline parameter"

**What the AI gave:** `tests/demo/failure-demo.postman_collection.json` (one passing test, two deliberate failures and one skipped test against the seeded data); an optional `demo` argument for `scripts/tests/run-tests.sh` instead of a third run script, with the default behaviour unchanged; and in `azure-pipelines.yml` a boolean parameter `runFailureDemo` (default false) that adds a demo step and a separate test-results step only when ticked. It also added a README section, a layout line and two SOLUTION.md paragraphs (the failing run, and that a skipped test shows as passed in the JUnit export). It ran the demo locally in Git Bash (exit code 1, 4 assertions, 2 failed, 1 skipped, API stopped), a bad argument (exit code 1 with a message) and the normal run (exit code 0, 311 assertions, 0 failed).

**What I did:** Approved the design, committed and pushed it, then ran the pipeline by hand with "Also run the failure demo" ticked and sent screenshots of the result.

**Outcome:** Verified. The normal push run stayed green. The manual run failed as intended at the demo step ("Bash exited with code 1"), the stage showed 99.3% tests passed, and the artifact held both the real and the demo reports. The demo HTML report showed 3 assertions, 2 failed and 1 skipped; the real report showed 155 requests, 311 assertions and 0 failed.

---

### 35. docker-compose.yml for SQL Server

**Tool:** Claude Code

**Prompt:** "Do the docker-compose.yml"

**What the AI gave:** `docker-compose.yml` with one service, the SQL Server 2022 image the pipeline uses, port 1433, the `sa` password taken from `DB_PASSWORD` in `.env` (it refuses to start without it) and `platform: linux/amd64` for Apple Silicon. It added a "Without LocalDB (Docker)" section to the README with the steps (settings in `.env`, `docker compose up -d`, creating the database with `sqlcmd`, running the tests, `docker compose down`), a layout line, and one sentence in the SOLUTION.md approach table.
**What I did:** Asked for the file. Testing it needed a machine with Docker, and the AI ran the test once Docker was available. I did not run the compose test myself.

**Outcome:** Verified. The AI started the container with `docker compose up -d`, waited for SQL Server (ready in about 8 seconds), applied `db/01_schema.sql` and ran `run-tests.ps1` twice against it, using a throwaway password in its own session so my `.env` was untouched. Both runs gave exit code 0 with 311 assertions and 0 failed. A blank `DB_PASSWORD` stopped compose with a clear message, and `docker compose down` left nothing behind. Not tried: Apple Silicon, and `run-tests.sh` against the container.

---

### 36. Read-through of SOLUTION.md and four fixes

**Tool:** Claude Code

**Prompts:** "Walk me through SOLUTION.md"; then "Apply fixes 1 to 4, with number 4 I chose".

**What the AI gave:** A section-by-section walk through `SOLUTION.md`, flagging four things to fix: the "No Docker needed on my machine" wording (Docker is installed now), `BASE_URL` missing from the list of plain pipeline settings, "204 small source files" counting `helpers.js` twice, and a sentence claiming I had asked the recruiter about the date format and status codes, which my older notes did not clearly support. It applied the four fixes, using wording for the last one that does not claim I asked. While checking it also found that a comment it had written in `azure-pipelines.yml` ("can be overridden when the pipeline is run") was wrong for variables defined in the YAML, and corrected it.

**What I did:** Read the walk through, decided to apply all four fixes, and chose how the recruiter sentence should read.

**Outcome:** `SOLUTION.md` and the comment in `azure-pipelines.yml` updated.

---

## What I reviewed or corrected myself

- Found the validation gap with my own before-fix test, before any AI suggested it (`docs/evidence/`).
- Found a timestamp format mismatch in my hand tests and had it fixed (D14).
- Found that a 400 that looked wrong was PowerShell mangling quotes in `curl.exe`, not an API bug.
- Found that Claude chat's prediction about long `id` and `deviceId` values was wrong: they were saved as 201, not a 500, because the SQL driver silently truncates strings (see C5).
- Caught a stale claim in my working notes that D16 was not applied, when the code already had it.
- Built most of the validation script in small pieces that I typed and ran, and decided it should clean and seed the database itself so it can be re-run.
- Decided where the API key lives: in a gitignored local file, never in the repository.
- Stopped the AI from committing; I commit and push myself.

## Not covered

- The Claude chat conversations are summarised in Part 0, not quoted word for word.
