CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE IF NOT EXISTS telemetry (
  ts TIMESTAMPTZ NOT NULL,
  source_ts TIMESTAMPTZ NOT NULL,
  site TEXT NOT NULL,
  line_name TEXT NOT NULL,
  asset TEXT NOT NULL,
  signal TEXT NOT NULL,
  value DOUBLE PRECISION NULL,
  quality TEXT NOT NULL,
  state TEXT NOT NULL,
  fault_code INTEGER NOT NULL DEFAULT 0,
  reason_code TEXT NULL,
  seq BIGINT NOT NULL,
  PRIMARY KEY (ts, asset, signal, seq)
);

SELECT create_hypertable('telemetry', 'ts', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS telemetry_asset_time_idx
ON telemetry (asset, ts DESC);

CREATE TABLE IF NOT EXISTS events (
  ts TIMESTAMPTZ NOT NULL,
  source_ts TIMESTAMPTZ NOT NULL,
  site TEXT NOT NULL,
  line_name TEXT NOT NULL,
  asset TEXT NOT NULL,
  event_type TEXT NOT NULL,
  state TEXT NOT NULL,
  fault_code INTEGER NOT NULL DEFAULT 0,
  severity TEXT NOT NULL,
  message TEXT NOT NULL,
  reason_code TEXT NULL,
  seq BIGINT NOT NULL,
  PRIMARY KEY (ts, asset, event_type, seq)
);

SELECT create_hypertable('events', 'ts', if_not_exists => TRUE);

CREATE TABLE IF NOT EXISTS asset_metadata (
  asset TEXT PRIMARY KEY,
  site TEXT NOT NULL,
  line_name TEXT NOT NULL,
  cell_name TEXT NOT NULL,
  asset_type TEXT NOT NULL,
  display_name TEXT NOT NULL
);

INSERT INTO asset_metadata (asset, site, line_name, cell_name, asset_type, display_name)
VALUES
  ('feeder-01', 'demo-site', 'packaging-line-1', 'cell-a', 'feeder', 'Raw Material Feeder'),
  ('mixer-01', 'demo-site', 'packaging-line-1', 'cell-a', 'mixer', 'Blend Mixer'),
  ('conveyor-01', 'demo-site', 'packaging-line-1', 'cell-b', 'conveyor', 'Transfer Conveyor'),
  ('packer-01', 'demo-site', 'packaging-line-1', 'cell-b', 'packer', 'Final Packer')
ON CONFLICT (asset) DO NOTHING;

CREATE OR REPLACE VIEW telemetry_latest AS
SELECT DISTINCT ON (asset, signal)
  ts,
  source_ts,
  site,
  line_name,
  asset,
  signal,
  value,
  quality,
  state,
  fault_code,
  reason_code,
  seq
FROM telemetry
ORDER BY asset, signal, ts DESC;

CREATE OR REPLACE VIEW asset_status AS
SELECT DISTINCT ON (asset)
  asset,
  site,
  line_name,
  state,
  fault_code,
  quality,
  reason_code,
  ts
FROM telemetry
WHERE signal = 'state_code'
ORDER BY asset, ts DESC;

CREATE OR REPLACE VIEW production_kpis AS
SELECT
  asset,
  MAX(CASE WHEN signal IN ('produced_count', 'batch_count', 'items_transferred', 'packed_count') THEN value END) AS total_output,
  MAX(CASE WHEN state = 'FAULTED' THEN ts END) AS last_fault_ts,
  COUNT(*) FILTER (WHERE quality = 'bad') AS bad_quality_points
FROM telemetry
GROUP BY asset;

SELECT add_retention_policy('telemetry', INTERVAL '90 days', if_not_exists => TRUE);
SELECT add_retention_policy('events', INTERVAL '180 days', if_not_exists => TRUE);

ALTER TABLE telemetry SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'asset,signal'
);

SELECT add_compression_policy('telemetry', INTERVAL '7 days', if_not_exists => TRUE);

ALTER TABLE events SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'asset,event_type'
);

SELECT add_compression_policy('events', INTERVAL '14 days', if_not_exists => TRUE);
