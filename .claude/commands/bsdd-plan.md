# /bsdd-plan

Entry point of the development cycle. Transforms any input (conversation, ticket, PRD, vague idea) into a refined plan via the grill-me loop.

## Procedure

1. Enter plan mode via `EnterPlanMode` so the rest of this command runs inside the native planning flow. This gives you the native plan file (its path is provided in the plan mode system message) and the native approval UI at the end. The user must consent to entering plan mode.
2. Use the native Plan agent (subagent_type: Plan) to explore the codebase and understand the impact of the task.
3. Produce a structured plan with the following sections:
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
4. Start the grill-me loop automatically:
   - For each relevant question about the plan, use `AskUserQuestion` with one question at a time.
   - Always include the recommended answer as the first option.
   - If the answer can be found in the codebase, explore the code and answer without asking.
   - Continue until there are no more relevant open questions.
   - Do NOT use `AskUserQuestion` to ask whether the plan is approved — that is what `ExitPlanMode` does in the next step.
5. When grill-me concludes:
   - Suggest a short kebab-case title for the plan and confirm with the user.
   - Write the refined plan to the native plan file (path given in the plan mode system message).
   - Call `ExitPlanMode` to present the plan and request native approval. The user can accept (optionally auto-accepting edits) or reject. If rejected, fold the feedback back into the plan and call `ExitPlanMode` again.
6. After the plan is approved:
   - Save a copy of the approved plan in `.plans/YYYY-MM-DD-<title>.md` with frontmatter:
     ```
     ---
     date: YYYY-MM-DD
     title: <title>
     ---
     ```
   - Suggest: `Plan saved. Run /bsdd-implement <title> to continue.`
