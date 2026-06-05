# /bsdd-prd

Creates a PRD via conversational grill-me. Use before `/bsdd-plan` for larger-scope features.

## Procedure

1. Use `AskUserQuestion` to collect, one question at a time:
   - "What is the feature name?"
   - "What problem does it solve? Who is affected?"
   - "What is the measurable objective?"
   - "What are the main functional requirements?"
   - "What is explicitly out of scope?"
   - "What are the acceptance criteria?"
   - "Are there open questions or blockers?"
2. Draft the PRD and present it for review before saving.
3. Estimate the feature size from the collected requirements and the drafted PRD.
   - If estimated > 500 lines: use `AskUserQuestion` to ask whether the user wants to decompose into slices. If yes, collect slices one at a time — for each slice ask: kebab-case title, description, estimated lines, dependencies (other slice titles or "none"). Continue until the user confirms the list is complete. Add a `## Slices` table to the PRD draft with columns: `Slice | Description | Est. lines | Dependencies`.
   - If the user declines to decompose: add the following note to the PRD draft before saving: `> Note: slice decomposition was suggested (feature estimated at ~X lines) and not applied.`
   - If estimated ≤ 500 lines: skip this step silently.
4. Suggest a short kebab-case title and confirm.
5. Save locally in `.prds/YYYY-MM-DD-<title>.md`.
6. Suggest: `PRD saved. Run /bsdd-plan to turn it into an implementation plan.`
