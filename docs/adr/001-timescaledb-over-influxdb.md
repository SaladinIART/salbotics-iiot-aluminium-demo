# ADR-001 — TimescaleDB over InfluxDB

**Date:** 2026-04-07
**Status:** Accepted

---

## Context

NEXUS needs a time-series database to store sensor telemetry and events. The two most common options in the IIoT space are InfluxDB and TimescaleDB. Both can handle high-frequency sensor writes. The choice has long-term implications for query flexibility, operational stability, and team skills.

---

## Decision

We use **TimescaleDB** (PostgreSQL 16 extension) as the primary storage layer.

---

## Reasons

**1. SQL is the common language on the factory floor.**
Shift supervisors, process engineers, and IT teams all understand SQL. InfluxDB uses Flux — a proprietary query language that requires dedicated learning and produces queries that are difficult to audit or hand off.

**2. Manufacturing data is relational, not purely time-series.**
A telemetry row needs to JOIN to asset metadata, shift schedules, and production orders. TimescaleDB handles this natively as a PostgreSQL extension. InfluxDB requires a separate relational database and application-layer joins, which adds complexity and latency.

**3. TimescaleDB performs better at scale.**
Independent benchmarks show TimescaleDB outperforms InfluxDB 3.5×–71× on complex queries involving aggregations, JOINs, and high-cardinality tag sets (100+ unique assets). InfluxDB performs well at simple, low-cardinality metrics queries, but NEXUS is designed to eventually handle multi-site deployments.

**4. InfluxDB's API stability is a risk.**
InfluxDB rewrote its core engine twice in five years (InfluxDB 1 → 2 → 3), each time with breaking API changes. TimescaleDB sits on top of PostgreSQL's 25-year-old stable foundation. The risk of forced migrations is materially lower.

**5. We already have the skill.**
The base repo and prior work at Alumac Industrience both used PostgreSQL-compatible SQL. No new mental model required.

---

## Consequences

- We must manage a PostgreSQL instance rather than a dedicated time-series appliance. This is lower operational burden than it sounds — TimescaleDB runs as a standard Docker container with a well-understood backup/restore story.
- Hypertable partitioning must be set up correctly on `telemetry` and `events` tables. This is a one-time migration step (already done in `db/migrations/001_init.sql`).
- Complex dashboards in Grafana are easier to build because queries are standard SQL with familiar aggregation functions (`time_bucket`, `first`, `last`).

---

## Rejected Alternative

**InfluxDB 2** — rejected due to Flux learning curve, relational JOIN limitations, and historical API instability. Reconsidered if NEXUS ever moves to a managed cloud time-series service at very large scale (>10,000 devices), but that is out of scope for now.
