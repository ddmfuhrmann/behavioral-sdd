# Brainstorm — Claude Code features worth adopting in behavioral-sdd

> Working notes, not canonical docs. Captures Claude Code primitives that fit the
> bsdd workflow, ranked by value. Promote anything proven here into `workflow.md`.

## Priority at a glance

| # | Idea | Fits which gate / step | Effort | Status |
|---|---|---|---|---|
| 1 | **Hooks (`PreToolUse`)** — enforce gates programmatically | The 3 hard rules in `CLAUDE.md` | Medium | To prototype |
| 2 | **`/goal`** — keep working until criteria hold | `/bsdd-implement`, `/bsdd-optimize` | Low | To document |
| 3 | **Plugin + marketplace packaging** | Distribution of the whole framework | Medium | To explore |
| 4 | **MCP servers** | external integrations (issues, docs) | Varies | Backlog |
| 5 | **`/schedule` routines & `/loop`** | unattended ship / nightly review | Low | Backlog |
| 6 | **`/bsdd-run`** — full-loop orchestrator | runs plan→implement→ship without per-command invocation | Medium | To design |
| 7 | **Permission-noise mitigation** | removes "can I run this?" prompts, keeps decision gates | Low | To document |

---

## 1. Hooks — turn prose rules into real enforcement (highest value)

`CLAUDE.md` carries three hard rules that today are **prose the model may ignore**:

- No code before a saved plan exists (`.plans/`)
- No optimization without a measured baseline
- No scope expansion without an explicit note in the plan

A `PreToolUse` hook on `Edit`/`Write` can **block** a code edit when no plan exists
in `.plans/`. This moves governance from "instruction the model should follow" to
"gate the harness executes." It is the missing piece that makes bsdd drift-proof.

- **Configured in:** `settings.json` (the harness runs it, not Claude)
- **Candidate gates:**
  - `PreToolUse(Edit|Write)` → require a matching `.plans/*.md` before touching code
  - `PreToolUse` on optimize path → require a baseline artifact before perf changes
- **Caveat:** keep the check fast and deterministic; a script hook beats a prompt
  hook for hard gates.

## 2. `/goal` — work across turns until criteria hold

Requires Claude Code **v2.1.139+**. You set a completion condition; Claude keeps
taking turns (no re-prompting) until a small fast model (Haiku by default) confirms
the condition holds by reading the transcript. Under the hood it is a
**session-scoped, prompt-based Stop hook** — same hooks family as idea #1, but the
"keep going until done" end instead of the "block before doing" end.

- **Fits:** the doc's own example use case — *"implement a design doc until all
  acceptance criteria hold."* That is `/bsdd-implement` against a `.plans/` file.
- **Example condition:**
  ```text
  /goal all acceptance criteria in .plans/<feature>.md are satisfied,
  `npm test` exits 0, and no file outside the plan's scope was modified —
  or stop after 25 turns
  ```
- **Caveat 1 — evaluator reads only the transcript.** It does not run tools or open
  files. Write conditions that Claude's own output demonstrates ("`npm test` exits
  0"), not states nobody printed.
- **Caveat 2 — does not replace entry gates.** `/goal` decides when to *stop*; the
  "no code before a plan" rule still needs a `PreToolUse` hook (idea #1). They are
  complementary — together they cover both ends of governance.
- **Pairs with:** auto mode (approves tool calls within a turn) so each goal turn
  runs unattended.

## 3. Package behavioral-sdd as a Plugin + Marketplace

Claude Code has a real plugin system with marketplaces. Today `.bsdd-plugins.yml`
is an internal concept; the whole framework (skills `bsdd-*` + agents + hooks)
could become **one installable plugin** instead of copying `.skills/` by hand into
every repo. This is the natural distribution path for what's been built.

- **Outcome:** one-command install of the entire workflow into any project.
- **v0 stepping stone:** a plain install script (`install.sh` or `/bsdd-install`)
  that copies `.claude/agents/`, `.claude/commands/`, `.skills/`, a `CLAUDE.md`
  template, **and the curated permission preset** (see #7) into a target repo. Ships
  today, no infra; the cost is no versioning/updates.
- **Why the plugin is the real destination:** once enforcement **hooks** (#1) exist,
  only a plugin distributes them reliably — a copy-install can't carry hook config.
- **Open question:** how hooks ship with a plugin and how project trust interacts.

## 4. MCP servers

External integrations (issue trackers, design docs, Notion) as MCP tools that the
bsdd steps can read from — e.g. `/bsdd-prd` pulling from a real backlog.

- **Status:** backlog; pick a concrete integration before investing.

## 5. `/schedule` routines & `/loop`

Niche fit, but: a scheduled routine running `/bsdd-ship` or a nightly review across
open PRs automates the ship/optimize tail without you present. `/loop` re-runs on a
time interval; `/schedule` runs independent of any open session.

## 6. `/bsdd-run` — full-loop orchestrator (no per-command invocation)

A top-level command in the **main session** that sequences the phases
(plan → implement → ship → optionally optimize) by invoking each skill in order.
Auto-chaining must live **here**, above the commands — a running phase cannot trigger
the next one from inside itself; that is a structural property of Claude Code, not a
bug. `/bsdd-run` is the orchestration layer that today is driven by hand.

- **Modes:** `--guided` (default — stops at every decision gate) vs `--auto` (flows
  between phases unattended).
- **Sacred gates stay regardless of mode:** plan approval before code, the grill-me
  handoff, and per-finding decisions are *deliberate* and remain. `--auto` only
  removes the *between-phase* friction, not the decision prompts.
- **Pairs with:** `/goal` (#2) for "run until shipped", and #7 to remove permission
  noise so unattended turns don't stall on "can I run this?".

## 7. Permission-noise mitigation (decisions ask, permissions don't)

The friction is not the decision prompts — it's the **permission prompts** ("can I
run this?"). Separate the two and treat them differently:

- **Decisions** (grill-me, findings, plan approval) → keep asking. This is the value.
- **Permissions** (run bash, accept edit) → mitigate.

Levers, lightest first:

- **Curated bsdd allowlist preset** in `.claude/settings.json` — the exact bash the
  workflow runs (`git diff`, build, test) plus `Edit`/`Write` loosened **in the
  implement phase only**, with `/bsdd-ship`'s review as the downstream gate.
- **Auto-accept edits** mode during implement.
- **Reuse existing tools, don't build a new command:** `/fewer-permission-prompts`
  (transcript-driven allowlist) and `update-config` (natural-language permission
  edits). A custom allowlist command would duplicate these — the **preset** is the
  real artifact, not the command.
- **Delivery:** the install script / plugin (#3) emits the preset; a permissions
  addendum doc (referenced from the README) documents it as opt-in.

---

## Open questions / next steps

- [ ] Prototype the `PreToolUse` plan-gate hook and measure false positives.
- [ ] Draft a `workflow.md` section: combining `/goal` with `implement`/`ship`/`optimize` + recommended condition formats.
- [ ] Spike: minimal plugin manifest that bundles skills + agents + hooks.
- [ ] Lock the list of **sacred gates** for `/bsdd-run --auto` (proposed: plan approval, grill-me handoff, per-finding decisions).
- [ ] Write the curated permission preset + permissions addendum doc (referenced from README).
