# /bsdd-sync-patterns

Scans the codebase and updates `.skills/patterns.md` with the latest canonical patterns.

## When to use

After implementing a new relevant pattern that other agents should follow. Prevents `.skills/patterns.md` from going stale.

## Procedure

1. Read all source files in the main source directory and test directory.
2. Identify recurring patterns in:
   - Data models / entities (construction patterns, domain behavior, validation)
   - Business logic (state transitions, guard clauses, private helpers)
   - Service layer (transactions, outbox pattern or equivalent)
   - Processors (idempotency, delegation to private methods)
   - Integration tests (setup, given/when/then, fixtures)
3. Rewrite `.skills/patterns.md` with real, updated snippets from the codebase.
4. Confirm: `patterns.md updated with X patterns.`
