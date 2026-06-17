# /bsdd-handoff

Updates the compact handoff file with decisions made in the orchestrator's dialogue.

## Inputs

- Plan title as argument: `/bsdd-handoff my-feature`
- Without argument: infer title from conversation context (most recently active plan).

## Procedure

1. Locate `.plans/YYYY-MM-DD-<title>.md`. Confirm it exists before proceeding.
2. Check for `.handoff/YYYY-MM-DD-<title>.yml`:
   - If it exists: pass its path to `handoff-keeper`.
   - If it does not exist: pass `"none"` as the handoff path.
3. Collect user direction: the message or decisions from the current dialogue that triggered this command. This is the source of update passed to `handoff-keeper`.
4. Spawn `handoff-keeper` with:
   - Plan path: `.plans/YYYY-MM-DD-<title>.md`
   - Handoff path: `.handoff/YYYY-MM-DD-<title>.yml` or `"none"`
   - User direction: the relevant decisions or context from the current dialogue
5. Confirm: `Handoff updated. .handoff/YYYY-MM-DD-<title>.yml reflects current stage.`
