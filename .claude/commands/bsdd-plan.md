# /bsdd-plan

Entry point of the development cycle. Transforms any input (conversation, ticket, PRD, vague idea) into a refined plan via the grill-me loop.

## Procedure

1. Use the native Plan agent (subagent_type: Plan) to explore the codebase and understand the impact of the task.
2. Produce a structured plan with the following sections:
   - **Understanding** — what the task asks for, in your own words
   - **Assumptions** — what is being treated as true without being explicitly stated
   - **Scope** — what will change (files, layers, behaviors)
   - **Out of scope** — what will explicitly not be done
   - **Approach** — how to implement it (concrete: "add method X to class Y that does Z")
   - **Files likely to change** — list of files or directories
   - **Tests needed** — test cases and type (unit/integration/contract/e2e)
   - **Risks** — what could go wrong
   - **Performance criteria** — measurable criteria if any, or "none" if not applicable
   - **Blocking questions** — questions that must be answered before implementing
3. Start the grill-me loop automatically:
   - For each relevant question about the plan, use `AskUserQuestion` with one question at a time.
   - Always include the recommended answer as the first option.
   - If the answer can be found in the codebase, explore the code and answer without asking.
   - Continue until there are no more relevant open questions.
4. When grill-me concludes:
   - Suggest a short kebab-case title for the plan and confirm with the user.
   - Save the refined plan locally in `.plans/YYYY-MM-DD-<title>.md` with frontmatter:
     ```
     ---
     date: YYYY-MM-DD
     title: <title>
     ---
     ```
   - Suggest: `Plan saved. Run /bsdd-implement <title> to continue.`
