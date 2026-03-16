# MQTT Topic Contract

- Telemetry topics use `iiot/v1/telemetry/<site>/<line>/<asset>/<signal>`.
- Event topics use `iiot/v1/events/<site>/<line>/<asset>/<event_type>`.
- Status topics use `iiot/v1/events/<site>/<line>/<asset>/status`.
- Telemetry messages are JSON and must satisfy `telemetry_payload.schema.json`.
- Event messages are JSON and must satisfy `event_payload.schema.json`.
- QoS defaults:
  - Telemetry: QoS 1
  - Events and status: QoS 1, retained
- Payload timestamps use epoch milliseconds in UTC.
- `seq` is monotonic per collector process and can be used for deduplication.
