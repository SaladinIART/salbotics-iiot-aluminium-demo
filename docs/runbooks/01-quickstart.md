# Runbook 01 — Quick Start (Zero to Running Stack)

**Time required:** ~15 minutes
**Prerequisites:** Docker Engine ≥ 24, Docker Compose ≥ 2.22, Git, 4 GB RAM free

---

## 1. Clone and configure

```bash
git clone https://github.com/SaladinIART/salbotics-iiot-aluminium-demo.git
cd salbotics-iiot-aluminium-demo
cp .env.example .env
```

The default `.env` values work out of the box for a local demo. You only need to change them for production.

| Variable | Default | Change for production |
|----------|---------|----------------------|
| `POSTGRES_PASSWORD` | `iiot_password_change_me` | ✅ Yes |
| `API_KEY` | `nexus-dev-key-change-me` | ✅ Yes |
| `GRAFANA_ADMIN_PASSWORD` | `change_me_now` | ✅ Yes |
| `MQTT_PASSWORD` | `demo_password` | ✅ Yes |

---

## 2. Start the stack

```bash
docker compose up --build -d
```

This starts 8 services in dependency order:

| Service | Starts after | Ready when |
|---------|-------------|-----------|
| `mosquitto` | — | Port 1883 open |
| `timescaledb` | — | Migrations applied automatically |
| `modbus_sim` | — | Port 1502 open |
| `collector` | mosquitto, modbus_sim | First MQTT publish appears in logs |
| `ingestor` | mosquitto, timescaledb | First DB write appears in logs |
| `alerting` | mosquitto, timescaledb | "alerting service started" in logs |
| `api` | timescaledb | `/health` returns `{"status":"ok"}` |
| `grafana` | timescaledb | Port 3000 responds |

Wait ~30 seconds for all services to be healthy, then:

```bash
docker compose ps
```

All services should show `running` or `healthy`.

---

## 3. Verify data is flowing

```bash
# Check telemetry is being written
docker exec iiot-timescaledb \
  psql -U iiot -d iiot -c \
  "SELECT asset, signal, value, ts FROM telemetry ORDER BY ts DESC LIMIT 5;"
```

You should see rows like:
```
    asset    |  signal   | value  |             ts
-------------+-----------+--------+----------------------------
 quench-01   | quench_flow_lpm      | 221.8 | 2026-04-24 13:40:01+00
 quench-01   | exit_temp_c          |  57.2 | 2026-04-24 13:40:01+00
 press-01    | ram_force_kn         | 1958.4 | 2026-04-24 13:40:00+00
```

---

## 4. Open the interfaces

| Interface | URL | Credentials |
|-----------|-----|-------------|
| NEXUS Web App | http://localhost:8080 | API Key in Admin page |
| Swagger API Docs | http://localhost:8080/docs | — |
| Grafana | http://localhost:3000 | admin / change_me_now |

For the aluminium demo flow:

- open `http://localhost:8080/`
- navigate to **Executive View**
- open Grafana in a second tab and load **Aluminium Profile Decision Board**

### First API call

```bash
curl -s -H "X-API-Key: nexus-dev-key-change-me" \
  http://localhost:8080/api/v1/assets | python3 -m json.tool
```

Expected: JSON array of 7 aluminium stations (`furnace-01`, `press-01`, `quench-01`, `cooling-01`, `stretcher-01`, `saw-01`, `ageing-01`).

---

## 5. Trigger the flagship demo scenario

Use the demo scenario endpoint instead of inserting fake raw telemetry:

```bash
curl -s -X POST \
  -H "X-API-Key: nexus-dev-key-change-me" \
  http://localhost:8080/api/v1/demo/scenario/QUALITY_HOLD_QUENCH | python3 -m json.tool
```

Within ~10 seconds:

- the Svelte executive dashboard banner should turn `AMBER`
- Grafana should populate the decision board with the P2 quality-hold actions
- `quench-01` should show low flow and elevated exit temperature

Check the current scenario:

```bash
curl -s -H "X-API-Key: nexus-dev-key-change-me" \
  http://localhost:8080/api/v1/demo/scenario | python3 -m json.tool
```

---

## 6. Stop the stack

```bash
docker compose down          # stop, keep volumes (data preserved)
docker compose down -v       # stop and delete all volumes (clean slate)
```

---

## Troubleshooting

| Problem | Resolution |
|---------|-----------|
| `docker compose up` fails — port conflict | Check ports 1883, 5432, 3000, 8080 are free before retrying |
| `timescaledb` keeps restarting | Remove the Timescale volume for this compose project, then `docker compose up -d` again |
| No telemetry in DB after 60s | `docker logs iiot-collector` — check Modbus connection errors |
| API returns 401 | Ensure `X-API-Key` header matches `API_KEY` in `.env` |
| Grafana shows "No data" | Confirm datasource is named `iiot-timescaledb` in provisioning |
