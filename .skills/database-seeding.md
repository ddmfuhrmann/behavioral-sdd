# Skill: Database Seeding

## Purpose
Populate a local or test database with realistic data volume for meaningful performance measurement.

## Rules
- Seed data must be realistic in volume. Testing a query on 100 rows when production has 10M rows is not a baseline.
- Seed data must be realistic in shape. Use real-ish values, not all-nulls or all-zeros.
- Seed scripts must be idempotent. Running them twice should not fail.
- Document the volume seeded in every optimization report.

## Seed approaches

### SQL generation script
```sql
-- Generate 100k users with realistic data
INSERT INTO users (id, email, status, created_at)
SELECT
    gen_random_uuid(),
    'user' || i || '@example.com',
    CASE WHEN i % 10 = 0 THEN 'INACTIVE' ELSE 'ACTIVE' END,
    NOW() - (random() * INTERVAL '365 days')
FROM generate_series(1, 100000) AS i
ON CONFLICT DO NOTHING;
```

### Application-level seed command
```bash
./gradlew seed --rows=100000 --profile=perf
```

## Volumes for meaningful measurement

| Table size | Minimum seed for perf testing |
|---|---|
| < 10k rows in prod | 10k |
| 10k–1M rows in prod | 100k |
| > 1M rows in prod | 1M or representative sample |

## Checklist
- [ ] Row counts documented in optimization report
- [ ] Data distribution matches production shape (not all same value)
- [ ] Indexes match production schema (not missing any)
- [ ] Seed script is idempotent
