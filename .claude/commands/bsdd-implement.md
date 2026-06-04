# /bsdd-implement

Orchestrates the complete implementation: code + tests, with automatic correction loop.

## Inputs

- Plan title as argument: `/bsdd-implement my-feature`
- Without argument: infer title from conversation context (most recently saved plan).

## Procedure

1. Locate the file `.plans/YYYY-MM-DD-<title>.md` and read it.
2. Spawn the `feature-implementer` with the full plan content.
3. Read the implementation summary produced by the `feature-implementer`:
   - If **Deviations** is non-empty, note the delta explicitly.
   - Spawn the `test-implementer` with the plan + implementation summary, highlighting any deviations so tests target the actual implementation, not the original plan.
4. If tests pass: go to step 8.
5. If tests fail, record the error signature (first error message + location). Then:
   - Spawn the `feature-implementer` again with the plan + test failure output to fix.
   - Spawn the `test-implementer` again.
6. **Circuit breaker:** if the new error signature matches the previous attempt's signature, abort immediately — do not consume the remaining tries. Go to step 7.
7. Checkpoint via `AskUserQuestion` (on 4th failure or circuit breaker trigger):
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
