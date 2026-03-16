from __future__ import annotations

import os
from dataclasses import dataclass


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
