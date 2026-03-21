---
name: epic-planning
description: >-
  Structures epic planning in the workspace under epic-planning/ using agreed
  folder names, Jira reference exports, a decisions log, and a PLAN.md with
  specification and candidate stories. Use when the user plans a Jira epic,
  sprint scope, child stories, enablers, or works under epic-planning/. The
  skill file must never contain real issue keys or confidential Jira content;
  all epic-specific data stays in the workspace repo.
---

# Epic planning (agent workflow)

## Confidentiality (hard rules)

- This skill is intended for **public or shared** skill repositories. **Do not** put real Jira issue keys, epic titles, customer or org names, pasted descriptions, comments, or XML/JSON in `SKILL.md` or in skill repo files when “saving” planning.
- **All** epic-specific content belongs under **`<workspace>/epic-planning/<folder>/`** in the project workspace only.

## Where files live

| Location | Content |
|----------|---------|
| `<workspace>/epic-planning/README.md` | Short pointer; **no** templates or scripts here—only per-epic subfolders and this README. |
| `<workspace>/epic-planning/<JIRAKEY-ShortName>/` | `epic-reference.xml`, `epic-reference.json`, `decisions.md`, `PLAN.md` |
| `~/.cursor/skills/epic-planning/` | `SKILL.md`, `scripts/fetch-jira-epic.sh`, `templates/*.template.md` (generic only) |

Never create per-epic data under `~/.cursor/skills/` (except generic templates and scripts).

## Folder naming

1. User provides an epic **issue key** and an agreed **short name** (ASCII slug, hyphens).
2. Create: `epic-planning/<JIRAKEY-ShortName>/` (example pattern only: `PROJ-1234-feature-name` — use the user’s actual key and name).

## Bootstrap a new epic folder

1. Create the directory under `epic-planning/`.
2. Run the fetch script (requires network permission and `~/.atlassian_config`):

```bash
chmod +x ~/.cursor/skills/epic-planning/scripts/fetch-jira-epic.sh   # once
~/.cursor/skills/epic-planning/scripts/fetch-jira-epic.sh "<EPIC-KEY>" "<workspace>/epic-planning/<JIRAKEY-ShortName>"
```

3. Copy templates from the skill into the epic folder (adjust titles only inside the workspace files):
   - `~/.cursor/skills/epic-planning/templates/PLAN.template.md` → `PLAN.md`
   - `~/.cursor/skills/epic-planning/templates/DECISIONS.template.md` → `decisions.md`

4. **PLAN.md** must include:
   - **Specification:** problem, goals, non-goals, constraints.
   - **Scope:** default **two sprints** of **two weeks** each (**four weeks** total); keep story count **controlled** (typical guidance: a small number of delivery stories plus optional enablers unless the user expands scope).
   - **Candidate child issues / user stories** and optional **enabler** rows (PoC, HLD, LLD, spike) only when they unblock delivery inside the window.
   - **Out of scope / follow-up** for work owned elsewhere or later epics.

5. **decisions.md:** append dated decisions (context, decision, rationale, alternatives). Link to Jira in the workspace file only; do not paste secrets.

## Jira API (read-only)

- Use the same credentials pattern as the **jira-reader** skill (`~/.atlassian_config`).
- Do **not** create, edit, or transition Jira issues from this workflow unless the user explicitly asks and uses a different process.

## Child issues in Jira

Epic children may require a **JQL** search (`/rest/api/3/search`) with the project’s epic link field. Document candidate stories in **PLAN.md**; creation in Jira is a separate step unless the user requests otherwise.

## Git

- Changes under `epic-planning/<epic>/` in the **workspace** repo: commit with the product repo.
- Changes to **`~/.cursor/skills/epic-planning/`**: commit in the **public skills** repository — **generic** edits only.

## Related skills

- **jira-reader** — read-only issue/comment fetch patterns.
- **skill-maintainer** — if updating the public skills repo commit workflow.
