# Skill: Plan-First Development

## Purpose
Ensure implementation always starts from a written, challenged, and revised plan — never from raw input directly.

## Rules
- A plan must exist before any file is touched.
- A plan must be challenged (`/grill-me`) before it is revised.
- A revised plan must exist before implementation starts.
- The revised plan is the single source of truth for implementation, testing, and review.
- If the task changes mid-implementation, stop and update the plan first.

## What a good plan contains
- Clear understanding of the task (not a restatement of the input)
- Explicit assumptions (each one is a risk)
- Concrete scope (specific files and behaviors, not vague layers)
- Explicit out-of-scope items
- A concrete approach (not abstract patterns — specific classes, methods, behaviors)
- Test cases anticipated
- Risks identified
- Blocking questions surfaced before work begins

## What a bad plan looks like
- Restates the ticket verbatim
- Scope is "update the service layer"
- No assumptions listed (means none were examined)
- No blocking questions (means none were considered)
- Approach describes patterns instead of concrete changes

## Checklist (before approving plan for implementation)
- [ ] Understanding is specific, not generic
- [ ] At least one assumption is listed (or "none" with justification)
- [ ] Scope lists files or components, not just layers
- [ ] Out-of-scope section exists
- [ ] Approach describes actual changes, not architecture patterns
- [ ] Tests needed are listed with test type rationale
- [ ] Risks include integration points and data concerns
- [ ] Blocking questions are explicit (or confirmed as "none")
