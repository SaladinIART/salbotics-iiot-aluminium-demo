# Runbook 04 — Scaling to Tier 2 (Multi-Site)

## When to use this runbook

You have more than one physical site (factory, building, or production line cluster) and want all telemetry flowing into a single TimescaleDB instance with site-level filtering in Grafana and the API.

**Tier 1** (single site, Mosquitto) → **Tier 2** (multi-site, EMQX, one collector per site)

No code changes are required. The MQTT topic schema (`iiot/v1/telemetry/{site}/{line}/{asset}/{signal}`) and the TimescaleDB schema (`site` column on all tables) are multi-site from day one.

---

## Architecture change

```
Tier 1                         Tier 2
──────────────────────         ──────────────────────────────────────
Mosquitto (single broker)  →   EMQX (clusterable, multi-protocol)
1× collector               →   N× collectors (one per site/network)
1× ingestor                →   N× ingestors  (or 1 shared)
TimescaleDB (site column)       TimescaleDB (unchanged — already multi-site)
```

---

## Prerequisites

- Tier 1 stack is already running and healthy (`docker compose up`)
- Docker Engine ≥ 24, Docker Compose ≥ 2.22
- Port 1503 available on the host (second Modbus simulator)
- Port 18083 available (EMQX dashboard)

---

## Step 1 — Switch from Mosquitto to EMQX

The `docker-compose.multi.yml` overlay replaces Mosquitto with EMQX.

1. Stop the running stack:
   ```bash
   docker compose down
   ```

2. In `docker-compose.yml`, comment out the `mosquitto` service block:
   ```yaml
   # mosquitto:
   #   image: eclipse-mosquitto:2
   #   ...
   ```

3. Start the combined stack:
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.multi.yml up --build -d
   ```

4. Verify EMQX is healthy:
   ```bash
   docker exec iiot-emqx emqx ping
   # Expected: pong
   ```

5. Open the EMQX dashboard at `http://localhost:18083` (default credentials: `admin` / `public`).

---

## Step 2 — Verify site-b data is flowing

After the stack starts, the `seed_site_b` container inserts the `site-b` row into `sites` and exits. Confirm:

```bash
docker exec iiot-timescaledb \
  psql -U iiot -d iiot -c "SELECT site_id, display_name FROM sites;"
```

Expected output:
```
  site_id  |    display_name
-----------+--------------------
 demo-site | Demo Site (Penang)
 site-b    | Site B (Penang)
```

Wait ~30 seconds for the first telemetry to arrive, then:

```bash
docker exec iiot-timescaledb \
  psql -U iiot -d iiot -c "SELECT DISTINCT site FROM telemetry ORDER BY site;"
```

Expected:
```
   site
-----------
 demo-site
 site-b
```

---

## Step 3 — Switch Grafana dashboard to site-b

1. Open Grafana at `http://localhost:3000`
2. Navigate to **Production KPIs** dashboard
3. Use the **Site** variable dropdown (top-left) to switch between `demo-site` and `site-b`

The dashboard queries `v_kpi_summary WHERE site = '$site'` — all panels update automatically.

---

## Step 4 — Add a third site

Copy the `site_b` blocks in `docker-compose.multi.yml` and change:

| Variable | New value |
|----------|-----------|
| `SITE` | `site-c` |
| `LINE` | your line name |
| `MQTT_CLIENT_ID_PREFIX` | `iiot-site-c` |
| container names | `iiot-modbus-sim-c`, `iiot-collector-site-c`, etc. |
| host port for Modbus | `1504:1502` |

Then seed the new site:
```bash
docker exec iiot-timescaledb \
  psql -U iiot -d iiot -c \
  "INSERT INTO sites (site_id, display_name, location, timezone)
   VALUES ('site-c', 'Site C', 'Penang, Malaysia', 'Asia/Kuala_Lumpur')
   ON CONFLICT DO NOTHING;"
```

No other changes needed. The API, alerting service, and Grafana all pick up the new site automatically.

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| `site-b` data missing from DB | `docker logs iiot-ingestor-site-b` — look for connection errors |
| EMQX not accepting connections | `docker logs iiot-emqx` — check port conflicts with Mosquitto |
| `seed_site_b` exits non-zero | `docker logs iiot-seed-site-b` — DB may not be ready yet; re-run manually |
| Grafana Site dropdown shows only `demo-site` | Refresh the variable (dashboard settings → Variables → site → Refresh) |

---

## Rollback to Tier 1

```bash
docker compose -f docker-compose.yml -f docker-compose.multi.yml down
# Re-enable mosquitto in docker-compose.yml
docker compose up -d
```

TimescaleDB data is preserved — `site-b` rows remain but no new data will arrive for that site.
