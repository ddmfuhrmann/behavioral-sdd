# Skill: Postgres EXPLAIN ANALYZE

## Purpose
Measure actual query execution cost, identify sequential scans, and validate index usage.

## Command

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ...;
```

Always use `ANALYZE` (executes the query) and `BUFFERS` (shows cache hits vs. disk reads).

## What to look for

| Pattern | Problem | Fix |
|---|---|---|
| `Seq Scan` on large table | Missing index | Add index on filter column |
| `Nested Loop` with high rows | N+1 query | Rewrite with JOIN or batch fetch |
| High `Buffers: shared hit` | Query is cache-dependent | Test with cold cache too |
| `Sort` with no index | Missing index for ORDER BY | Add index on sort column |
| `rows=X (actual rows=Y)` large divergence | Stale statistics | Run `ANALYZE table_name` |

## Baseline format for optimization report

```
Query: SELECT ... (paste full query)
Data volume: 100k rows in users table
EXPLAIN ANALYZE output:

  Seq Scan on users  (cost=0.00..2345.00 rows=100000 width=64)
                     (actual time=0.012..45.231 rows=99832 loops=1)
  Buffers: shared hit=1234

Planning Time: 0.3 ms
Execution Time: 45.5 ms
```

## After index, document:

```
After: CREATE INDEX idx_users_status ON users(status);

  Index Scan using idx_users_status on users  (cost=0.29..8.31 rows=1 width=64)
                                               (actual time=0.021..0.023 rows=1 loops=1)

Execution Time: 0.1 ms   (-99.8%)
```

## Checklist
- [ ] Used ANALYZE (not just EXPLAIN)
- [ ] BUFFERS included
- [ ] Run against seeded data, not empty database
- [ ] Both before and after captured
- [ ] Row count discrepancy noted if significant
