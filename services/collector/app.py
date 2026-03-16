from __future__ import annotations

import logging
import time

import paho.mqtt.client as mqtt
from pymodbus.client import ModbusTcpClient

from iiot_stack.contracts import load_register_map
from iiot_stack.logging_utils import configure_logging
from iiot_stack.settings import CollectorSettings
from iiot_stack.telemetry import apply_scaling, build_payload, build_topic, decode_words, payload_bytes


LOG = logging.getLogger("collector")


def connect_mqtt(settings: CollectorSettings) -> mqtt.Client:
    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id=f"{settings.mqtt_client_id_prefix}-collector-{settings.asset}",
        protocol=mqtt.MQTTv311,
    )
    client.username_pw_set(settings.mqtt_user, settings.mqtt_password)
    client.connect(settings.mqtt_host, settings.mqtt_port, keepalive=30)
    client.loop_start()
    return client


def publish_status(client: mqtt.Client, settings: CollectorSettings, quality: str, seq: int) -> None:
    topic = build_topic(settings.site, settings.line, settings.asset, "status")
    payload = build_payload(settings.asset, "status", float(seq), quality, seq)
    client.publish(topic, payload=payload_bytes(payload), qos=1, retain=True)


def run() -> None:
    configure_logging()
    settings = CollectorSettings()
    register_map = load_register_map()["signals"]
    mqtt_client = connect_mqtt(settings)
    modbus_client = ModbusTcpClient(settings.modbus_host, port=settings.modbus_port, timeout=2.0)

    seq = 0
    backoff_seconds = 1.0
    poll_interval_seconds = settings.collect_interval_ms / 1000.0

    while True:
        try:
            if not modbus_client.connect():
                raise RuntimeError("modbus connect failed")

            for signal in register_map:
                result = modbus_client.read_holding_registers(
                    address=signal["address"],
                    count=signal["word_count"],
                    device_id=settings.modbus_unit_id,
                )
                if result.isError():
                    raise RuntimeError(f"modbus read error for {signal['tag_id']}: {result}")

                raw_value = decode_words(result.registers, signal["datatype"], signal["endianness"])
                scaled_value = apply_scaling(raw_value, signal["scale"], signal["offset"])
                topic = build_topic(settings.site, settings.line, settings.asset, signal["tag_id"])
                payload = build_payload(
                    settings.asset,
                    signal["tag_id"],
                    scaled_value,
                    "good",
                    seq,
                    unit=signal.get("unit"),
                )
                mqtt_client.publish(topic, payload=payload_bytes(payload), qos=1, retain=False)
                LOG.info(
                    "published telemetry",
                    extra={"event": {"signal": signal["tag_id"], "seq": seq, "value": scaled_value}},
                )
                seq += 1

            publish_status(mqtt_client, settings, "good", seq)
            backoff_seconds = 1.0
            time.sleep(poll_interval_seconds)
        except Exception as exc:
            LOG.warning(
                "collector cycle failed",
                extra={"event": {"error": str(exc), "backoff_seconds": backoff_seconds}},
            )
            publish_status(mqtt_client, settings, "bad", seq)
            time.sleep(backoff_seconds)
            backoff_seconds = min(backoff_seconds * 2, 30.0)


if __name__ == "__main__":
    run()
