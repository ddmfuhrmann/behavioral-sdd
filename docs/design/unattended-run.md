# Unattended run with asynchronous review

> Design study, deeper than a brainstorm note. Captures how `/goal` (brainstorm #2)
> and `/bsdd-run` (brainstorm #6) combine into one model: run the full bsdd loop
> without a human in the inner loop, record every autonomous decision, and move the
> human gate from *mid-flow* to *the PR*. See `docs/brainstorm.md` for the wider
> backlog this belongs to.

## TL;DR

- `/goal` does **not** decide anything and does **not** replace the per-command
  loops. It is a session-scoped Stop hook: it keeps the session taking turns and
  crisply decides **when to stop**.
- The decisions are made by a **`decide(auto)` policy** inside the orchestrators —
  the same gates that ask `AskUserQuestion` today, resolved by their existing
  `(Recommended)` default and **logged to a ledger** instead of stopping for a human.
- The human gate doesn't disappear — it **moves to the PR** as an asynchronous
  review of a stratified decision summary.
- **Blast radius is small:** the change lives in a thin "mode" layer inside the
  orchestrators plus one new command. Subagents, `git-agent`, and the manual
  command path are untouched.

## Why `/goal` lives one layer above the commands

The bsdd commands already "keep going until done" — but with **bounded loops inside
a single invocation**: `/bsdd-implement` retries (≤3× + circuit breaker), `/bsdd-optimize`
loops baseline→change→remeasure. Those loops run **inside isolated subagents**, so:

- Their internal work never reaches the **main session transcript** — only the
  subagent's final summary returns to the orchestrator.
- `/goal`'s evaluator reads **only the main transcript**. So `/goal` wrapped around a
  single command would be partly **blind** to the very evidence (test exit code, p95)
  it needs.

Conclusion: `/goal` is **not** a good fit *inside* `implement`/`optimize` (redundant
with their internal loops, blind to subagent state). Its real niche is the layer
**above** the commands — the termination oracle for a full-loop sequencer
(`/bsdd-run`). The two are complementary, not overlapping.

## The three layers

```
/goal           ENVELOPE   — keeps the session alive; decides when to STOP.
  └ /bsdd-run   SEQUENCE   — runs plan → implement → optimize? → ship, one pass.
      └ decide(auto)  POLICY — resolves each gate, classifies it, logs to the ledger.
```

- **`decide(auto)` is the decision-maker** (and the thing that writes the ledger).
- **`/goal` is liveness + termination** — it is what makes the loop *come back* when
  ship finds a BLOCKER, by granting another turn so the session can re-implement.
- You can build and ship `/bsdd-run` **without** `/goal` (one forward pass); `/goal`
  is the robustness layer that turns "one pass" into "iterate until shipped."

## Gate classification — not every gate has a safe default

The escape condition is **not** a flat "always take the recommended option." Gates
fall into classes, and the class decides how `decide(auto)` treats it:

| Class | Examples | `decide(auto)` behavior | Summary color |
|---|---|---|---|
| **● Policy** | ship findings by severity (BLOCKER/WARNING/SUGGESTION), implement "try 3 more" checkpoint, optimize retry checkpoint, "run optimize?", ADR registration | apply the existing rule, log, **collapse** in summary | none (FYI) |
| **◐ Intent — soft** | scope granularity, naming, defaults (UTC, page size) chosen during `/bsdd-plan` grill-me | guess the recommended value, log as a reversible bet | **yellow** |
| **◯ Intent — hard** | the plan's own `Blocking questions` section — things the model flagged as *"cannot proceed without knowing"* | still auto-answered (loop never stalls), but **downgrades the `/goal` done-condition to "needs review"** | **red** |

The distinction that matters: **does the gate apply a policy (has a correct default)
or resolve an intent (needs the human's head)?** Auto-resolving a policy gate just
executes a rule that was already written. Auto-resolving an intent gate means the
model *guessed your scope* — which is the exact drift bsdd exists to prevent. The
mitigation is not to stop the loop, but to **record the guess as a reversible bet**
and let the color (yellow/red) drive the reviewer's attention.

> **Hard-blocker asymmetry (the one safeguard kept even in `--auto-full`):** a
> non-empty `Blocking questions` section is qualitatively different from guessing a
> default. Auto-answering it never halts the loop, but it paints the entry **red** and
> flips the `/goal` terminal state from "done with notes" to "needs review", pushing it
> to the absolute top of the PR summary. Without this, `--auto-full` would erase the
> one signal the framework had for "this I deliberately did not guess."

## The ledger

- **One file per plan:** `.ship/<title>/decisions.md`, keyed by the same kebab-title
  as the plan and the existing `.ship/<title>/` directory.
- **Append-only, written by every phase:** plan writes scope/blocker entries,
  implement writes retries, ship writes findings/ADR/handoff.
- **Serves three readers:** you (in the PR), `/goal`'s evaluator (resolves the
  transcript-blindness problem when the orchestrator echoes status into the main
  transcript), and history (a real ADR of what was decided autonomously and why).

## Asynchronous review — the PR is the human gate

The human gate is not removed; it is moved from *mid-flow* to *the PR*, where you
review on your own time. The summary must be **stratified** — a flat list of ten
decisions gets ignored by the third line.

```markdown
## Autonomous decisions

Branch produced by an unattended bsdd run. Review the first group.

### ⚠️ Judgment calls — review (3)
◯ 1. [RED] blocking question auto-answered: assumed single-tenant — verify.
◐ 2. [yellow] scope: assumed CSV export is out (plan only said "export").
       → if wrong: edit .plans/<title>.md §Scope and re-run.
◐ 3. [yellow] timestamps in UTC (plan didn't specify tz) — see src/report.py:88.

<details><summary>Applied by policy (●) — no action needed</summary>

- Findings: 2 WARNING deferred, 1 SUGGESTION → issue (severity rule)
- Implement: 3 retries after test failure, then passed
- ADR: 1 candidate registered
</details>
```

Each judgment call is phrased as a **reversible bet** (`→ if wrong: do X`) so review
is *actionable*, not just readable — the reviewer scans a few bets and decides what
to revert, instead of re-reading the whole diff.

## Trust boundary — where does the unattended run begin?

Two modes, controlled by a flag on `/bsdd-run`:

| Mode | Where auto begins | Use when |
|---|---|---|
| `--auto` | **after** the plan is approved by a human; plan grill-me stays synchronous | scope is non-trivial — protects the most expensive error |
| **`--auto-full` (default)** | from the start; even the plan grill-me is auto-resolved, scope guessed and logged as judgment call #1 | the ticket is crisp, or you accept reviewing scope at the PR |

The chosen default is **`--auto-full`**: maximum unattendedness, with the hard-blocker
red-flag safeguard above as the backstop. In `--auto-full` the ledger's plan-layer
entries are **never empty** — they point at the saved plan's `Scope`, `Assumptions`,
and `Blocking questions` sections, which *are* the judgment calls of the planning phase.

## Full flow

```
LEGEND   ● policy (auto+collapse)   ◐ intent-soft (auto+yellow)   ◯ hard-blocker (auto+red, downgrades done)

┌───────────────────────────────────────────────────────────────────────────────┐
│ /goal "plan implemented, tests green, ship has no BLOCKER, ledger has no open   │
│        red item — or stop after N turns"     ENVELOPE: only STOP / CONTINUE     │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │ /bsdd-run --auto-full      SEQUENCE: one forward pass                    │  │
│  │                                                                         │  │
│  │  ┌────────┐  Plan agent explores → 10-section plan                      │  │
│  │  │  PLAN  │  grill-me auto-resolved: Scope/Assumptions ◐ · Blocking ◯   │  │
│  │  │        │  saves .plans/<title>.md ──┐ append                         │  │
│  │  └───┬────┘                            ▼                                │  │
│  │  ┌───▼─────┐  feature-implementer    ╔═══════════════╗                  │  │
│  │  │IMPLEMENT│  test-implementer       ║    LEDGER     ║                  │  │
│  │  │         │  correction loop ≤3×    ║ .ship/<title> ║                  │  │
│  │  │         │  4th fail → ● try 3 ───►║ /decisions.md ║                  │  │
│  │  └───┬─────┘                         ║ (append by    ║                  │  │
│  │  ┌───▼─────┐  "run optimize?" ● ────►║  every phase) ║                  │  │
│  │  │OPTIMIZE?│  (only if perf criteria)║               ║                  │  │
│  │  │         │  optimizer loop;        ║               ║                  │  │
│  │  │         │  miss → ● try 3 ───────►║               ║                  │  │
│  │  └───┬─────┘                         ║               ║                  │  │
│  │  ┌───▼─────┐  git-agent: diff        ║               ║                  │  │
│  │  │  SHIP   │  reviewer (+plugins)    ║               ║                  │  │
│  │  │         │  BLOCKER → ● fix now ───╫──┐ loop back  ║                  │  │
│  │  │         │  WARNING → ● defer ────►║  │            ║                  │  │
│  │  │         │  SUGGEST → ● issue ────►║  │            ║                  │  │
│  │  │         │  ADR ● · handoff ◐/◯ ──►║  │            ║                  │  │
│  │  └───┬─────┘                         ╚══╤════════════╝                  │  │
│  │      │  PR created only when done-cond holds (no open BLOCKER);         │  │
│  │      │  git-agent: PR, body = stratified ledger summary ◄──┘ reads      │  │
│  └──────┼──────────────────────────────────────────────────────────────────┘  │
│         ▼                                                                       │
│   /goal: condition holds?                                                       │
│     ├─ BLOCKER open / not done → CONTINUE ──► (loop back to fix)                 │
│     └─ shipped clean (mod ledger) → STOP                                         │
└─────────┬───────────────────────────────────────────────────────────────────────┘
          ▼  PR open
   ═══════════════ OUTSIDE THE ENVELOPE — OFF-SESSION ═══════════════
              ASYNCHRONOUS HUMAN REVIEW (you, on your own time)
        review the reversible bets in the PR body → approve / comment / revert
```

## Blast radius — what changes, what doesn't

The bsdd isolation rule ("orchestrators decide, subagents do domain work, never call
git directly") put all decision logic in the orchestrators. That is exactly what keeps
this change small.

| Component | Change | Detail |
|---|---|---|
| Commands `bsdd-plan/implement/optimize/ship` | ✏️ **yes** | wrap each gate in `decide(question, options, mode)`: `GUIDED`→`AskUserQuestion`, `AUTO`→recommended + classify (●/◐/◯) + append ledger |
| `/bsdd-run` | ➕ **new** | new command that sequences the phases and carries the policy. New file, not a refactor |
| `/goal` | — | harness built-in; **no file in the repo** |
| `/bsdd-ship` PR step | ✏️ **yes (auto only)** | (1) PR creation gated on done-condition instead of unconditional-at-end, so loop-back doesn't create a premature PR; (2) body includes the stratified ledger summary |
| `git-agent` | ⚪ **no** | still receives a PR body and creates the PR — same contract, richer body |
| `feature/test-implementer`, `reviewer`, `optimizer` | ⚪ **no** | same domain work, same output. Their existing output contracts already emit what `decide(auto)` consumes — `Results: X passed/Y failed`, severity labels `BLOCKER\|WARNING\|SUGGESTION`, optimizer criteria met/unmet |

The only adjacent-to-subagent need is **echoing status to the main transcript** so
`/goal`'s evaluator can see "tests green" / "review PASS". That is **orchestrator**
behavior, not a subagent change, and it is needed **only in v2** (with `/goal`).

## The guided-default invariant (backward compatibility)

This must be an **explicit design invariant**, not an accident: the commands keep
identical behavior when invoked standalone.

```
decide(question, options, mode = GUIDED)        ← default
  GUIDED → AskUserQuestion        (today's exact behavior)
  AUTO   → recommended + log       (only when something turns it on)
```

`AUTO` is turned on **only** by `/bsdd-run` (which signals the mode to the phases it
sequences) or an explicit flag. The auto machinery is **dormant** otherwise.

| You run | Mode | Behavior |
|---|---|---|
| `/bsdd-ship` by hand | GUIDED (default) | `AskUserQuestion` as today · PR at end as today · trivial/empty ledger |
| `/bsdd-implement` by hand | GUIDED | 4th-failure checkpoint as today |
| `/bsdd-run --auto-full` | AUTO | the whole machine above |

Nothing about the manual path changes. `decide(guided)` is literally a wrapper around
today's `AskUserQuestion`.

## Incremental path

- **v1 — `/bsdd-run --auto-full` alone:** sequence + `decide(auto)` + ledger +
  stratified PR. One forward pass; stops wherever it ends. Does **not** need the
  transcript-echo. Lowest risk; ships value immediately.
- **v2 — wrap with `/goal`:** gains the BLOCKER loop-back, survival across turn
  boundaries, and a machine-checked stop condition. Add the transcript-echo here.

Build and trust v1 first; add `/goal` once the sequence is reliable.

## Caveats

- **The evaluator reads only the transcript.** It runs no tools and opens no files.
  Write `/goal` conditions that the session's own output demonstrates ("`npm test`
  exits 0", "review PASS"), and make the orchestrator echo that evidence to the main
  transcript (v2).
- **`/goal` does not replace entry gates.** "No code before a saved plan" still needs
  a `PreToolUse` hook (brainstorm #1). `/goal` governs *when to stop*; the hook governs
  *what may start*. They cover opposite ends.
- **Pairs with permission-noise mitigation (brainstorm #7).** Unattended turns stall on
  "can I run this?" without an allowlist / auto-accept-edits during implement.
- **Philosophy:** auto is **opt-in, never default at the command level.** Over-automating
  the deliberate gates erodes bsdd's core value; the ledger + async review is what keeps
  the human decision in the loop, just asynchronously.
