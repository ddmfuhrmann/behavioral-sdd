# Development Workflow — behavioral-sdd

> Portuguese version: `docs/workflow.pt-br.md`

## Overview

This workflow is **spec-driven and plan-first**: no code is written without a saved plan. Context is preserved across steps via local `.plans/` files, and responsibilities are distributed across isolated subagents to prevent context from one step contaminating another.

Key design decisions:

- **`f-` prefix** — avoids collision with native Claude Code skills (`/plan`, `/review`, `/test`).
- **Grill-me as a conversational loop** — integrated into `/bsdd-plan` via `AskUserQuestion`, one question at a time, no separate command.
- **`/bsdd-implement` orchestrates implement + test + correction loop** — no need to invoke `/test` separately.
- **`/bsdd-ship` unifies review + ADR check + handoff** — one command to close the cycle.
- **Integrations isolated in Haiku 4.5** — `git-agent` is cheap and focused; domain agents never call git directly.
- **`caveman` and `karpathy-guidelines` always active** — all agents load these skills by default.

---

## Main Flow

```
[free conversation / ticket / PRD]
         │
    /bsdd-prd  (optional — larger-scope features)
         │
    /bsdd-plan  ──→  [grill-me loop via AskUserQuestion]  ──→  plan saved in .plans/
         │
    /bsdd-implement <title>
         ├──→  [feature-implementer]  (writes production code)
         ├──→  [test-implementer]     (writes and runs tests)
         └──→  auto-correction loop (up to 3x, then checkpoint)
         │
    /bsdd-ship
         ├──→  [git-agent]    (gets diff)
         ├──→  [reviewer]     (audits diff vs plan)
         ├──→  findings grill-me via AskUserQuestion
         ├──→  ADR check via AskUserQuestion
         ├──→  handoff grill-me via AskUserQuestion
         ├──→  saves artifacts to .ship/YYYY-MM-DD-<title>/
         └──→  [git-agent]    (creates PR)
```

**Flow with optimize:**

```
    /bsdd-implement <title>
         │ (on complete: AskUserQuestion — run /bsdd-optimize?)
         ↓
    /bsdd-optimize <title>
         └──→  [optimizer]    (baseline → analysis → loop)
              saves report to .plans/YYYY-MM-DD-<title>-optimization.md
         ↓
    /bsdd-ship
```

**Flow with PRD:**

```
    /bsdd-prd
         ├──→  grill-me via AskUserQuestion
         └──→  saves .prds/YYYY-MM-DD-<title>.md
         ↓
    /bsdd-plan  (reads the PRD as input)
```

---

## Main Commands

### /bsdd-plan

Entry point of the cycle. Accepts any input (conversation, ticket, PRD, vague idea).

1. Uses the native Plan agent to explore the codebase.
2. Produces a structured plan with 10 sections: Understanding, Assumptions, Scope, Out of scope, Approach, Files likely to change, Tests needed, Risks, Performance criteria, Blocking questions.
3. Starts automatic grill-me — one question at a time via `AskUserQuestion`.
4. Saves refined plan to `.plans/YYYY-MM-DD-<title>.md`.

### /bsdd-implement \<title\>

Orchestrates the full implementation. The argument is the kebab-case plan title.

1. Reads `.plans/YYYY-MM-DD-<title>.md`.
2. Spawns `feature-implementer` (production code).
3. Spawns `test-implementer` (tests).
4. If tests fail: automatic correction loop (up to 3x), then checkpoint via `AskUserQuestion`.
5. On success: asks whether to run `/bsdd-optimize`.

### /bsdd-ship

Closes the cycle. Can be used outside the pipeline to revisit previous deliveries.

1. Spawns `git-agent` to get the diff.
2. Spawns `reviewer` with plan + diff + summaries.
3. Interactive findings grill-me (BLOCKER → fix now, WARNING → defer, SUGGESTION → open issue).
4. ADR check: detects architectural decision candidates, asks whether to register.
5. Handoff grill-me: next step, pending decisions, production risks.
6. Saves all artifacts locally in `.ship/YYYY-MM-DD-<title>/`.
7. Spawns `git-agent` to create PR.

---

## Complementary Commands

### /bsdd-optimize \<title\>

Plan-driven performance optimization. Behavior determined by the **Performance criteria** field in the plan.

- **With measurable criteria** (e.g. `p95 < 200ms`): optimizer runs autonomously — baseline → analysis → change → re-measurement → loop. Checkpoint every 3 attempts.
- **Without criteria**: optimizer collects baseline and produces findings without applying changes.

In both cases, the report is saved locally in `.plans/YYYY-MM-DD-<title>-optimization.md`.

### /bsdd-prd

Creates a PRD via conversational grill-me. Use for larger-scope features before `/bsdd-plan`. One question at a time: name, problem, measurable objective, requirements, out of scope, acceptance criteria, blockers.

### /bsdd-sync-patterns

Scans the source tree and rewrites `.skills/patterns.md` with updated canonical snippets. Run after implementing a new pattern that other agents should follow.

---

## Quick Reference

| Command | When to use |
|---|---|
| `/bsdd-prd` | Before plan, for larger-scope features |
| `/bsdd-plan` | Always — entry point of the cycle |
| `/bsdd-implement <title>` | After grill-me completes and plan is saved |
| `/bsdd-ship` | After implement completes successfully |
| `/bsdd-optimize <title>` | Performance — standalone or post-implement |
| `/bsdd-sync-patterns` | After implementing a new relevant pattern |

---

## Agent Structure

| Type | Agent | Model | Responsibility |
|---|---|---|---|
| Orchestrator | `/bsdd-plan`, `/bsdd-implement`, `/bsdd-ship`, `/bsdd-optimize`, `/bsdd-prd` | Sonnet 4.6 (inline) | Coordinates flow, uses AskUserQuestion, never writes code |
| Domain | `feature-implementer` | Sonnet 4.6 | Writes production code |
| Domain | `test-implementer` | Sonnet 4.6 | Writes and runs tests |
| Domain | `reviewer` | Opus 4.8 | Audits diff vs plan |
| Optimizer | `optimizer` | Opus 4.8 | Measurement + optimization loop, evidence-based |
| Integration | `git-agent` | Haiku 4.5 | Branch, commit, PR |

**Isolation principle:** domain agents never call git directly — they delegate to `git-agent` via the orchestrator.

---

## Local Artifacts

| Path | Content |
|---|---|
| `.plans/YYYY-MM-DD-<title>.md` | Refined plan with frontmatter (`date`, `title`) |
| `.prds/YYYY-MM-DD-<title>.md` | PRD with frontmatter |
| `.plans/YYYY-MM-DD-<title>-optimization.md` | Optimization report |
| `.ship/YYYY-MM-DD-<title>/` | Review summary, ADRs, handoff doc |
| `.skills/patterns.md` | Canonical codebase snippets (updated via `/bsdd-sync-patterns`) |
| `docs/workflow.md` | This document (English) |
| `docs/workflow.pt-br.md` | This document (Português BR) |

`.plans/`, `.prds/`, and `.ship/` are gitignored by default. Recommended practice: remove them from `.gitignore` on feature branches and include them in the PR. They serve as live ADRs — the record of why code was written, what was deferred, and what risks were accepted.
