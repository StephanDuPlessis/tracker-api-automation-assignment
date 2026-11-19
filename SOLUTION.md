# Solution

Design, trade-offs and assumptions for the Tracker Connect API automation assignment.

> Work in progress: only the comparison of the two Postman options is written so far.

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
