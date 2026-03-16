from __future__ import annotations

import json
import struct

import pytest

from iiot_stack.telemetry import (
    apply_scaling,
    build_event_payload,
    build_event_topic,
    build_payload,
    build_telemetry_topic,
    decode_words,
    parse_event_topic,
    parse_telemetry_topic,
    validate_event_payload,
    validate_payload,
)


def test_build_topic_and_parse_topic_round_trip() -> None:
    topic = build_telemetry_topic("site-a", "line-1", "asset-1", "energy_kwh")
    assert topic == "iiot/v1/telemetry/site-a/line-1/asset-1/energy_kwh"
    assert parse_telemetry_topic(topic) == ("site-a", "line-1", "asset-1", "energy_kwh")


def test_parse_topic_rejects_invalid_shape() -> None:
    with pytest.raises(ValueError):
        parse_telemetry_topic("bad/topic")


def test_event_topic_round_trip() -> None:
    topic = build_event_topic("site-a", "line-1", "asset-1", "alarm_raised")
    assert topic == "iiot/v1/events/site-a/line-1/asset-1/alarm_raised"
    assert parse_event_topic(topic) == ("site-a", "line-1", "asset-1", "alarm_raised")


def test_decode_uint32_words() -> None:
    assert decode_words([0x0001, 0x86A0], "uint32", "big") == 100000.0


def test_decode_uint16_words() -> None:
    assert decode_words([0x0003], "uint16", "big") == 3.0


def test_decode_float32_words() -> None:
    words = list(struct.unpack(">HH", struct.pack(">f", 22.5)))
    assert decode_words(words, "float32", "big") == pytest.approx(22.5)


def test_apply_scaling() -> None:
    assert apply_scaling(100000.0, 0.01, 0.0) == 1000.0


def test_build_payload_matches_schema() -> None:
    payload = build_payload(
        "asset-1",
        "temperature_c",
        22.5,
        "good",
        7,
        state="RUNNING",
        fault_code=0,
        unit="degC",
        limits={"warn_low": 10.0, "warn_high": 80.0},
        ts=1730000000000,
    )
    validate_payload(payload)
    assert payload["unit"] == "degC"
    assert payload["state"] == "RUNNING"
    assert json.loads(json.dumps(payload))["signal"] == "temperature_c"


def test_build_payload_rejects_invalid_quality() -> None:
    with pytest.raises(Exception):
        build_payload("asset-1", "temperature_c", 22.5, "unknown", 7, state="RUNNING", fault_code=0)


def test_build_event_payload_matches_schema() -> None:
    payload = build_event_payload(
        asset="asset-1",
        event_type="alarm_raised",
        state="FAULTED",
        fault_code=301,
        severity="critical",
        message="Conveyor jam detected",
        seq=8,
        reason_code="JAM_DETECTED",
        ts=1730000000000,
    )
    validate_event_payload(payload)
    assert payload["fault_code"] == 301
