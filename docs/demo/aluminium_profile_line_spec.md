# Aluminium Profile Line 1 — Decision Demo Spec

A human-readable companion to `contracts/register_map.json`, `sim/modbus_sim/scenario_state.py`, and `db/migrations/008_aluminium_decision_views.sql`. This document tells the story. The code enforces it.

---

## Line Overview

**Site**: `demo-site` → *Penang Plant 1 — Aluminium Profile Line 1*
**Line**: `aluminium-profile-line-1`
**Cells**:
- `extrusion-cell-a` — furnace, press, quench, cooling
- `finishing-cell-b` — stretcher, saw, ageing

A billet enters cold at the furnace and leaves the line as a cut, tempered, customer-ready aluminium profile. Seven stations, sequential. If any upstream station stops, downstream stations starve; if any downstream station clogs, upstream WIP piles up.

---

## Glossary

- **Billet** — a cast aluminium log (typically 7 inch dia × 800 mm) fed into the extrusion press.
- **Homogenisation** — low-temperature soak in the furnace that evens out the billet's internal microstructure before extrusion.
- **Extrusion** — hydraulic press forces the billet through a steel die, producing a continuous profile of the required cross-section.
- **Quenching** — rapid cooling immediately after extrusion that "locks in" the alloy's solution state. Critical for T5/T6 temper.
- **T5 / T6 temper** — standard heat-treatment designations. T5 is "cooled from extrusion + artificially aged"; T6 is "solution-heat-treated + artificially aged" (harder, used for structural parts like bumpers).
- **Stretching** — a post-extrusion straightening operation that pulls the profile to eliminate bow and twist. Typically 0.8–2.2 % elongation.
- **Ageing** — controlled low-temperature oven hold (typically ~180 °C for ~8 hours) that completes the T6 temper by precipitation hardening.
- **MTBF / MTTR** — Mean Time Between Failures / Mean Time To Repair (minutes for MTTR here).

---

## Station Reference

| # | asset_id       | base_addr | Primary signal       | Warn band   | Secondary signal        | Counter                     | Why it matters |
|---|----------------|-----------|----------------------|-------------|-------------------------|-----------------------------|----------------|
| 1 | `furnace-01`   | 0         | `billet_temp_c`      | 540–600 °C  | `preheat_zone_temp_c`   | `billet_loaded_count`       | Wrong soak = wrong microstructure. |
| 2 | `press-01`     | 20        | `ram_force_kn`       | 1500–2400   | `exit_profile_temp_c`   | `press_cycle_count`         | Heart of the line. Highest cost-when-down. |
| 3 | `quench-01`    | 40        | `quench_flow_lpm`    | 180–260     | `exit_temp_c`           | `quenched_profile_count`    | T5/T6 temper gatekeeper. |
| 4 | `cooling-01`   | 60        | `table_temp_c`       | 40–85 °C    | `conveyor_speed_m_min`  | `cooled_profile_count`      | WIP buffer; blocks finishing if full. |
| 5 | `stretcher-01` | 80        | `stretch_force_kn`   | 120–240 kN  | `stretch_pct`           | `stretched_profile_count`   | Straightness gate. Required before saw. |
| 6 | `saw-01`       | 100       | `blade_rpm`          | 2400–3200   | `cut_length_dev_mm`     | `cut_profile_count`         | Dimensional accuracy. Blade wear = scrap. |
| 7 | `ageing-01`    | 120       | `oven_temp_c`        | 170–195 °C  | `oven_dwell_min`        | `aged_batch_count`          | T6 temper completion. End-of-line. |

Every station follows the same 8-word Modbus stride:

| offset | type    | content        |
|-------:|---------|----------------|
| 0–1    | float32 | primary signal |
| 2–3    | float32 | secondary      |
| 4–5    | uint32  | counter        |
| 6      | uint16  | state_code     |
| 7      | uint16  | fault_code     |

---

## State codes

| code | state       | meaning                              |
|------|-------------|--------------------------------------|
| 0    | IDLE        | Powered but not producing            |
| 1    | STARTUP     | Ramp-up, warming, purging            |
| 2    | RUNNING     | Producing at nominal throughput      |
| 3    | FAULTED     | Active fault — requires intervention |
| 4    | MAINTENANCE | Planned PM or changeover             |

## Fault catalog (with MTTR estimates)

