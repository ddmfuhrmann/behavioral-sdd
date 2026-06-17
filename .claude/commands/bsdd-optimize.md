# /bsdd-optimize

Autonomous performance optimization, always based on a plan. Uses the plan to determine whether to optimize or only analyze.

## Inputs

- Plan title as argument: `/bsdd-optimize my-feature`
- Without argument: infer from conversation context.

## Procedure

1. Locate and read `.plans/YYYY-MM-DD-<title>.md`.
2. Check whether the plan contains measurable **Performance criteria**.

**With performance criteria:**
1. Spawn the `optimizer` in optimization mode with the full plan.
2. The optimizer runs autonomously: baseline → analysis → change → re-measurement → loop.
3. Checkpoint after 3 attempts without reaching the criteria: `AskUserQuestion`:
   - "Try 3 more times" (Recommended)
   - "I want to intervene now"
   - "Accept current result"
4. Save the optimization report locally in `.plans/YYYY-MM-DD-<title>-optimization.md`.
5. Ensure `.handoff/` directory exists (`mkdir -p .handoff` if needed). Then spawn `handoff-keeper` with:
   - Plan path: `.plans/YYYY-MM-DD-<title>.md`
   - Handoff path: `.handoff/YYYY-MM-DD-<title>.yml` if it exists, otherwise `"none"`
   - Phase summary: `stage=optimized`, optimization report path (`.plans/YYYY-MM-DD-<title>-optimization.md`) in `notes_for_next_agent`

**Without performance criteria:**
1. Spawn the `optimizer` in analysis mode (without applying changes).
2. The optimizer collects baseline, analyzes, produces findings and recommendations.
3. Save the analysis report locally in `.plans/YYYY-MM-DD-<title>-optimization.md`.
4. Ensure `.handoff/` directory exists (`mkdir -p .handoff` if needed). Then spawn `handoff-keeper` with:
   - Plan path: `.plans/YYYY-MM-DD-<title>.md`
   - Handoff path: `.handoff/YYYY-MM-DD-<title>.yml` if it exists, otherwise `"none"`
   - Phase summary: `stage=optimized`, optimization report path (`.plans/YYYY-MM-DD-<title>-optimization.md`) in `notes_for_next_agent`
