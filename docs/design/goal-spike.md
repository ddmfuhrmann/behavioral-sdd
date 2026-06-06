# The `/goal` spike — `/bsdd-fix` + recipe generator

> Design study. The **smallest buildable step** that puts `/goal` to work in the bsdd
> workflow, before the full unattended-run model. Parent / wider design:
> [`unattended-run.md`](unattended-run.md).

## Goal of the spike

Validate `/goal` on the smallest real loop — **review → fix → review until clean** —
before building `/bsdd-run`. This makes `/goal` **load-bearing** (it *owns* the loop),
exercises the transcript-echo and the turn-cap on a tiny surface, and dogfoods on real
changes. Two commands, **none** of the autonomous-flow machinery (no ledger, no
`decide(auto)`, no `/bsdd-run`).

## `/bsdd-fix <level>` — single-shot fix primitive

`level ∈ { blockers (default) | warnings | suggestions }`. One pass, **no internal loop**:

1. spawn the existing `reviewer` on `git diff main` (no questions).
2. **echo the verdict to the main transcript:** `Review: <N> findings ≥ <level>: [...]`
   — so `/goal`'s evaluator can read it.
3. if findings ≥ level exist: spawn `feature-implementer` targeted at those findings.
4. spawn `test-implementer` so a fix doesn't silently break the build.
5. stop; report the post-fix state.

"Single-shot" = **one review + one fix per call**. The repetition (review→fix→review)
is entirely `/goal`'s job. No `AskUserQuestion` anywhere — unattended-capable by
construction. Reuses the existing subagents as-is; their output contracts already feed
it (severity labels, pass/fail).

**Auto-accept by level:** running `/bsdd-fix <level>` pre-authorizes **all** edits for
findings ≥ level — you opted into the level, so you opted into its edits. Needs a
permission setting scoped by level (ties to [`brainstorm.md`](../brainstorm.md) #7).

## `/bsdd-goal <level>` — recipe generator

`/goal` **cannot be aliased**: a custom command is a prompt, and `/goal` is a harness
Stop hook armed from the user's input line — emitting `/goal` from inside a command's
body does not arm it. So this command does **not** start `/goal`; it **emits the
paste-ready recipe**:

```
/goal "run /bsdd-fix <level> each turn; done when the latest review verdict shows
       0 findings ≥ <level> — or stop after 6 turns"
```

It auto-fills the level, turn cap, and the exact condition phrasing. Its value beyond
convenience: it **guarantees a well-formed, transcript-checkable condition**. The one
failure mode of `/goal` is a condition the evaluator can't verify against the
transcript; the generator encodes the correct format so a blind condition can't be
written by accident. You paste the output; `/goal` then drives `/bsdd-fix` until the
verdict is clean or the cap hits.

## How a run looks

```
1. /bsdd-goal blockers           → prints the /goal recipe
2. paste the recipe              → /goal arms the Stop hook
3. /goal drives the loop:
     turn 1: /bsdd-fix blockers  → Review: 2 blockers → fix → test → stop
     turn 2: /bsdd-fix blockers  → Review: 1 blocker  → fix → test → stop
     turn 3: /bsdd-fix blockers  → Review: 0 blockers → /goal STOPS
   (or stops at turn 6 if a blocker is stubborn — the turn cap is the backstop)
```

## Defaults & boundaries

- `level` default **blockers** · turn cap **6** · diff `git diff main` · title from
  argument or context.
- the review runs **inside** each `/bsdd-fix` pass, so every turn produces a verdict
  for `/goal` to check.
- **out of scope:** `/bsdd-clean` (the bounded-internal-loop variant) and any command
  that arms `/goal` for you.
- this spike **precedes** the `/bsdd-run` v1/v2 path in
  [`unattended-run.md`](unattended-run.md) — prove the `/goal` mechanic here first.

## What the spike validates

- **Loop-back** — does `/goal` actually grant turns and re-run `/bsdd-fix`?
- **Evaluator / transcript-blindness** — can the small fast model read the echoed
  verdict and judge "0 findings" correctly?
- **Turn cap** — does it terminate on a stubborn finding instead of spinning?
- **The fix primitive** — does the surgical, findings-driven fix actually work?

All of this without touching `decide(auto)`, the ledger, or the PR summary — the exact
subset needed to trust `/goal` before building the rest.
