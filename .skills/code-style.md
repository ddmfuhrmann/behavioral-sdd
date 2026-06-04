> Adapt to your stack — the conventions below are examples. Replace with your project's actual naming rules, DTO patterns, and formatting standards.

# Skill: Code Style

## Naming

| Element | Convention | Example |
|---|---|---|
| Classes | PascalCase | `UserService`, `OrderStatus` |
| Methods | camelCase, verb-first | `create()`, `findById()`, `markCompleted()` |
| Constants / enum values | UPPER_SNAKE | `ORDER_PLACED`, `PENDING` |
| Database columns | snake_case | `user_id`, `created_at`, `total_amount` |
| Test methods | `shouldXxxWhenYyy` | `shouldReturnErrorWhenBalanceInsufficient` |

## DTOs

- Use immutable value objects for commands and responses.
- Separate input DTOs (commands/requests) from output DTOs (responses/events).

## Entities / Models

- No public setters — all mutation through named domain methods.
- Enforce invariants inside the model, not in the service layer.

## Injection

- Constructor injection preferred. Avoid field injection.

## Method size

- Target: ≤ 20 lines per method.
- Extract to private methods with descriptive names rather than adding comments.

## Comments

- No comments for obvious code.
- Comments explain WHY, not WHAT.
- No doc comments on internal classes.

## Imports

- No wildcard imports.
- Static imports only for test assertions.

## Formatting

- Consistent indentation (match your language/framework standard).
- No trailing whitespace.
