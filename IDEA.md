# Idea brief — AI-first electronic Quality Management System (ai-qms)

> Input to `gdd.urs.from-idea`. Decisions captured in the `/gdd.start` session of 2026-07-27.

We are building a bespoke electronic QMS for regulated (GxP) manufacturing, comparable in
scope to established eQMS platforms but designed **AI-first**: assistive agents are a
first-class part of the system, not a bolt-on. The system covers six quality processes —
deviations, CAPAs, change control, audits received (inspections and customer audits), audits
performed (internal and supplier), and general quality events. All six share one **quality
record lifecycle** (event → investigation → action → closure → effectiveness check), so the
requirements are organized as a common core plus six specializations rather than six
independent modules.

Records created here are **primary GxP records**: tamper-evident, fully audit-trailed, and
signed electronically at the defined approval steps (21 CFR Part 11 and EU GMP Annex 11
apply). Users are quality and manufacturing staff in a regulated company; the regulator or a
customer auditor is an implicit second audience, since the system's own output is what they
inspect.

The AI-first part is where this differs from a classical eQMS and where the hardest
requirements live. Assistive agents help investigators do the work: propose root-cause
hypotheses from the event description and history, surface precedent records, draft
investigation narratives and CAPA proposals, classify and route incoming events, and check a
draft record for completeness before submission. Every one of those is **advisory**: a human
owns the decision and signs it. That imposes requirements a classical QMS does not have, and
they must be specified rather than assumed — traceability of model output (which model,
which prompt version, which retrieved context produced a given suggestion), mandatory human
review before any AI-influenced content enters a signed record, versioning and change control
of models and prompts as configuration items, evaluation of assistant quality over time, and
explicit handling of non-determinism and hallucination as risks in the risk assessment. EU GMP
Annex 22 (AI in GMP) is the governing reference for that component and is expected to be an
active preset, bringing the `AISC` template into the active set.

The software is custom-built by us, which puts it at **GAMP category 5** and makes `develop`
the operating mode. It runs the full regulated cascade (URS → RA-INIT → FS → RA-DET → DS →
IQ → OQ → PQ → VR, with the RTM derived), because producing a complete, inspectable
validation package end-to-end is an explicit objective of this project and not only a
byproduct.

## Open questions for the URS interview

Deployment model (multi-tenant SaaS, single-tenant hosted, or on-premise) is undecided and
materially changes the infrastructure and data-residency requirements. Whether the AI
assistants call an external model provider or a self-hosted model is likewise open, and it
drives the supplier assessment, the data-protection analysis, and what "qualified model" means
here. Integrations with adjacent systems (document management, training records, LIMS, ERP)
are out of scope for the first pass but should be anticipated as interfaces. Whether the
system must support more than one language in the record content is undecided.
