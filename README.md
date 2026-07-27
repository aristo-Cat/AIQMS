# AI-QMS — an AI-first electronic Quality Management System

A bespoke eQMS for regulated (GxP) manufacturing, built in the open — with the complete
validation package produced alongside the software rather than after it.

> **Status: bootstrapped.** The project manifest and layout exist; `specs/` is still empty.
> Nothing here is validated, and no claim of regulatory compliance is made or implied.
> Watch this file — status changes as the cascade fills in.

## What this is

Most quality-management systems treat AI as a feature bolted onto an existing workflow.
This one is specified the other way round: assistive agents are part of the system from the
requirements up, and the requirements that govern them — traceability of model output,
mandatory human review, model and prompt version control, assistant evaluation over
time — are written before any code exists.

The system covers six quality processes — deviations, CAPAs, change control, audits
received, audits performed, and general quality events — sharing one record lifecycle
(event → investigation → action → closure → effectiveness check). Records are primary GxP
records: tamper-evident, audit-trailed, and electronically signed at defined approval steps.

Every AI contribution is **advisory**. An agent may propose a root-cause hypothesis, surface
precedent records, draft an investigation narrative, or flag an incomplete record — a human
owns the decision and signs it. That boundary is a requirement, not a convention.

## Why it is public

The deliverable is two things at once: working software, and an inspectable demonstration
that AI-assisted development can produce audit-grade evidence. The second is the harder
claim, so the specifications, risk assessments, qualification protocols and traceability
matrix are published as they are written — including the parts that are still open.

Read it as a worked example. If you build regulated software, the interesting question is
whether the traceability actually holds end to end; the repository is arranged so you can
check rather than take it on faith.

## What is here

| Path | Contents |
|---|---|
| `IDEA.md` | The original idea brief — the input the requirements were interviewed from |
| `.gxp-dev.yaml` | Project manifest: mode, GAMP category, regulatory presets, active templates |
| `CONTEXT.md` | Living domain glossary — terms fixed as they settle |
| `specs/` | The specification cascade: URS → RA-INIT → FS → RA-DET → DS → IQ/OQ/PQ → VR, with RTM derived |
| `work/` | Execution plans, one folder per work item |
| `evidence/` | Qualification and implementation evidence |
| `compliance-bundle/` | Inspector-facing package, assembled on demand |
| `src/` · `tests/` | Application source and tests (not yet started) |

Requirement identifiers follow `<DOC-TYPE>-<CATEGORY>-<NNN>` — a requirement in the URS
(`URS-FUNC-001`) is traceable through the functional specification, the design, the risk
assessment and the test protocols that exercise it. That chain is what the RTM checks.

Project decisions, open questions and known gaps are tracked locally in `STATE.md`, which is
deliberately not published; anything load-bearing is restated in the specifications themselves.

## Regulatory frame

GAMP category 5 (custom-built), `develop` mode, `regulated` rigor. Active presets: 21 CFR
Part 11, EU GMP Annex 11, GDPR. EU GMP Annex 22 (AI in GMP) is declared as the governing
reference for the AI component — its current status must be verified against EudraLex before
it is cited as binding, and the AI-specific requirements are authored explicitly rather than
inherited from a preset.

## Tooling

Specifications are produced with [gxp-driven-dev](https://github.com/aristo-Cat/gxp-driven-dev),
an open-source spec-driven development toolkit, pinned at commit **`dd91827`**.

The toolkit is not vendored into this repository — it is a separate project with its own
history. To run the `/gdd.*` commands against this project, clone the toolkit at that commit
into this working directory (its files are git-ignored here) or point your agent at a clone
elsewhere on disk. Reading the artifacts requires nothing but a Markdown viewer.

## License

Apache License 2.0 — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
