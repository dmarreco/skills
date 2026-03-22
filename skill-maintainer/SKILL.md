---
name: skill-maintainer
description: >-
  Maintains the user's Cursor skills Git repository at ~/.cursor/skills: stage,
  commit, and push after creating or editing skills; keeps README.md at the
  skills repo root in sync with the list of skills. Use when the user adds or
  changes files under ~/.cursor/skills, mentions committing skills, syncing
  remotes, or works on SKILL.md, skill scripts, or README.md. Does not apply to
  project code outside the skills repo.
---

# Skill maintainer

## Repository

- **Root:** `~/.cursor/skills` (Git repo; remotes e.g. `origin` and backup like `github`).
- **Tracked content:** skill folders (`*/SKILL.md`, `*/scripts/*`, etc.) and **[README.md](../README.md)** at repo root.
- **Never commit:** `~/.atlassian_config`, API tokens, or any file outside this directory unless the user explicitly asks.

## Project-local skills

Some skills are **not** in `~/.cursor/skills`—they live under another repo’s `.cursor/skills/<name>/` (e.g. epic-planning). **Do not** expect them in this README’s table; the user commits them with that project. If one is **moved** into or out of this repo, update **[README.md](../README.md)** (project-local note + table rows) as part of the change.

## README.md (skills index)

The repo root **[README.md](../README.md)** lists every skill with a one-line description. **Keep it up to date** whenever skills are added, removed, or materially renamed:

- After **adding** a skill: add a row to the table (folder name in bold, short description from the skill’s purpose).
- After **removing** a skill: remove its row and update the layout tree if present.
- After a skill’s **scope changes** enough to change how you’d describe it: update that row.

Stage and commit README changes with the same skill change when possible (one commit), or `docs(skills): sync skills README` if only documentation/index changed.

## When to run this workflow

After **creating**, **editing**, or **deleting** anything under `~/.cursor/skills/`:

1. Confirm the working tree is the skills repo: `cd ~/.cursor/skills` (or use absolute paths with `git -C ~/.cursor/skills`).
2. If the change affects which skills exist or what they do, **update [README.md](../README.md)** (see “README.md” above).
3. Show status: `git status`.
4. Stage only skill-related changes: `git add` the relevant paths (include `README.md` when updated) (or `git add .` if the entire change set is intentional).
5. Commit with a **Conventional Commits**–style message:
   - `feat(skills): add <skill-name>` — new skill
   - `fix(skills): <what changed>` — bugfix in a skill
   - `chore(skills): <what changed>` — docs, scripts, refactor without behavior change
   - `docs(skills): update <skill-name>` — SKILL.md only
   - `docs(skills): sync skills README` — README.md index only
6. If the user wants remote updated: `git push` (requires network permission).

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
