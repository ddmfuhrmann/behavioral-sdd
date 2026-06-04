# behavioral-sdd

Behavioral Spec-Driven Development: a workflow for Claude Code that enforces plan-first development, spec-driven implementation, and isolated subagent orchestration.

---

## What is behavioral-sdd

behavioral-sdd is a template workflow for Claude Code projects. It installs a set of slash commands, subagents, and skills that enforce a consistent development discipline:

- No code is written without a saved plan.
- Plans are challenged via a grill-me loop before implementation begins.
- Implementation, testing, review, and git operations are handled by isolated subagents.
- All artifacts (plans, optimization reports, handoffs) are stored locally in `.plans/`, `.prds/`, and `.ship/`.

The workflow is language- and framework-agnostic. A small set of skills (`code-style.md`, `error-handling.md`, `testing-strategy.md`) come with placeholder examples that you adapt to your stack.

---

## Motivation

LLM-driven development without structure tends to drift. A model given a vague request
will interpret, assume, and expand scope — often producing code that solves a slightly
different problem than the one stated. Across a multi-step feature (implement, test,
review, ship), context accumulated in one step leaks into the next, and small
misalignments compound.

behavioral-sdd treats this as an engineering problem, not a prompting problem.

**Spec-driven development** means every implementation starts from a written plan —
not a conversation, not a mental model, not an intent. The plan is a contract: it
defines scope, assumptions, files likely to change, tests needed, and acceptance
criteria before any code is written. The grill-me loop exists to challenge the plan
while it is still cheap to change it, not after code has been written.

**Harnesses** are structured commands that enforce workflow stages. A harness doesn't
ask the model to behave correctly — it makes incorrect behavior structurally
impossible. `/bsdd-implement` cannot run without a saved plan. `/bsdd-ship` runs the
reviewer before the PR. The orchestrator never writes code. These are not guidelines;
they are constraints baked into the command sequence.

**Specialized subagents** reduce the context contamination problem. When a single agent
implements, tests, reviews, and commits in one session, each step's output biases the
next. Splitting responsibilities across isolated agents (`feature-implementer`,
`test-implementer`, `reviewer`, `git-agent`) gives each a clean context window scoped
to its task. It also allows model tiering: expensive reasoning models (`Opus 4.8`) for
judgment-heavy tasks like review and optimization; cheaper models (`Haiku 4.5`) for
mechanical tasks like git operations.

The name reflects this design: *behavioral* because the workflow enforces behavior
through harnesses and agent boundaries, not through prompting conventions that the
model can silently ignore.

---

## Tradeoffs

**Cost.** Running multiple specialized subagents — particularly `reviewer` and
`optimizer` on Opus 4.8 — is more expensive than a single free-form conversation.
The pipeline trades token cost for discipline.

