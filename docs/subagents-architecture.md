# Subagents Architecture

How behavioral-sdd splits work across isolated Claude Code subagents, and the
design rules that keep each one in its lane.

> The Portuguese mirror of this document is [`subagents-architecture.pt-br.md`](subagents-architecture.pt-br.md).

---

## Model: orchestrator + specialists

The `bsdd-*` slash commands (`.claude/commands/`) are **orchestrators**. They run
in the main session, hold the conversation, and `Spawn` specialist **subagents**
(`.claude/agents/`) for the work that benefits from an isolated context and a
restricted toolset.

```
/bsdd-implement ──▶ feature-implementer ──▶ test-implementer
                         │ (correction loop on test failure)
/bsdd-ship ─────▶ reviewer ──▶ (fix via feature-implementer) ──▶ git-agent
/bsdd-optimize ─▶ optimizer
git ops ────────▶ git-agent  (branches, commits, diffs, PRs)
```

Planning (`/bsdd-prd`, `/bsdd-plan`) deliberately runs in the **main thread**, not
a subagent — planning needs the full conversation context, which isolation would
strip away. See [Known gaps](#known-gaps).

> **Constraint — subagents cannot invoke slash commands.** A subagent runs in an
> isolated context with a fixed toolset; it has no way to trigger `/bsdd-ship` or any
> other command, no matter what its prompt says. Slash commands are a main-session
> construct. This is why the `feature-implementer` cannot "call ship" — it is
> structural, not a bug. **Phase chaining must live in a main-thread orchestrator**
> (the proposed `/bsdd-run`, see [`brainstorm.md`](brainstorm.md) #6), never inside a
> subagent.

---

## The roster

| Subagent | Model | Tools | Role | Spawned by |
|---|---|---|---|---|
| `feature-implementer` | Sonnet 4.6 | Read, Write, Edit, Bash | Writes production code exactly as the plan describes | `/bsdd-implement`, `/bsdd-ship` (fixes) |
| `test-implementer` | Sonnet 4.6 | Read, Write, Edit, Bash | Writes and runs tests that verify the plan | `/bsdd-implement` |
| `reviewer` | Opus 4.8 | Read, Bash | Audits the diff against the plan; quality gate | `/bsdd-ship` |
| `optimizer` | Opus 4.8 | Read, Write, Edit, Bash | Evidence-based performance work (measure → change → measure) | `/bsdd-optimize` |
| `git-agent` | Haiku 4.5 | Bash | Git operations: branches, commits, diffs, PRs | orchestrators only |
| `handoff-keeper` | Sonnet 4.6 | Read, Write, Edit | Rewrites `.handoff/YYYY-MM-DD-<title>.yml` at each phase transition; narrow state manager, not a domain agent | `/bsdd-implement`, `/bsdd-ship`, `/bsdd-optimize`, `/bsdd-handoff` |

---

## Design principles

### 1. Single responsibility
Each subagent does one thing. The implementer does not write tests; the test
implementer does not patch production code; the reviewer does not rewrite code —
it flags findings and the orchestrator re-spawns the implementer to fix.

### 2. Tool scoping
Tools are granted by need, narrowest first. The `reviewer` has **no `Write`/`Edit`**
— it physically cannot mutate the tree, which is what makes it a trustworthy gate.
The `git-agent` has only `Bash`.

> **Caveat:** scoping is coarse. `Bash` cannot be narrowed to "git only", and
> `Write`/`Edit` cannot be narrowed to "test files only". So some invariants
> ("don't fix production code", "never force-push") are **prose-enforced**, not
> tool-enforced. Hardening these into `PreToolUse` hooks is noted in
> [`brainstorm.md`](brainstorm.md) (idea #1).

### 3. Model tiering (cost-aware)
Mechanical work runs cheap, judgment runs expensive:
- **Haiku** — `git-agent` (deterministic shell ops)
- **Sonnet** — `feature-implementer`, `test-implementer` (execution)
- **Opus** — `reviewer`, `optimizer` (judgment, trade-off reasoning)

### 4. Context isolation
Each subagent receives only what it needs — the plan, the handoff YAML (when
available), and phase-specific context (diff, test output). The reviewer receives
the handoff YAML in place of separate implementation and test summaries; the
feature-implementer in the correction loop receives the handoff alongside the
current test failure. Neither sees the other agent's chain of thought. This is the
core reason to use subagents instead of one long thread.

### 5. Contract-based handoff
Subagents do not share memory. They communicate through **structured Output blocks**
that the orchestrator relays:

- `feature-implementer` → **Implementation Summary** (files changed, plan coverage,
  deviations, flagged-for-optimizer, out-of-scope)
- `test-implementer` → **Test Summary** (test types, cases, results, gaps, bugs found)
- `reviewer` → **Review Summary** (plan coverage, verdict, severity-labeled findings)
- `optimizer` → **Optimization Report** (baseline, change, after, trade-offs, recommendation)

The plan itself is passed **inline in the spawn prompt** — there is no shared plan
file the subagents read. (The canonical saved plan lives at
`.plans/YYYY-MM-DD-<title>.md`, written by `/bsdd-plan`.)

In addition to these Output blocks, the compact handoff YAML
(`.handoff/YYYY-MM-DD-<title>.yml`) carries post-plan decisions (constraints,
accepted risks, deferred work) and phase state across agent boundaries and
sessions — replacing or supplementing the Output blocks as the primary context
passed to the reviewer and the correction loop.

---

## Orchestration flows

### Implement (with correction loop)
`/bsdd-implement` spawns `feature-implementer`, then `test-implementer`. On test
failure it records the error signature, re-spawns the implementer with the failure
output, and re-tests. A **circuit breaker** aborts if the new error signature
matches the previous attempt's — preventing a thrash loop. After repeated failures
it checkpoints via `AskUserQuestion` (retry / intervene / abandon).

### Ship (quality gate → handoff)
`/bsdd-ship` spawns `git-agent` for the diff, warns on large PRs (600–900 / >900
lines), spawns the `reviewer`, walks findings with `AskUserQuestion` (fix / defer /
open issue), runs an ADR check, collects handoff context, then spawns `git-agent`
to open the PR. Review/ADR/handoff artifacts are saved under `.ship/` and are
**gitignored** — never committed.

### Optimize
`/bsdd-optimize` spawns the `optimizer` only when there is a measurable concern. It
establishes a baseline before any change, applies one change at a time, and reports
trade-offs.

---

## git-agent safety invariants

The `git-agent` centralizes git so the safety rules live in one place:

- Never force-push.
- Never `--no-verify` (never skip hooks).
- Never commit to `main` directly.
- Never `git add -f` / `--force`; if git refuses an ignored file, report it instead
  of overriding.
- Never commit `.env` or credential files; check each file against `.gitignore`
  before staging.

These are currently **prose invariants** (the agent has full `Bash`). Promoting them
to enforced hooks is noted in [`brainstorm.md`](brainstorm.md) (idea #1).

---

## Known gaps

- **No planner/PRD subagent.** `/bsdd-prd` and `/bsdd-plan` run in the main thread.
  This is intentional (planning needs full context) but means plan quality depends
  on the orchestrator, not an isolated specialist.
- **Prose-only enforcement** of several safety rules — see principle #2.
- **Branch-creation ownership overlap.** `feature-implementer` creates its own
  feature branch (`git checkout -b`) even though `git-agent` also offers a
  `create-branch` operation. One owner should be chosen.
