# Skill: Optimization Reporting

## Purpose
Document every optimization attempt with baseline, change, measurement, and trade-offs — regardless of outcome.

## Rules
- A rejected optimization is still worth documenting. Future engineers should know it was tried.
- Never state improvement without stating what got worse.
- Always include the recommendation and a one-sentence reason.

## Report template

```
## Optimization Report

**Target:** [specific query / endpoint / job / component]
**Triggered by:** [review finding | plan item | monitoring alert]

### Baseline
- Method: [EXPLAIN ANALYZE | wrk | JMH | timer]
- Data volume: [rows / requests / size]
- Key metric: [execution time / p99 latency / throughput]
- Result: [raw numbers]

### Change Applied
[Description of change]
[Relevant diff or new query]

### After Measurement
- Key metric: [same metric as baseline]
- Result: [raw numbers]
- Delta: [absolute and percentage change]

### Trade-offs
- [What got worse, more complex, or more fragile]
- [Maintenance cost if any]
- [Correctness implications if any]

### Recommendation
APPLY | APPLY WITH MONITORING | DEFER | REJECT
Reason: [one sentence]
```

## Checklist
- [ ] Baseline measured before change
- [ ] Same measurement method used before and after
- [ ] At least one trade-off stated
- [ ] Recommendation includes reason
- [ ] Report attached to PR if change is merged
