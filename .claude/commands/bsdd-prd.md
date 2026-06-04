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
3. Suggest a short kebab-case title and confirm.
4. Save locally in `.prds/YYYY-MM-DD-<title>.md`.
5. Suggest: `PRD saved. Run /bsdd-plan to turn it into an implementation plan.`
