CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE IF NOT EXISTS telemetry (
  ts TIMESTAMPTZ NOT NULL,
  site TEXT NOT NULL,
  line_name TEXT NOT NULL,
  asset TEXT NOT NULL,
  signal TEXT NOT NULL,
  value DOUBLE PRECISION NULL,
  quality TEXT NOT NULL,
  seq BIGINT NOT NULL,
  PRIMARY KEY (ts, site, line_name, asset, signal, seq)
);

SELECT create_hypertable('telemetry', 'ts', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS telemetry_asset_time_idx
ON telemetry (asset, ts DESC);

CREATE OR REPLACE VIEW telemetry_latest AS
SELECT DISTINCT ON (asset, signal)
  ts,
  site,
  line_name,
  asset,
  signal,
  value,
  quality,
  seq
FROM telemetry
ORDER BY asset, signal, ts DESC;

SELECT add_retention_policy('telemetry', INTERVAL '90 days', if_not_exists => TRUE);

ALTER TABLE telemetry SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'asset,signal'
);

SELECT add_compression_policy('telemetry', INTERVAL '7 days', if_not_exists => TRUE);
