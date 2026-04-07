# ADR-004 — ISA-95 MQTT Topic Hierarchy

**Date:** 2026-04-07
**Status:** Accepted

---

## Context

MQTT topic design is a one-way door. Once devices are publishing to a topic structure and consumers are subscribing to it, changing the structure requires coordinated updates across every service, dashboard, and external subscriber. Getting this wrong early is expensive.

NEXUS will eventually run across multiple sites with hundreds of assets. The topic structure must:
- Be unambiguous (no collisions between assets or sites)
- Support selective subscription (a site manager subscribes to their site only)
- Enable access control (ACL rules map to topic prefixes)
- Carry enough context in the topic itself that consumers don't need to decode the payload to route a message

---

## Decision

We follow the **ISA-95 equipment hierarchy** for MQTT topic naming:

```
iiot/v1/{message_type}/{site}/{area_or_line}/{asset}/{signal_or_event_type}
```

**Examples:**
```
iiot/v1/telemetry/penang-plant-1/packaging-line-1/conveyor-01/temperature
iiot/v1/telemetry/penang-plant-1/packaging-line-1/conveyor-01/speed_rpm
iiot/v1/events/penang-plant-1/packaging-line-1/conveyor-01/alarm_raised
iiot/v1/alerts/penang-plant-1/packaging-line-1/conveyor-01/a3f92c1d
```

**Naming rules:**
- Lowercase only, hyphens as word separators (no underscores in hierarchy levels, no spaces)
- `v1` version prefix allows future schema migrations without breaking existing subscribers
- `message_type` is one of: `telemetry`, `events`, `alerts`
- `site` is the physical location identifier (e.g., `penang-plant-1`, `demo-site`)
- `area_or_line` is the production line or functional zone (e.g., `packaging-line-1`, `assembly`)
- `asset` is the equipment identifier (e.g., `conveyor-01`, `feeder-01`)
- `signal_or_event_type` is the measurement name or event classification

---

## Subscription Patterns

The hierarchy enables clean wildcard subscriptions:

```
# Receive all telemetry from a specific site
iiot/v1/telemetry/penang-plant-1/#

# Receive all events across all sites (e.g., central alert aggregator)
iiot/v1/events/#

# Receive all messages for one asset
iiot/v1/+/penang-plant-1/packaging-line-1/conveyor-01/#

# Ingestor: subscribe to all telemetry and events
iiot/v1/telemetry/#
iiot/v1/events/#
```

---

## ISA-95 Mapping

| ISA-95 Level | NEXUS Topic Level | Example |
|---|---|---|
| Enterprise | (implicit — single company) | — |
| Site | `{site}` | `penang-plant-1` |
| Area | `{area_or_line}` | `assembly`, `qc` |
| Production Line | `{area_or_line}` | `packaging-line-1` |
| Work Cell / Equipment | `{asset}` | `conveyor-01` |
| Data Point | `{signal}` | `temperature`, `speed_rpm` |

The area and line levels share a single topic segment because in practice (and at Alumac) the distinction is often not needed at the data pipeline level. It can be split to two levels in a future version bump.

---

## ACL Example (Mosquitto)

```
# Collector for site A — can only publish to its own site
user collector_site_a
topic write iiot/v1/telemetry/penang-plant-1/#
topic write iiot/v1/events/penang-plant-1/#

# Ingestor — subscribes to all telemetry and events
user ingestor
topic read iiot/v1/telemetry/#
topic read iiot/v1/events/#

# Alert service — subscribes to telemetry, publishes alerts
user alerting
topic read iiot/v1/telemetry/#
topic write iiot/v1/alerts/#
```

This pattern means that a misconfigured or compromised collector at Site A cannot publish to Site B's topics. Security is enforced at the broker level, not just in application code.

---

## Consequences

- All services must parse the topic string to extract `site`, `line`, `asset`, `signal`. This is done in `services/ingestor/app.py` and `services/alerting/detector.py` with a simple `topic.split("/")` call. The fixed 6-level depth makes parsing deterministic.
- Adding a new site requires no code changes — only a new collector deployment with `SITE=new-site` and a new ACL entry in `infra/mosquitto/aclfile`.
- The `v1` prefix means a future breaking schema change can be deployed alongside `v2` topics without downtime, with consumers migrated gradually.

---

## Rejected Alternatives

**Flat topics** (e.g., `sensor/conveyor01/temperature`) — no site hierarchy, no access control possible at broker level, collapses when scaling to multiple sites.

**Asset-first hierarchy** (e.g., `asset/conveyor-01/penang-plant-1/temperature`) — harder to subscribe to all data from one site using MQTT wildcards.

**SparkplugB** — a full MQTT specification for IIoT with birth certificates, will messages, and namespace standards. More complete than our approach but significantly more complex to implement and debug. Appropriate for a product; excessive for a portfolio platform. NEXUS's contract-driven approach covers the same functional ground.
