# Skill: Edge Case Generation

## Purpose
Systematically surface non-obvious inputs and states that break assumptions.

## Standard edge case categories

### Boundary values
- Minimum and maximum allowed values
- Off-by-one (n-1, n, n+1 around any limit)
- Zero, one, many (for collections and counts)

### Empty and null
- Null inputs
- Empty strings, empty collections
- Fields present but blank vs. fields absent

### Invalid input
- Wrong type coerced (if dynamic typing)
- Malformed identifiers (e.g. UUID with wrong format)
- Values that pass syntax but fail semantics (e.g. negative price)

### Concurrent access
- Two requests modifying the same resource simultaneously
- Read-modify-write without locking

### State transitions
- Resource in wrong state for the operation
- Operation called twice (idempotency)
- Partial failure mid-operation

### External dependencies
- Downstream service times out
- Downstream service returns unexpected status
- Empty response vs. error response

## Process
1. For each public method or endpoint in scope, apply the categories above.
2. Pick the 3–5 most likely to cause production incidents.
3. Write a test for each.

## Checklist
- [ ] Null/empty inputs covered
- [ ] Boundary values covered
- [ ] At least one concurrent access scenario considered
- [ ] At least one external dependency failure scenario considered
