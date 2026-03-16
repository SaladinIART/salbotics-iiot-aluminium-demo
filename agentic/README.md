# Agentic AI Scaffold

This repository includes a lightweight agentic AI scaffold rather than a live orchestration service.

## Intended workflow

1. Planner agent breaks work into dependency-ordered tasks.
2. Worker agents specialize by subsystem:
   - PLC and Modbus mapping
   - Collector implementation
   - MQTT contract stewardship
   - Timescale schema and ingestion
   - Grafana provisioning
   - Verification and failure injection
3. Verifier agent runs tests and feeds failures into a repair loop.
4. Human approval gates any write, migration, or deployment action.

## Safe tool policy

- `read_repo(path)`: safe
- `search_repo(query)`: safe
- `run_tests(cmd)`: safe
- `lint(cmd)`: safe
- `write_file(path, content)`: human approval required
- `apply_patch(diff)`: human approval required
- `run_migrations()`: human approval required
- `docker_compose_up()`: safe on dev, approval on shared or production hosts

## Evaluation hooks

The v1 scaffold leaves evaluation tooling as a documented extension point:

- prompt regression checks
- trace capture for agent runs
- task acceptance criteria review
- failure replay after prompt updates

See `prompts.md` for reusable system prompts.
