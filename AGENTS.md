# AI-QMS — AI-first electronic Quality Management System — AI Agent Contract (AGENTS.md)

This repository is a **consumer project** built on the
[gxp-driven-dev](https://github.com/aristo-Cat/gxp-driven-dev) template clone.
The target system is **AI-QMS — AI-first electronic Quality Management System** (`AIQMS-2026-001`) — specs, work items,
and evidence in this repo belong to it. `CLAUDE.md` imports this file via `@AGENTS.md`.

## How to work here

- `.gxp-dev.yaml` at this root is the manifest every skill reads first; move harness
  states only with `python skills/_scripts/transition-harness-state.py`.
- Author the target system's artifacts through the toolkit commands (`/gdd.next` routes;
  `docs/user-manual.md` is the full manual). Deliverables land in `specs/`, `work/`,
  and `evidence/` — chat is never evidence.
- **Never invent — mark.** When you cannot answer (an ID, a citation, a value), write
  `[NEEDS CLARIFICATION: …]` instead of guessing.
- Never weaken a gate (`skills/_scripts/*.py`, `validation_rules`, presets) to make it pass —
  fix the spec or the evidence, never the rule.

## The toolkit lives outside this repository

This project consumes [gxp-driven-dev](https://github.com/aristo-Cat/gxp-driven-dev) at pinned
commit `dd91827` — the **standalone** layout (`docs/project-layout.md` § "Two supported
layouts"). Its files (`skills/`, `templates/`, `patterns/`, `docs/`, `adapters/`, `examples/`,
`.claude/`, `.codex/`, `.agents/`, `.githooks/`, `.github/`) sit in this working directory so
the `/gdd.*` commands resolve, but they are **git-ignored and not part of this product**:

- Never edit them here and never commit them. A toolkit defect found while working on AI-QMS
  is fixed upstream in the toolkit's own repository, then re-pinned here.
- Because the toolkit occupies `docs/` and `.github/` on disk, this project must not use those
  paths for its own content.
- `.claude/skills/` and `.codex/prompts/` are **generated** mounting points; if the pin moves,
  regenerate them with `python skills/_scripts/sync-vendor-skills.py --write`.
