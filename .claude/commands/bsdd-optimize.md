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

**Without performance criteria:**
1. Spawn the `optimizer` in analysis mode (without applying changes).
2. The optimizer collects baseline, analyzes, produces findings and recommendations.
3. Save the analysis report locally in `.plans/YYYY-MM-DD-<title>-optimization.md`.
