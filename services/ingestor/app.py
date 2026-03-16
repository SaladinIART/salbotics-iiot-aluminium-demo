from __future__ import annotations

import json
import logging
import time
from typing import Any

import paho.mqtt.client as mqtt
import psycopg

from iiot_stack.logging_utils import configure_logging
from iiot_stack.settings import IngestorSettings
from iiot_stack.telemetry import parse_topic, validate_payload


LOG = logging.getLogger("ingestor")
TOPIC_FILTER = "iiot/v1/+/+/+/+"
INSERT_SQL = """
INSERT INTO telemetry (ts, site, line_name, asset, signal, value, quality, seq)
VALUES (to_timestamp(%(ts)s / 1000.0), %(site)s, %(line)s, %(asset)s, %(signal)s, %(value)s, %(quality)s, %(seq)s)
ON CONFLICT DO NOTHING
"""


class Ingestor:
    def __init__(self, settings: IngestorSettings, max_batch: int = 200, max_delay_s: float = 1.0) -> None:
        self.settings = settings
        self.max_batch = max_batch
        self.max_delay_s = max_delay_s
        self.buffer: list[dict[str, Any]] = []
        self.last_flush = time.time()

    def on_message(self, _client: mqtt.Client, _userdata: Any, msg: mqtt.MQTTMessage) -> None:
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
            validate_payload(payload)
            site, line, asset, signal = parse_topic(msg.topic)
            self.buffer.append(
                {
                    "ts": int(payload["ts"]),
                    "site": site,
                    "line": line,
                    "asset": asset,
                    "signal": signal,
                    "value": float(payload["value"]),
                    "quality": str(payload["quality"]),
                    "seq": int(payload["seq"]),
                }
            )
        except Exception as exc:
            LOG.warning("dropping invalid message", extra={"event": {"topic": msg.topic, "error": str(exc)}})

    def flush_if_due(self, cur: psycopg.Cursor[Any]) -> None:
        if not self.buffer:
            return
        now = time.time()
        if len(self.buffer) < self.max_batch and (now - self.last_flush) < self.max_delay_s:
            return
        cur.executemany(INSERT_SQL, self.buffer)
        LOG.info("flushed telemetry batch", extra={"event": {"rows": len(self.buffer)}})
        self.buffer.clear()
        self.last_flush = now


def connect_mqtt(ingestor: Ingestor) -> mqtt.Client:
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="iiot-demo-ingestor", protocol=mqtt.MQTTv311)
    client.username_pw_set(ingestor.settings.mqtt_user, ingestor.settings.mqtt_password)
    client.on_message = ingestor.on_message
    client.connect(ingestor.settings.mqtt_host, ingestor.settings.mqtt_port, keepalive=30)
    client.subscribe(TOPIC_FILTER, qos=1)
    client.loop_start()
    return client


def run() -> None:
    configure_logging()
    settings = IngestorSettings()
    ingestor = Ingestor(settings=settings)

    while True:
        try:
            with psycopg.connect(settings.dsn) as conn:
                with conn.cursor() as cur:
                    mqtt_client = connect_mqtt(ingestor)
                    while True:
                        ingestor.flush_if_due(cur)
                        conn.commit()
                        time.sleep(0.2)
                    mqtt_client.loop_stop()
        except Exception as exc:
            LOG.warning("ingestor loop failed", extra={"event": {"error": str(exc)}})
            time.sleep(2.0)


if __name__ == "__main__":
    run()
