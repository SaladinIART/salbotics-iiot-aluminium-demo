# NEXUS — Industrial Intelligence Platform

> From Factory Floor to Decision Desk

![CI](https://github.com/SaladinIART/IIoT-Telemetry-Stack/actions/workflows/ci.yml/badge.svg)

A self-contained IIoT monitoring platform built to demonstrate the full Digital Transformation stack — from Modbus register reads to a live browser dashboard with real-time alerts. Designed for Penang manufacturing environments. Deployable with a single command.

---

## The Problem This Solves

| Problem | How NEXUS answers it |
|---------|----------------------|
| Factory data trapped in PLCs, managers using spreadsheets | REST API + Svelte frontend — any browser, no training needed |
| DX projects fail because no one bridges PLC + code + DevOps | One engineer owns every layer: Modbus → MQTT → Python → TimescaleDB → FastAPI → Svelte → Docker → CI/CD |
| Failures detected reactively, after machines stop | 3-layer alert engine: threshold rules → statistical baseline → ML anomaly (IsolationForest) |
| AI tools used blindly without architectural ownership | Structured agentic scaffold + Architecture Decision Records document every choice |

---

## Architecture

```
OT LAYER
  sim/modbus_sim        Modbus TCP :1502  (4 assets: feeder, mixer, conveyor, packer)

COLLECTION
  services/collector    Polls Modbus → publishes MQTT
                        Topics: iiot/v1/telemetry/{site}/{line}/{asset}/{signal}
                                iiot/v1/events/{site}/{line}/{asset}/{event_type}

MESSAGING
  infra/mosquitto       Eclipse Mosquitto, ACL auth  (Tier 1/2)
                        → EMQX cluster               (Tier 3)

PROCESSING  (parallel MQTT subscribers)
  services/ingestor     Schema validate → batch write → TimescaleDB
  services/alerting     3-layer detect → deduplicate → route → TimescaleDB + webhook

STORAGE
  TimescaleDB           telemetry · events · alerts · alert_rules · sites · asset_metadata
                        Views: v_asset_current_state · v_recent_alerts · v_kpi_summary

API
  services/api          FastAPI + Uvicorn
                        REST  GET  /api/v1/assets  /assets/{id}/telemetry  /alerts  /kpis  /sites
                              POST /api/v1/alerts/{id}/acknowledge
                        SSE   GET  /api/v1/stream/telemetry   (2s push)
                              GET  /api/v1/stream/alerts      (new OPEN alerts)
                        Auth  X-API-Key header
                        Serves compiled frontend at /

FRONTEND
  frontend/             Svelte 5, compiled vanilla JS
                        /           Floor overview — live asset grid
                        /assets     Asset browser + signal history chart
                        /alerts     Alert inbox + acknowledge
                        /kpis       OEE + production KPIs
                        /admin      Threshold editor + API key

VISUALIZATION
  Grafana :3000         Operator dashboards (direct TimescaleDB queries)
```

**Scale tiers — no code rewrites, only config changes:**

| | Tier 1 (now) | Tier 2 | Tier 3 |
|--|---|---|---|
| Devices | < 10 | 10–100 | 100+ |
| Sites | 1 | 1–3 | Multi-site |
| MQTT | Mosquitto | Mosquitto + bridge | EMQX cluster |
| Deploy | `docker compose up` | `docker compose -f dc.yml -f dc.multi.yml up` | `helm install nexus ./helm/nexus` |

---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Protocol | Modbus TCP | Most common in Penang manufacturing legacy equipment |
| Messaging | MQTT / Mosquitto | Lightweight, proven IIoT standard, QoS 1 |
| Backend | Python 3.13, FastAPI | Async, auto-generated OpenAPI docs, type-safe |
| Database | TimescaleDB (PostgreSQL) | SQL + time-series, 3.5× faster than InfluxDB at high cardinality, native JOINs for shifts/assets |
| Frontend | Svelte 5 + Vite | Compiles to vanilla JS, ~5× smaller bundle than React, SSE-native |
| Alerting | scikit-learn IsolationForest | Zero cloud dependency, explainable, works fully offline |
| Orchestration | Docker Compose → Helm | Single command at every scale tier |
| CI/CD | GitHub Actions | Automated lint + test + build on every push |
| Topic naming | ISA-95 hierarchy | Industry standard: `{site}/{line}/{asset}/{signal}` |

---

## Screenshots

> Run `docker compose up --build` and open `http://localhost:8000` to see these live.

| Floor Overview | Alert Inbox | KPI Dashboard |
|---|---|---|
| ![Floor Overview](docs/screenshots/floor-overview.png) | ![Alerts](docs/screenshots/alerts.png) | ![KPIs](docs/screenshots/kpis.png) |

| Grafana Operator View | Asset Detail |
|---|---|
| ![Grafana](docs/screenshots/grafana-overview.png) | ![Asset Detail](docs/screenshots/asset-detail.png) |

*(Screenshots taken from a local demo run — `docker compose up --build`)*

---

## Quick Start

```bash
# 1. Clone and configure
git clone https://github.com/SaladinIART/IIoT-Telemetry-Stack.git nexus-iiot-platform
cd nexus-iiot-platform
cp .env.example .env        # review and adjust passwords

# 2. Start the full stack
docker compose up --build

# 3. Open dashboards
#    Grafana operator dashboard  →  http://localhost:3000   (admin / change_me_now)
#    NEXUS web app               →  http://localhost:8000   (available from Phase 4)
#    API docs (Swagger)          →  http://localhost:8000/docs
```

Verify data is flowing:

```bash
docker compose exec timescaledb psql -U iiot -d iiot \
  -c "SELECT asset, signal, value, ts FROM telemetry ORDER BY ts DESC LIMIT 10;"
```

---

## Project Structure

```
nexus-iiot-platform/
├── contracts/              JSON schemas + MQTT topic contract
├── db/migrations/          TimescaleDB schema (hypertables, views, alerts)
├── docs/
│   ├── architecture.md     Full system diagram and data flow
│   ├── adr/                Architecture Decision Records (why each tech was chosen)
│   └── runbooks/           Step-by-step operational guides
├── frontend/               Svelte 5 app (Phase 4)
├── helm/nexus/             Kubernetes Helm charts (Phase 8)
├── infra/
│   ├── grafana/            Provisioned datasource + dashboards
│   └── mosquitto/          Broker config + ACL
├── services/
│   ├── alerting/           3-layer alert engine (Phase 2)
│   ├── api/                FastAPI REST + SSE service (Phase 3)
│   ├── collector/          Modbus → MQTT
│   └── ingestor/           MQTT → TimescaleDB
├── sim/modbus_sim/         4-asset Modbus TCP simulator
├── src/iiot_stack/         Shared Python library
├── tests/                  Unit + integration tests
├── docker-compose.yml      Tier 1 — single host
├── docker-compose.multi.yml  Tier 2 — multi-site (Phase 6)
├── PROGRESS.md             Build checklist
└── pyproject.toml
```

---

## Development

```bash
python -m venv .venv
.venv\Scripts\Activate.ps1          # Windows
source .venv/bin/activate            # Linux/macOS
pip install -e ".[dev]"

pytest tests/unit                    # fast unit tests
pytest tests/integration -m integration  # requires Docker
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | Full system diagram, data flow, component responsibilities |
| [ADR-001 TimescaleDB](docs/adr/001-timescaledb-over-influxdb.md) | Why TimescaleDB over InfluxDB |
| [ADR-002 FastAPI + Svelte](docs/adr/002-fastapi-svelte-frontend.md) | Why FastAPI + Svelte |
| [ADR-003 Alert design](docs/adr/003-alert-three-layer.md) | 3-layer alert architecture |
| [ADR-004 MQTT topics](docs/adr/004-isa95-topic-hierarchy.md) | ISA-95 topic naming convention |
| [Quickstart runbook](docs/runbooks/01-quickstart.md) | Zero to running stack |
| [Add a new asset](docs/runbooks/02-adding-new-asset.md) | Extend to new equipment |
| [Tune alerts](docs/runbooks/03-alert-tuning.md) | Threshold and ML configuration |
| [Scale to Tier 2](docs/runbooks/04-scaling-to-tier2.md) | Multi-site Docker Compose |
| [Scale to Tier 3](docs/runbooks/05-scaling-to-tier3.md) | Kubernetes + EMQX |
| [API Reference](docs/api-reference.md) | All REST + SSE endpoints |
| [Data Model](docs/data-model.md) | All tables, views, indexes, and useful queries |

---

## Build Progress

See [PROGRESS.md](PROGRESS.md) for the current build checklist.

---

## Background

Built during a career transition period (Sept 2025 – Apr 2026) as a practical extension of real IIoT work done at Alumac Industrience — a power monitoring system across 17 factory locations. This project does the same thing, properly: with Docker, CI/CD, structured contracts, and a real user interface.

The goal is not just a working demo. It is a system that a plant engineer at Bosch, Siemens, or Schneider Electric could actually use.

---

*Built by [Muhamad Solehuddin](https://www.linkedin.com/in/solehuddin-muhamad-b67068132/) — Salbotics Solutions, Penang*
