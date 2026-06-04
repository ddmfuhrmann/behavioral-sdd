> Adapt to your stack — the test runner commands and infrastructure tools below are examples. Replace with your project's actual test framework, container tooling, and conventions.

# Skill: Testing Strategy

## Purpose
Choose the right test type for each assertion. Default to the test type that gives the most confidence for the least maintenance cost.

## Test type selection

| Test type | Use when | Avoid when |
|---|---|---|
| Unit | Pure logic, no I/O, deterministic transformation | The behavior depends on a real database or external state |
| Integration | Code interacts with a database, queue, cache, or file system | The dependency can be replaced by a simple in-memory stub |
| Contract | Service produces or consumes an API that another team/service depends on | It's an internal-only interface with a single consumer |
| End-to-end | A full user-facing flow must be verified from input to output | The flow is already covered by lower-level tests |

## Rules
- Do not mock what you can spin up cheaply (use containers or in-memory equivalents).
- Do not write end-to-end tests for logic that unit tests cover.
- One test per assertion. Do not pack multiple behaviors into one test.
- Test failure paths as deliberately as success paths.
- Test names should describe behavior, not implementation: `whenUserHasNoPermission_shouldReturn403` not `testAccessControl`.

## Coverage targets
- All plan assertions must have at least one test.
- All error paths in the revised plan must be tested.
- Edge cases from `.skills/edge-case-generation.md` applied to each public method/endpoint.

## Checklist
- [ ] Test type matches the dependency profile of the code under test
- [ ] No mocks where real infrastructure would be more appropriate
- [ ] Failure paths tested
- [ ] Test names describe behavior
- [ ] All plan assertions covered
