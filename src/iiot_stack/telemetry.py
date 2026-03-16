from __future__ import annotations

import json
import struct
import time
from typing import Any

from jsonschema import Draft202012Validator

from iiot_stack.contracts import load_payload_schema


validator = Draft202012Validator(load_payload_schema())


def build_topic(site: str, line: str, asset: str, signal: str) -> str:
    return f"iiot/v1/{site}/{line}/{asset}/{signal}"


def parse_topic(topic: str) -> tuple[str, str, str, str]:
    parts = topic.split("/")
    if len(parts) != 6 or parts[0] != "iiot" or parts[1] != "v1":
        raise ValueError(f"invalid topic: {topic}")
    return parts[2], parts[3], parts[4], parts[5]


def decode_words(words: list[int], datatype: str, endianness: str) -> float:
    if datatype == "uint32":
        if len(words) != 2:
            raise ValueError("uint32 decoding requires two words")
        if endianness != "big":
            raise ValueError("only big-endian uint32 is supported in this demo")
        return float((words[0] << 16) | words[1])
    if datatype == "float32":
        if len(words) != 2:
            raise ValueError("float32 decoding requires two words")
        if endianness != "big":
            raise ValueError("only big-endian float32 is supported in this demo")
        packed = struct.pack(">HH", words[0], words[1])
        return float(struct.unpack(">f", packed)[0])
    raise ValueError(f"unsupported datatype: {datatype}")


def apply_scaling(value: float, scale: float, offset: float) -> float:
    return value * scale + offset


def build_payload(
    asset: str,
    signal: str,
    value: float,
    quality: str,
    seq: int,
    unit: str | None = None,
    ts: int | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "v": 1,
        "ts": int(ts if ts is not None else time.time() * 1000),
        "asset": asset,
        "signal": signal,
        "value": value,
        "quality": quality,
        "seq": seq,
    }
    if unit is not None:
        payload["unit"] = unit
    validate_payload(payload)
    return payload


def validate_payload(payload: dict[str, Any]) -> None:
    validator.validate(payload)


def payload_bytes(payload: dict[str, Any]) -> bytes:
    return json.dumps(payload, separators=(",", ":")).encode("utf-8")
