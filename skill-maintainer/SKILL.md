---
name: skill-maintainer
description: >-
  Maintains the user's Cursor skills Git repository at ~/.cursor/skills: stage,
  commit, and push after creating or editing skills. Use when the user adds or
  changes files under ~/.cursor/skills, mentions committing skills, syncing
  skills to GitHub, or works on SKILL.md or skill scripts. Does not apply to
  project code outside the skills repo.
---

# Skill maintainer

## Repository

- **Root:** `~/.cursor/skills` (Git repo; remote e.g. `origin` on GitHub).
- **Tracked content:** skill folders (`*/SKILL.md`, `*/scripts/*`, etc.).
- **Never commit:** `~/.atlassian_config`, API tokens, or any file outside this directory unless the user explicitly asks.

## When to run this workflow

After **creating**, **editing**, or **deleting** anything under `~/.cursor/skills/`:

1. Confirm the working tree is the skills repo: `cd ~/.cursor/skills` (or use absolute paths with `git -C ~/.cursor/skills`).
2. Show status: `git status`.
3. Stage only skill-related changes: `git add` the relevant paths (or `git add .` if the entire change set is intentional).
4. Commit with a **Conventional Commits**–style message:
   - `feat(skills): add <skill-name>` — new skill
   - `fix(skills): <what changed>` — bugfix in a skill
   - `chore(skills): <what changed>` — docs, scripts, refactor without behavior change
   - `docs(skills): update <skill-name>` — SKILL.md only
5. If the user wants remote updated: `git push` (requires network permission).

Example:

```bash
git -C ~/.cursor/skills status
git -C ~/.cursor/skills add jira-reader/SKILL.md
git -C ~/.cursor/skills commit -m "docs(skills): clarify JQL examples in jira-reader"
git -C ~/.cursor/skills push
```

## Workspace note

If the Cursor workspace is **not** opened at `~/.cursor/skills`, the agent may still run `git -C "$HOME/.cursor/skills"` so commits apply to the skills repo without moving the user's project root.

## End of task

If the user asked to create or change a skill, **do not stop** until either:

- the changes are committed (and pushed if they asked), or  
- the user declines commit/push.

If `git` fails (no repo, merge conflict), explain and offer next steps.

## Security

- Do not paste secrets into commit messages.
- If a skill accidentally references token paths, remind the user that `~/.atlassian_config` should stay **untracked** and never be copied into `~/.cursor/skills`.
