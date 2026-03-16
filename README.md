# IIoT Telemetry Stack

This project implements a simulator-first Industrial IIoT telemetry pipeline:

`Modbus simulator -> Python collector -> MQTT broker -> Python ingestor -> TimescaleDB -> Grafana`

It is designed as a portfolio-grade demo with reproducible infrastructure, versioned contracts, baseline security defaults, and a lightweight in-repo agentic AI scaffold.

## What is included

- Deterministic Modbus TCP simulator serving demo telemetry.
- Python collector with retry/backoff, sequence IDs, quality states, and structured logs.
- MQTT contract and JSON payload schema for versioned telemetry.
- Python ingestor that validates telemetry and batches writes to TimescaleDB.
- Docker Compose stack for Mosquitto, TimescaleDB, Grafana, simulator, collector, and ingestor.
- Provisioned Grafana datasource and dashboard.
- SQL migrations that create the telemetry hypertable and retention/compression policies.
- Unit tests plus an integration smoke test for the compose stack.
- `agentic/` scaffold documenting planner-worker-verifier prompts and safe tool boundaries.

## Quick start

1. Create a virtual environment and install dependencies.

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
```

2. Copy the environment defaults if you want a local `.env`.

```powershell
Copy-Item .env.example .env
```

3. Start the full stack.

```powershell
docker compose up --build
```

4. Open Grafana at [http://localhost:3000](http://localhost:3000) with:

- User: `admin`
- Password: `change_me_now`

5. Verify data flow:

```powershell
docker compose exec timescaledb psql -U iiot -d iiot -c "SELECT * FROM telemetry ORDER BY ts DESC LIMIT 5;"
```

## Testing

```powershell
pytest tests/unit
pytest tests/integration -m integration
```

The integration test expects a reachable Docker daemon because it starts the compose stack and checks telemetry flow.

## GitHub setup

If `gh` is available later:

```powershell
git init
git branch -M main
git add .
git commit -m "Initial IIoT telemetry stack"
gh repo create mqtt-simulation --private --source . --remote origin --push
```

If `gh` is unavailable, create the private repository in GitHub and then run:

```powershell
git init
git branch -M main
git add .
git commit -m "Initial IIoT telemetry stack"
git remote add origin https://github.com/<your-user>/mqtt-simulation.git
git push -u origin main
```
