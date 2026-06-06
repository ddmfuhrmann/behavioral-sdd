# Compact handoff as workflow state

> Design note. Captures a small extension to the bsdd loop: keep the plan as the
> contract, and add a compact handoff file as the orchestration cursor between
> agents and sessions.

## Thesis

The saved plan is already the main context compression artifact. It turns the
conversation, exploration, scope decisions, and acceptance criteria into a stable
contract that every agent can follow.

Adding another broad "context pack" would mostly duplicate the plan. The better
addition is narrower: a compact handoff that records only the current workflow state
and manual decisions that affect future agents.

## What the handoff is

The handoff is not a log and not a transcript summary. It is a small, overwritten
state file that answers:

- what stage the work is in
- which files changed
- whether implementation and tests are complete
- what constraints or accepted risks were added after the plan
- what the next agent needs to know

The plan remains the source of truth for scope. The handoff is the cursor that lets
the orchestrator resume or route work without relying on the main conversation
window.

## What the handoff is not

- no full diffs
- no full test logs
- no chain-of-thought
- no append-only attempt history
- no generic conversation recap

During retry loops, detailed failure context can stay transient. When a phase
settles, the handoff should be rewritten to the final compact state. If the workflow
blocks, save only the current failure signature and the next needed action.

## Possible file shape

Prefer structured data over free-form Markdown so orchestrators can read it
mechanically.

```yaml
title: my-feature
plan_file: .plans/2026-06-06-my-feature.md
stage: tested

changed_files:
  - src/foo.ts
  - tests/foo.test.ts

implementation:
  status: complete
  deviations: none

tests:
  status: pass
  command: npm test -- foo
  failures: []
  gaps: []

constraints:
  - Do not change the admin flow in this slice.

accepted_risks:
  - Existing flaky report test is not blocking this PR.

deferred:
  - CSV export edge case moved to a later slice.

notes_for_next_agent:
  - Reviewer should verify the public API stayed compatible.

ready_for_ship: true
blockers: []
```

## Manual comments

Manual comments should update the handoff only when they change future execution:
scope, constraints, accepted risk, deferred work, next action, or review focus.

Examples that belong in the handoff:

- "Do not touch the admin flow."
- "This warning is accepted for this PR."
- "Move that edge case to the next slice."
- "Use real integration tests, not mocks."

Examples that should not be recorded:

- acknowledgements
- exploratory questions with no lasting decision
- preferences already captured in `CLAUDE.md` or skills

## Command and agent sketch

A small command can promote relevant manual context into the handoff:

```text
/bsdd-handoff <title>
```

It would invoke a focused subagent:

```text
handoff-keeper
```

The `handoff-keeper` reads the plan, current handoff, and the latest user direction.
It rewrites the handoff as the current compact state. It does not implement, review,
or plan.

Suggested tool scope:

```yaml
tools:
  - Read
  - Write
  - Edit
```

The key invariant: do not append indefinitely. Preserve only decisions and state that
still matter to the next agent.

## Orchestration value

With a compact handoff, orchestrators can route work from durable state instead of
conversation memory:

- `implemented` but not `tested` -> spawn `test-implementer`
- `tests.status: fail` -> spawn `feature-implementer` with the compact failure
- `ready_for_ship: true` -> `/bsdd-ship` reads plan + handoff + diff
- interrupted session -> resume from the last stable phase
- compacted main context -> no need to reconstruct previous summaries

This keeps the main context window small while avoiding a second broad context
artifact. The loop has one contract (`.plans/...md`) and one compact cursor
(`...-handoff.yml`).

## Open choice

The handoff could live beside the plan:

```text
.plans/YYYY-MM-DD-title.md
.plans/YYYY-MM-DD-title-handoff.yml
```

Or in a dedicated directory:

```text
.handoff/YYYY-MM-DD-title.yml
```

Keeping it beside the plan makes discovery simple. A dedicated directory keeps plan
contracts visually separate from mutable workflow state.
