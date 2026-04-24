# Prompt Templates

## Planner Agent

You are the Project Planner for an industrial IIoT telemetry stack.
Produce a dependency-ordered task graph with acceptance criteria, artifacts, and verification steps.
Never write code directly.
Every task must list inputs, outputs, and failure modes.

## PLC and Modbus Mapping Agent

You are a controls engineer specializing in Modbus TCP integration.
Output a register map with addressing assumptions, scaling, endianness, and simulator test vectors.

## Collector Agent

You are an edge software engineer.
Implement a Python service that polls Modbus TCP and publishes MQTT messages with retries, timestamps, sequence IDs, structured logs, graceful shutdown behavior, and tests.

## MQTT Contract Agent

You are a messaging architect.
Define the topic taxonomy, payload schema, QoS choices, retain rules, and Last Will strategy for telemetry and status topics.

## Timescale Agent

You are a database engineer.
Define the schema, hypertable, indexes, retention policy, compression policy, and stable query surface for dashboards.

## Grafana Agent

You are a Grafana operator.
Produce reproducible datasource and dashboard provisioning files with no manual console steps.

## Verifier Agent

You are a QA engineer.
Attempt to break the system using malformed payloads, dependency outages, and replay scenarios.
Return pass or fail results with concrete reproduction steps.

---

## Demo Rehearsal — QUALITY_HOLD_QUENCH (Flagship)

**Scenario**: The water quench at the heart of the aluminium extrusion line loses flow. Exit temperature climbs because the profile isn't being cooled fast enough. In-flight profiles sit outside the T5/T6 temper window and have to be held for re-inspection. This is a P2 quality hold — no one gets hurt, but the batch ships late or gets scrapped, and an automotive customer's bumper-reinforcement order is on the line.

**60-second elevator pitch**:
> Stakeholder clicks `QUALITY_HOLD_QUENCH`. Within 5 seconds the Svelte scenario banner flips to amber. Grafana's *Decision Board* populates with four P2 actions (Quality, Maintenance, Shift Supervisor, Operator), each naming the affected batch `BATCH-AL-241024-Q3` and order `PO-AL-2024-0021` for Automotive Customer B. The *Quality Risk* table shows the RM 76,000 value-at-risk. The *Station Telemetry Trend* panel (with `station` dropdown on `quench-01`) shows flow dropping below 180 lpm while exit temp climbs above 80 °C — two independent forensic signals telling the same story. Everything across Grafana, Svelte, and the REST API comes from the same SQL view. No drift.

**Script (step-by-step)**:
1. Open Grafana → *Aluminium Profile Decision Board* dashboard. Confirm GREEN health.
2. In a second tab, open `http://localhost:8080/` and navigate to **Executive View** from the sidebar.
3. Click `Quality Hold — Quench` in the Demo Control Panel.
4. Point out: Line Health → AMBER. Open alerts count → 1–2. Active Quality Holds → 1.
5. Walk through the Decision Board rows top-down (P2 Quality first — that's the operator's first call).
6. Drop to the *Quality Risk* table — customer, order, value-at-risk are all named.
7. Filter the trend panel to `quench-01`. Point out the correlated flow drop + temp rise.
8. Reset: click `Normal`. Panels converge back to GREEN within ~10 seconds.

**Rehearsal tips**:
- Before a live demo, run the scenario once and let it sit 60 seconds so the hourly-throughput panel has a dent in it.
- If the Svelte UI still shows stale packaging-era copy, `services/api/static/` was not rebuilt — rerun the frontend build and refresh the API container.

## Recruiter Q&A — "Why aluminium? Why this stack?"

**Q: Why did you pick aluminium extrusion over a generic factory demo?**
Aluminium is where Penang's heavy manufacturing sits — billets, presses, T5/T6 tempers — so the domain is credible to local recruiters and plant managers, and the physics of quenching gives a cleaner correlated-signals story than a bolt-on "temperature alert" would. The flagship scenario drops quench flow *and* raises exit temperature simultaneously, because that's what actually happens when a quench pump impeller wears out.

**Q: What does this stack prove you can do?**
Every layer is end-to-end: Modbus simulator → MQTT contract → TimescaleDB hypertables (with retention and compression policies) → FastAPI with auth and SSE → Svelte 5 frontend → provisioned Grafana with a shared datasource UID. The *Decision Board* view is a single source of truth that both the API and Grafana read from — no duplicated business logic. I wired in a scenario control panel so the demo is reproducible in 30 seconds, and the database migrations are idempotent on a fresh volume.

**Q: How would this change if you joined our plant?**
The `contracts/register_map.json` is the only file that's asset-specific. Point it at your actual PLCs, update the alert rules, and the rest of the pipeline carries over without modification. The decision-board rules table is where your plant's SOPs would live — I'd sit with your shift supervisors to seed it properly.

## Client Q&A — "What can your stack do for my plant?"

**Q: How does this map to our factory?**
You tell me which stations, I give you the register map by end of week 1. The stack handles ISA-95 topic hierarchy (site → line → cell → asset), so a multi-line plant just means more asset rows. Alert rules are data, not code — supervisors tune them without a deploy.

**Q: Rough ROI?**
One avoided quality-hold-quench episode per month pays for the stack. In this demo scenario the value-at-risk is ~RM 76,000 for a single automotive batch. The Decision Board converts "something is wrong" into "here's who does what in the next 15 minutes" — which is where most plants lose time today.

**Q: What if we just want the data, not the dashboards?**
Every dashboard panel is backed by a SQL view. Drop the Grafana container, point your existing BI tool (Power BI, Superset, Tableau) at TimescaleDB, and you get the same numbers.

