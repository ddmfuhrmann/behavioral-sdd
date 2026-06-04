# Skill: Grill Me (Plan Challenge)

## Purpose
Find weaknesses in the plan before any code is written. A plan that has not been challenged is a liability.

## Rules
- Challenge the plan, not the person.
- Every challenge must be specific — not "this might be risky" but "if X assumption is wrong, Y breaks because Z."
- Prefer finding one real problem over five superficial ones.
- Do not suggest rewrites. Surface issues; let the author revise.

## Challenge dimensions

### Vague assumptions
Which assumptions are load-bearing? What breaks if they're wrong?
Example: "Assumes the user always has a valid session — what happens on token expiry mid-flow?"

### Hidden scope
What will a developer naturally implement that isn't written down?
Example: "Adding this endpoint implies adding auth middleware — is that in scope?"

### Risky design choices
What introduces coupling, fragility, future pain, or over-engineering?
Example: "Introducing an event bus for a single use case is premature — a direct call would suffice."

### Missing edge cases
What scenarios aren't covered? Failure paths, concurrent access, invalid input, empty states, pagination boundaries?

### Unnecessary abstractions
What is being added that isn't needed for the current task?

### Simpler alternatives
Is there a path with fewer moving parts that achieves the same outcome?

### Missing blocking questions
What should have been asked before writing the plan?

## Checklist
- [ ] At least one assumption challenged
- [ ] Scope boundary tested (what's implied but not stated?)
- [ ] At least one edge case surfaced
- [ ] Design choices interrogated for simplicity
- [ ] A simpler alternative considered (even if rejected)
