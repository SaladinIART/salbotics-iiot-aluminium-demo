# MQTT Topic Contract

- Telemetry topics use `iiot/v1/<site>/<line>/<asset>/<signal>`.
- Status topics use `iiot/v1/<site>/<line>/<asset>/status`.
- Telemetry messages are JSON and must satisfy `telemetry_payload.schema.json`.
- QoS defaults:
  - Telemetry: QoS 1
  - Status: QoS 1, retained
- Payload timestamps use epoch milliseconds in UTC.
- `seq` is monotonic per collector process and can be used for deduplication.
