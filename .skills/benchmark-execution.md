# Skill: Benchmark Execution

## Purpose
Measure endpoint or job throughput and latency under realistic load before and after optimization.

## Tools

| Tool | Use for |
|---|---|
| `wrk` / `wrk2` | HTTP endpoint latency and throughput |
| `k6` | Scripted load scenarios with assertions |
| JMH | JVM microbenchmarks (method-level) |
| Custom timer | Batch job wall-clock time |

## Minimum benchmark parameters
- Duration: ≥ 30 seconds (allow JIT to warm up for JVM)
- Concurrency: match expected production concurrency, or document what you used
- Warm-up: always warm up before capturing measurements

## wrk example

```bash
# Baseline: 10 threads, 100 connections, 60 seconds
wrk -t10 -c100 -d60s --latency http://localhost:8080/api/orders

# Output to capture:
# Requests/sec, Latency (avg, p50, p99, max), Errors
```

## Batch job example

```bash
time ./gradlew runJob --input=seed-data-100k.csv
# Capture: real time, user time, sys time
```

## Baseline format

```
Tool: wrk
URL: POST /api/orders
Concurrency: 100 connections, 10 threads
Duration: 60s
Warm-up: 10s excluded

Requests/sec:  1,234
Latency p50:   42ms
Latency p99:   310ms
Latency max:   1,204ms
Errors:        0
```

## Checklist
- [ ] Warm-up run completed before measurement
- [ ] Duration ≥ 30s
- [ ] Concurrency documented
- [ ] p99 latency captured (not just average)
- [ ] Error rate captured
- [ ] Same methodology used for before and after
