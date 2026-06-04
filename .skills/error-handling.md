> Adapt to your stack — the exception types and HTTP mappings below are examples. Replace with your project's actual error strategy, domain exceptions, and API response conventions.

# Skill: Error Handling

## Exception strategy

| Scenario | Exception | Example |
|---|---|---|
| Domain invariant violated | Domain exception (e.g. `IllegalStateException`) | `Order.confirm()` when not in PENDING state |
| Invalid input / argument | Validation exception (e.g. `IllegalArgumentException`) | Entity not found by ID; null or negative amount |
| External service failure | Infrastructure exception (wrapping original) | Failed HTTP call to payment provider |
| Idempotent no-op (not an error) | Silent return | Processor finds record already in final state |

## Domain behavior

Domain methods enforce their own invariants and throw immediately:

```
// Example: invalid state transition
public void confirm() {
    if (this.status != Status.PENDING) {
        throw new DomainException(
            "Cannot confirm from status " + status
        );
    }
    // proceed
}
```

## Application layer

Command services and processors do not catch domain exceptions — they let them propagate.
The caller (or transaction boundary) is responsible for rollback.

Business-level failure (e.g. insufficient funds) is handled as a domain outcome, not an exception: record a failure event and return normally.

## Infrastructure

Infrastructure adapters wrap lower-level exceptions with a descriptive message:

```
throw new InfrastructureException(
    "Failed to call payment provider: " + e.getMessage(), e
);
```

## HTTP mapping (when applicable)

| Exception | HTTP status |
|---|---|
| Validation / bad input | 400 |
| Entity not found | 404 |
| Conflict / duplicate | 409 |
| Domain invariant violation | 422 |
| Unhandled | 500 |