**Speed.** Each agent roundtrip adds latency. A full implement + test + ship cycle
takes longer than asking the model to "just do it." That friction is intentional on
large features; it is waste on small ones (see [When to use](#when-to-use)).

**Context handoff.** Isolated agents don't share conversational memory — they only
receive what the orchestrator explicitly passes. A vague plan produces a vague
implementation. The quality of the output is bounded by the quality of the plan.

**Setup.** The workflow requires upfront customization (`CLAUDE.md`, stack-specific
skills) before delivering value. It is not a zero-config tool.

---

## Core philosophy

- **No code without a saved plan.** Every implementation starts from a `.plans/` file.
- **Grill-me loop refines the plan before implementation.** One question at a time via `AskUserQuestion` — the model challenges its own plan before writing a line of code.
- **Subagents are isolated.** Domain agents (`feature-implementer`, `test-implementer`, `reviewer`) never call git directly. Integration agents (`git-agent`) are cheap and focused.
- **Integration agents run on Haiku 4.5.** They handle one thing (git operations) and cost almost nothing.
- **`caveman` + `karpathy-guidelines` always active.** Every agent loads these two skills: compressed output and disciplined coding behavior.

---

## When to use

| Task | Approach |
|---|---|
| Tiny fix, one-liners | Plan inline in conversation |
| Normal task | `/bsdd-plan` |
| Large feature | `/bsdd-prd` → `/bsdd-plan` |
| Performance issue | `/bsdd-optimize` |

**When not to use the full cycle:**

- Tiny fixes and one-liners
- Spike investigations and throwaway experiments
- Codebase exploration
- Anything where the cost of the wrong implementation is zero

The value is in the plan-first constraint — skip it only when that constraint adds no value.

---

## Workflow diagram

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

See `docs/workflow.md` for the full guide (with optimize and PRD flows).

---

## Commands quick reference

| Command | When to use |
|---|---|
| `/bsdd-prd` | Before plan, for larger-scope features — collects requirements via grill-me |
| `/bsdd-plan` | Always — entry point of the cycle |
| `/bsdd-implement <title>` | After grill-me completes and plan is saved |
| `/bsdd-ship` | After implement completes successfully |
| `/bsdd-optimize <title>` | Performance — standalone or triggered after implement |
| `/bsdd-sync-patterns` | After implementing a new pattern other agents should follow |

---

## Agent structure

| Tier | Agent | Model | Responsibility |
|---|---|---|---|
| Orchestrator | `/bsdd-plan`, `/bsdd-implement`, `/bsdd-ship`, `/bsdd-optimize`, `/bsdd-prd` | Sonnet 4.6 (inline) | Coordinates flow, uses AskUserQuestion, never writes code |
| Domain | `feature-implementer` | Sonnet 4.6 | Writes production code |
| Domain | `test-implementer` | Sonnet 4.6 | Writes and runs tests |
| Domain | `reviewer` | Opus 4.8 | Audits diff vs plan |
| Optimizer | `optimizer` | Opus 4.8 | Measurement + optimization loop, evidence-based |
| Integration | `git-agent` | Haiku 4.5 | Branch, commit, PR — only integration agent |

---

## Getting started

```bash
# Clone and copy into your project
git clone https://github.com/ddmfuhrmann/behavioral-sdd
cp -r behavioral-sdd/.claude your-project/
cp -r behavioral-sdd/.skills your-project/
cp -r behavioral-sdd/docs your-project/
cp behavioral-sdd/CLAUDE.md your-project/  # then customize it

# Customize
# 1. Edit CLAUDE.md with your project details
# 2. Adapt .skills/code-style.md, error-handling.md, testing-strategy.md to your stack
# 3. Run /bsdd-sync-patterns after your first implementation to generate patterns.md
```

---

## Example plan

A saved plan looks like this:

```
---
date: 2026-06-04
title: add-user-rate-limiting
---

## Understanding
Add per-user rate limiting to POST /api/messages.

## Assumptions
- Redis is already available in the stack.
- Limit is global per user, not per endpoint.

## Scope
- src/middleware/rateLimiter.ts — new middleware
- src/routes/messages.ts — apply middleware

## Out of scope
- Admin UI for configuring limits
- Per-endpoint granularity

## Approach
Create rateLimiter(limit, windowSeconds) in middleware layer.
Apply to POST /api/messages with limit=60, window=60.

## Files likely to change
- src/middleware/rateLimiter.ts (new)
- src/routes/messages.ts

## Tests needed
- Unit: middleware rejects when limit exceeded
- Integration: 429 response after N requests in window

## Risks
- Redis unavailable — fail open or closed?

## Performance criteria
- No measurable latency increase on non-rate-limited requests

## Blocking questions
- Fail open or closed when Redis is unavailable?
```

---

## What to customize

### Stack-specific (you must adapt these)

| File | What to change |
|---|---|
| `CLAUDE.md` | Project description, stack, architecture, domain constraints |
| `.skills/code-style.md` | Naming conventions, DTO patterns, formatting rules for your language |
| `.skills/error-handling.md` | Exception types, HTTP status codes, domain error strategy |
| `.skills/testing-strategy.md` | Test runner commands, container tooling, coverage conventions |

### Generic (copy as-is, no changes needed)

| File | Purpose |
|---|---|
| `.skills/caveman.md` | Ultra-compressed output mode |
| `.skills/karpathy-guidelines.md` | Coding discipline: think before coding, simplicity, surgical changes |
| `.skills/grill-me.md` | How to challenge a plan effectively |
| `.skills/diff-review.md` | Review process and severity labeling |
| `.skills/plan-first-development.md` | Plan workflow rules and checklist |
| `.skills/edge-case-generation.md` | Systematic edge case discovery |
| `.skills/benchmark-execution.md` | Load testing methodology |
| `.skills/database-seeding.md` | Realistic data seeding for perf tests |
| `.skills/postgres-explain-analyze.md` | Query analysis procedure |
| `.skills/optimization-reporting.md` | Optimization report format |
| All `.claude/commands/bsdd-*.md` | Workflow commands — no changes needed |
| All `.claude/agents/*.md` | Subagents — no changes needed |

### Optional integrations *(experimental)*

| File | Purpose | Activation |
|---|---|---|
| `.skills/sonar-analysis.md` | SonarQube static analysis in the review step | Add `sonar-project.properties` to the project root |

Requires Docker. Token is auto-generated on first use and stored in `.bsdd-sonar-token` (gitignored). See `docs/workflow.md` for details.

---

## Local artifacts

| Path | Content |
|---|---|
| `.plans/YYYY-MM-DD-<title>.md` | Refined plan with frontmatter (`date`, `title`) |
| `.prds/YYYY-MM-DD-<title>.md` | PRD with frontmatter |
| `.plans/YYYY-MM-DD-<title>-optimization.md` | Optimization report |
| `.ship/YYYY-MM-DD-<title>/` | Review summary, ADRs, handoff doc |
| `.skills/patterns.md` | Canonical codebase snippets — generated by `/bsdd-sync-patterns` |

`.plans/`, `.prds/`, and `.ship/` are in `.gitignore` by default — useful while iterating, but the recommendation is to **version them alongside the feature branch and include them in the PR**. These artifacts are live ADRs: they record why a line of code was written, which decisions were deferred, and what risks were accepted. That context is precisely what future developers (and future Claude sessions reading `git log`) need.

---

## Extensibility

The workflow is intentionally file-based. Plans, PRDs, ADRs, and handoff documents live in `.plans/`, `.prds/`, and `.ship/` as markdown files — no external dependencies, no accounts, no setup beyond cloning.

This is a deliberate tradeoff. The same artifacts could be managed through MCP servers: a Notion or Linear integration that persists PRDs and ADRs as structured records, queries the backlog to inform `/bsdd-plan`, or posts review findings directly to the issue tracker. The command and agent layer would stay the same; only the read/write surface of each artifact would change.

If your team already lives in one of those tools, replacing the file-based artifact layer with MCP calls is a natural extension point.

---

## Credits

- [`caveman`](https://github.com/mattpocock/skills/blob/main/skills/productivity/caveman/SKILL.md) — ultra-compressed output skill by Matt Pocock
- [`grill-me`](https://github.com/mattpocock/skills/blob/main/skills/productivity/grill-me/SKILL.md) — plan interrogation skill by Matt Pocock
- [`karpathy-guidelines`](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/skills/karpathy-guidelines/SKILL.md) — coding discipline skill inspired by Andrej Karpathy
