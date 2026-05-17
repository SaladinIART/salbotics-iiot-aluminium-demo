# NEXUS Architecture — Visual Reference

> Three diagrams, each designed to be understood in 30 seconds.
> GitHub renders these natively — no external tool needed.

---

## Diagram 1 — Data Flow

*Factory floor on the left, decision dashboards on the right. Follow the arrows to trace one temperature reading from sensor register to Grafana tile.*

```mermaid
flowchart LR
    subgraph OT["🏭  OT Layer (Shop Floor)"]
        SIM["Modbus TCP Simulator\n7 stations\nport :1502"]
    end

    subgraph EDGE["📡  Edge / Collection"]
        COL["Collector Service\nPolls Modbus every 1 s\nPublishes to MQTT"]
    end

    subgraph MSG["📨  Messaging"]
        MQ["Eclipse Mosquitto\nMQTT broker\nport :1883\nISA-95 topic hierarchy\nACL auth"]
    end

    subgraph PROC["⚙️  Processing (parallel)"]
        ING["Ingestor\nSchema validate\nBatch write → DB"]
        ALT["Alerting Engine\nThreshold → Z-score → ML\nIsolationForest"]
    end

    subgraph STORE["🗄️  Storage"]
        DB["TimescaleDB\nPostgreSQL + hypertables\nport :5432\ntelemetry · alerts · KPIs"]
    end

    subgraph API["🔌  API"]
        FA["FastAPI\nREST + SSE\nport :8080\nX-API-Key auth"]
    end

    subgraph UI["🖥️  Dashboards"]
        SVL["NEXUS Web App\nSvelte 5\nlocalhost:8080"]
        GRF["Grafana\nDecision Board\nlocalhost:3000"]
    end

    SIM -->|"Modbus TCP registers"| COL
    COL -->|"MQTT publish\niiot/v1/telemetry/..."| MQ
    MQ -->|"MQTT subscribe"| ING
    MQ -->|"MQTT subscribe"| ALT
    ING -->|"batch INSERT"| DB
    ALT -->|"INSERT alerts"| DB
    DB -->|"SQL queries"| FA
    DB -->|"direct datasource"| GRF
    FA -->|"REST JSON\nSSE stream"| SVL

    style OT fill:#f5f5f5,stroke:#999
    style EDGE fill:#e8f4fd,stroke:#5b9bd5
    style MSG fill:#e8f4fd,stroke:#5b9bd5
    style PROC fill:#fff3e0,stroke:#f0a500
    style STORE fill:#e8f5e9,stroke:#4caf50
    style API fill:#fce4ec,stroke:#e91e63
    style UI fill:#f3e5f5,stroke:#9c27b0
```

---

## Diagram 2 — ISA-95 MQTT Topic Hierarchy

*Every message in the system has a structured topic address — like a postal code for factory data. This is the ISA-95 standard. It makes multi-site aggregation, security ACLs, and data routing trivial.*

```mermaid
flowchart TD
    ROOT["iiot/v1/"]

    ROOT --> TEL["telemetry/"]
    ROOT --> EVT["events/"]
    ROOT --> CMD["commands/"]

    TEL --> SITE["site: demo-site/"]
    SITE --> LINE["line: aluminium-profile-line-1/"]
    LINE --> A1["asset: furnace-01/"]
    LINE --> A2["asset: press-01/"]
    LINE --> A3["asset: quench-01/"]
    LINE --> ADOT["... (7 assets total)"]

    A1 --> S1["signal: billet_temp\n→ value: 485.2°C"]
    A1 --> S2["signal: state_code\n→ value: 2 (RUNNING)"]
    A3 --> S3["signal: flow_rate\n→ value: 18.4 L/min"]
    A3 --> S4["signal: exit_temp\n→ value: 52.1°C"]

    style ROOT fill:#e3f2fd,stroke:#1565c0
    style TEL fill:#e8f5e9,stroke:#2e7d32
    style EVT fill:#fff8e1,stroke:#f57f17
    style CMD fill:#fce4ec,stroke:#c62828
```

> **Why this matters:** A subscriber can listen to `iiot/v1/telemetry/#` to get all data, or `iiot/v1/telemetry/site-b/+/quench-01/#` to watch only quench stations on one site. No code change — MQTT topic wildcards handle the filtering.

---

## Diagram 3 — Container Topology

*Eight Docker containers orchestrated by Docker Compose. Arrows show who calls whom. Numbers are the host-side ports you open in a browser or connect to.*

```mermaid
flowchart TB
    subgraph DOCKER["Docker Compose — single host (Tier 1)"]
        direction TB

        subgraph SIM_BOX["Simulator"]
            SIM["modbus_sim\n:1502 Modbus TCP\n:5001 Scenario API"]
        end

        subgraph BROKER["Broker"]
            MQ["mosquitto\n:1883 MQTT"]
        end

        subgraph SVCS["Services"]
            COL["collector\n(no port — internal)"]
            ING["ingestor\n(no port — internal)"]
            ALT["alerting\n(no port — internal)"]
            API["api\n:8080 → :8000"]
        end

        subgraph DATA["Data"]
            DB["timescaledb\n:5432"]
        end

        subgraph VIZ["Visualisation"]
            GRF["grafana\n:3000"]
        end
    end

    YOU["You (browser / scripts)"]

    YOU -->|"http://localhost:8080"| API
    YOU -->|"http://localhost:3000"| GRF
    YOU -->|"POST :5001/scenario"| SIM

    SIM -->|"Modbus TCP :1502"| COL
    COL -->|"MQTT publish :1883"| MQ
    MQ -->|"MQTT subscribe"| ING
    MQ -->|"MQTT subscribe"| ALT
    ING -->|"SQL :5432"| DB
    ALT -->|"SQL :5432"| DB
    API -->|"SQL :5432"| DB
    GRF -->|"SQL :5432"| DB
    API -->|"serves compiled Svelte"| YOU

    style YOU fill:#f3e5f5,stroke:#9c27b0,color:#000
    style DOCKER fill:#fafafa,stroke:#bbb
    style SIM_BOX fill:#e8f4fd,stroke:#5b9bd5
    style BROKER fill:#e8f4fd,stroke:#5b9bd5
    style SVCS fill:#fff3e0,stroke:#f0a500
    style DATA fill:#e8f5e9,stroke:#4caf50
    style VIZ fill:#fce4ec,stroke:#e91e63
```

### Port reference

| Port | Service | What you do with it |
|---|---|---|
| **3000** | Grafana | Open in browser → decision board |
| **8080** | NEXUS web app + FastAPI | Open in browser → ops UI; also Swagger at `/docs` |
| **5001** | Scenario API | `.bat` scripts POST to this to inject faults |
| **1502** | Modbus TCP | Collector reads from this (internal, not user-facing) |
| **1883** | MQTT / Mosquitto | Internal messaging (subscribe with MQTT Explorer to debug) |
| **5432** | TimescaleDB | Connect with DBeaver/psql for DB inspection (`iiot`/`iiot_password_change_me`) |

---

*For the full text-based architecture description: [`../architecture.md`](../architecture.md)*
*For technology choice rationale: [`../adr/`](../adr/)*
