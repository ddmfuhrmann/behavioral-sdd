# Skill: Diff Review

## Purpose
Review a code diff against a revised plan and project guidelines. Produce actionable, severity-labeled findings.

## Process

1. Read the revised plan in full. Note: scope, out-of-scope, approach, files expected to change.
2. Read the diff. For each changed file, ask:
   - Is this file in the plan's "files likely to change" list? If not, why was it touched?
   - Does the change match the described approach?
   - Is there anything here that wasn't in scope?
3. For each finding, assign severity:
   - **BLOCKER**: Incorrect behavior, missing required test, breaking change, security issue, scope violation that changes semantics.
   - **WARNING**: Guideline violation, missing edge case test, unnecessary complexity that should be addressed before merge.
   - **SUGGESTION**: Style preference, minor improvement, future consideration — does not block merge.
4. Produce the review output using the Reviewer's output format.

## What to look for

| Category | Examples |
|---|---|
| Scope creep | New method not in plan, new dependency not discussed, new config key |
| Missing tests | Plan assertion with no corresponding test |
| Breaking changes | Changed method signature, removed field, changed error code |
| Unnecessary complexity | Abstraction added for single use case, premature generalization |
| Guideline violations | See `.skills/code-style.md`, `.skills/project-architecture.md` |
| Dead code | Commented-out code, unused imports, unreachable branches |

## Checklist
- [ ] Every file in the diff is accounted for (in plan or explained)
- [ ] Every plan scope item appears in the diff
- [ ] No out-of-scope items without explicit justification
- [ ] All BLOCKER findings have file + line reference
- [ ] Test coverage assessed against plan assertions