| code | asset         | fault                      | MTTR (min) | Notes |
|------|---------------|----------------------------|-----------:|-------|
| 111  | furnace-01    | OVER_TEMPERATURE           | 60  | Zone thermocouple drift. |
| 112  | furnace-01    | UNDER_TEMPERATURE          | 45  | Setpoint regulation loop. |
| 113  | furnace-01    | BURNER_TRIP                | 240 | Igniter or safety interlock. |
| 211  | press-01      | EXTRUSION_OVERLOAD         | 120 | Die back-end worn — regrind or replace. |
| 212  | press-01      | BILLET_JAM                 | 60  | Clear and re-align. |
| 219  | press-01      | PRESS_EMERGENCY_TRIP       | 300 | Full interlock cycle; hydraulic check. |
| 311  | quench-01     | QUENCH_FLOW_LOW            | 30  | Strainer / nozzle clean; flagship fault. |
| 312  | quench-01     | QUENCH_TEMP_HIGH           | 45  | Chiller loop. |
| 411  | cooling-01    | COOLING_TABLE_HOT          | 30  | Air intake blocked. |
| 412  | cooling-01    | COOLING_AIR_FLOW_LOW       | 45  | Filter change. |
| 511  | stretcher-01  | STRETCH_SLIP               | 30  | Grip reface. |
| 512  | stretcher-01  | STRETCH_FORCE_HIGH         | 60  | Load cell or hydraulic. |
| 611  | saw-01        | BLADE_WEAR                 | 45  | Routine blade change (~4 wk cadence). |
| 612  | saw-01        | CUT_LENGTH_DEVIATION       | 30  | Length-gauge encoder. |
| 711  | ageing-01     | AGE_TEMP_DEVIATION         | 90  | Heater element. |
| 712  | ageing-01     | AGE_DWELL_SHORT            | 60  | Door seal / dwell timer. |

---

## Scenarios

| scenario                 | trigger                                                               | health   | primary owner         | story |
|--------------------------|-----------------------------------------------------------------------|----------|-----------------------|-------|
| `NORMAL`                 | All stations running                                                  | GREEN    | Shift Supervisor      | Baseline production. |
| `QUALITY_HOLD_QUENCH` ★  | quench-01 → fault 311                                                 | AMBER    | Quality               | **Flagship.** Flow drops + exit temp rises. Automotive Customer B batch on P2 hold. |
| `PRESS_BOTTLENECK`       | press-01 → fault 211; downstream IDLE                                 | AMBER    | Maintenance           | Line heart fails; everything downstream starves. |
| `STRETCHER_BACKLOG`      | stretcher-01 → state 4 (MAINTENANCE)                                  | AMBER    | Shift Supervisor      | Cooling table WIP accumulates. |
| `AGEING_OVEN_DEVIATION`  | ageing-01 → fault 711                                                 | AMBER    | Quality               | T6 batch out of spec; retest required. |
| `EMERGENCY_PRESS_TRIP`   | press-01 → fault 219; all others IDLE                                 | CRITICAL | Plant Manager         | Full line down. Invoke BCP. |

Each scenario's exact per-station state is in `sim/modbus_sim/scenario_state.py::SCENARIO_STATES`. Each scenario's decision-board actions are seeded in `db/migrations/008_aluminium_decision_views.sql::decision_board_rules`.

---

## Flagship — QUALITY_HOLD_QUENCH forensic signature

Two telemetry signals, together, tell the whole story:

1. `quench-01 / quench_flow_lpm` drops from ~220 → ~148 lpm (below the 180 warn floor).
2. `quench-01 / exit_temp_c` climbs from ~58 → ~94 °C (above the 80 warn ceiling).

One signal without the other looks like a sensor fault. Both signals together is physics: not enough water, so the profile leaves the quench still hot, so it doesn't lock into T5/T6 temper, so `BATCH-AL-241024-Q3` — which is 120 bumper-reinforcement profiles for Automotive Customer B's `PO-AL-2024-0021` — goes on quality hold for re-inspection.

Value at risk: 120 profiles × RM 95 unit revenue = **RM 11,400 direct**, plus line-cost accrual at RM 260/hr while quench is faulted.

This is why the scenario is flagship — the correlated signals make the plant condition unambiguous, and the decision board converts "something's wrong" into "Quality: hold the batch; Maintenance: inspect nozzles; Supervisor: call the account manager" in the first 60 seconds.

---

## Customer sanitization

Customer names are deliberately generic archetypes — not real companies. Any resemblance to actual Penang-based buyers is coincidental. The three archetypes:

- **MNC Customer A** — a multinational electronics/industrial buyer. Heatsink profiles. Cost-sensitive.
- **Automotive Customer B** — Tier-1 or Tier-2 automotive supplier. Bumper-reinforcement profiles. Quality-sensitive and time-sensitive (the flagship at-risk order).
- **Building Systems Customer C** — window-frame and architectural. Volume-driven, longer lead time.

For client-facing demos, replace these strings in `db/migrations/005_business_context.sql::production_orders` with the real customer archetype that matches the plant's book of business.

---

## Data flow recap (so the demo story stays straight)

```
Modbus sim (port 1502) ──► collector (MQTT) ──► mosquitto ──► ingestor ──► TimescaleDB
                                                                                │
                                          ┌─────────────────────────────────────┤
                                          ▼                                     ▼
                            v_aluminium_decision_board            v_aluminium_line_current_state
                                          │                                     │
                ┌─────────────────────────┼─────────────────────────┐           │
                ▼                         ▼                         ▼           ▼
        Grafana (5)                FastAPI /dashboard         Svelte (8000)    (all)
```

Single source of truth: the SQL view. If Grafana and the REST API ever disagree, the view is wrong, not the UI.
