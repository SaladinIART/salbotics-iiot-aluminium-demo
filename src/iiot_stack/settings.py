from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class AlertingSettings:
    mqtt_host: str = os.getenv("MQTT_HOST", "127.0.0.1")
    mqtt_port: int = int(os.getenv("MQTT_PORT", "1883"))
    mqtt_user: str = os.getenv("MQTT_USER", "iiot")
    mqtt_password: str = os.getenv("MQTT_PASSWORD", "demo_password")
    mqtt_client_id_prefix: str = os.getenv("MQTT_CLIENT_ID_PREFIX", "iiot-demo")
    pg_host: str = os.getenv("PGHOST", "127.0.0.1")
    pg_port: int = int(os.getenv("PGPORT", "5432"))
    pg_database: str = os.getenv("PGDATABASE", "iiot")
    pg_user: str = os.getenv("PGUSER", "iiot")
    pg_password: str = os.getenv("PGPASSWORD", "iiot_password_change_me")
    dedup_window_sec: float = float(os.getenv("ALERT_DEDUP_WINDOW_SEC", "300"))
    webhook_url: str = os.getenv("ALERT_WEBHOOK_URL", "")
    ml_anomaly_threshold: float = float(os.getenv("ML_ANOMALY_THRESHOLD", "-0.1"))
    ml_min_samples: int = int(os.getenv("ML_MIN_SAMPLES", "50"))
    ml_refit_every: int = int(os.getenv("ML_REFIT_EVERY", "500"))
    stat_zscore_threshold: float = float(os.getenv("STAT_ZSCORE_THRESHOLD", "3.0"))
    stat_window_size: int = int(os.getenv("STAT_WINDOW_SIZE", "100"))

    @property
    def dsn(self) -> str:
        return (
            f"host={self.pg_host} port={self.pg_port} dbname={self.pg_database} "
            f"user={self.pg_user} password={self.pg_password}"
        )


@dataclass(frozen=True)
class APISettings:
    pg_host: str = os.getenv("PGHOST", "127.0.0.1")
    pg_port: int = int(os.getenv("PGPORT", "5432"))
    pg_database: str = os.getenv("PGDATABASE", "iiot")
    pg_user: str = os.getenv("PGUSER", "iiot")
    pg_password: str = os.getenv("PGPASSWORD", "iiot_password_change_me")
    api_key: str = os.getenv("API_KEY", "nexus-dev-key-change-me")
    api_host: str = os.getenv("API_HOST", "0.0.0.0")
    api_port: int = int(os.getenv("API_PORT", "8000"))
    cors_origins: list[str] = None  # type: ignore[assignment]

    def __post_init__(self) -> None:
        raw = os.getenv("CORS_ORIGINS", "http://localhost:5173,http://localhost:8000")
        object.__setattr__(self, "cors_origins", [o.strip() for o in raw.split(",")])

    @property
    def dsn(self) -> str:
        return (
            f"host={self.pg_host} port={self.pg_port} dbname={self.pg_database} "
            f"user={self.pg_user} password={self.pg_password}"
        )


@dataclass(frozen=True)
class CollectorSettings:
    site: str = os.getenv("SITE", "demo-site")
    line: str = os.getenv("LINE", "packaging-line-1")
    modbus_host: str = os.getenv("MODBUS_HOST", "127.0.0.1")
    modbus_port: int = int(os.getenv("MODBUS_PORT", "1502"))
    mqtt_host: str = os.getenv("MQTT_HOST", "127.0.0.1")
    mqtt_port: int = int(os.getenv("MQTT_PORT", "1883"))
    mqtt_user: str = os.getenv("MQTT_USER", "iiot")
    mqtt_password: str = os.getenv("MQTT_PASSWORD", "demo_password")
    mqtt_client_id_prefix: str = os.getenv("MQTT_CLIENT_ID_PREFIX", "iiot-demo")
    default_poll_interval_ms: int = int(os.getenv("COLLECT_INTERVAL_MS", "1000"))


@dataclass(frozen=True)
class IngestorSettings:
    mqtt_host: str = os.getenv("MQTT_HOST", "127.0.0.1")
    mqtt_port: int = int(os.getenv("MQTT_PORT", "1883"))
    mqtt_user: str = os.getenv("MQTT_USER", "iiot")
    mqtt_password: str = os.getenv("MQTT_PASSWORD", "demo_password")
    pg_host: str = os.getenv("PGHOST", "127.0.0.1")
    pg_port: int = int(os.getenv("PGPORT", "5432"))
    pg_database: str = os.getenv("PGDATABASE", "iiot")
    pg_user: str = os.getenv("PGUSER", "iiot")
    pg_password: str = os.getenv("PGPASSWORD", "iiot_password_change_me")

    @property
    def dsn(self) -> str:
        return (
            f"host={self.pg_host} port={self.pg_port} dbname={self.pg_database} "
            f"user={self.pg_user} password={self.pg_password}"
        )
