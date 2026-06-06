# /bsdd-implement

Orchestrates the complete implementation: code + tests, with automatic correction loop.

## Inputs

- Plan title as argument: `/bsdd-implement my-feature`
- Without argument: infer title from conversation context (most recently saved plan).

## Procedure

1. Locate the file `.plans/YYYY-MM-DD-<title>.md` and read it.
1b. Check for `.handoff/YYYY-MM-DD-<title>.yml`. If it exists, read it and route:
   - `stage: tested`     → skip to step 8 (implementation and tests already complete)
   - `stage: blocked`    → skip to step 7 (resume correction loop; use handoff `blockers` as the last failure signature)
   - `stage: implemented` → skip steps 2 and 2b; go directly to step 3 using the handoff as implementation context in place of the implementation summary
   - `stage: shipped | reviewed | optimized` → inform the user the feature is already delivered and ask if they want to re-implement from scratch
   - no handoff file     → continue normally from step 2
2. Spawn the `feature-implementer` with the full plan content.
   - 2b. After `feature-implementer` completes successfully: ensure `.handoff/` directory exists (`mkdir -p .handoff` if needed). Then spawn `handoff-keeper` with:
     - Plan path: `.plans/YYYY-MM-DD-<title>.md`
     - Handoff path: `.handoff/YYYY-MM-DD-<title>.yml` if it exists, otherwise `"none"`
     - Phase summary: `stage=implemented`, `changed_files` and `implementation` fields extracted from the Implementation Summary already returned by the feature-implementer above (available in memory before proceeding to step 3)
3. Read the implementation summary produced by the `feature-implementer`:
   - **If routed from step 1b (`stage: implemented`):** no fresh Implementation Summary exists — use the handoff YAML (`changed_files`, `implementation.deviations`) as the implementation context for the test-implementer in place of the summary.
   - If **Deviations** is non-empty (from the summary or handoff), note the delta explicitly.
   - Spawn the `test-implementer` with the plan + implementation summary (or handoff content if routed from 1b), highlighting any deviations so tests target the actual implementation, not the original plan.
4. If tests pass: spawn `handoff-keeper` with:
   - Plan path: `.plans/YYYY-MM-DD-<title>.md`
   - Handoff path: `.handoff/YYYY-MM-DD-<title>.yml`
   - Phase summary: `stage=tested`, full `tests` block (`status=pass`, test command used, `failures=[]`, gaps from test summary)
   - Then go to step 8.
5. If tests fail, record the error signature (first error message + location). Then:
   - Spawn the `feature-implementer` again with: plan content + handoff YAML (provides `changed_files`, `constraints`, `accepted_risks`, `deferred` — compact context from previous phases) + current test failure output (specific error and location).
   - Spawn the `test-implementer` again.
6. **Circuit breaker:** if the new error signature matches the previous attempt's signature, abort immediately — do not consume the remaining tries. Go to step 7.
7. Checkpoint via `AskUserQuestion` (on 4th failure or circuit breaker trigger):
   - Before asking: spawn `handoff-keeper` with: plan path, `.handoff/YYYY-MM-DD-<title>.yml` (or `"none"`), `stage=blocked`, `blockers` = current failure signature, `tests.status=fail`. The keeper preserves all other fields.
   - "Try 3 more times" (Recommended)
   - "I want to intervene now"
   - "Abandon and see current state"
   - If "Try 3 more times": reset counter and return to step 5.
   - If "I want to intervene now": stop and present current state (last failure output).
   - If "Abandon": present current state and end.
8. On success: use `AskUserQuestion` to ask:
   - "Run /bsdd-optimize now?" (Recommended: no, go straight to /bsdd-ship)
   - "Yes, run /bsdd-optimize"
   - "No, go to /bsdd-ship"
9. Suggest: `Implementation complete. Run /bsdd-ship to review and hand off.`
