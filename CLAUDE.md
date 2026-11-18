@.github/copilot-instructions.md

# Claude Code notes

The file imported above is the shared project context. Claude Code and GitHub Copilot both work on this repo and must follow it, so do not duplicate or contradict it here. If something needs to change, change it in `.github/copilot-instructions.md`.

# Session start

1. Read `docs/HANDOFF.md` first. It says what is done, what is in progress and what comes next.
2. Run `git status` and `git log --oneline -5` to see the real state of the repo. If it disagrees with HANDOFF.md, trust git and say so.
3. Do only the task you are given. Do not start the next step on your own.

# Session end

After every task, update `docs/HANDOFF.md` (Current state, In progress, Next step) so the other agent, or a fresh session, can continue with no chat history. Do not put dates or times in any file. Suggest a `docs/BUILD_NOTES.md` entry but do not write it unless asked.

# Keeping tokens low

- Read only the files the task needs. Do not re-read the whole repo.
- Prefer small, single-purpose changes, and stop when the task is done.
