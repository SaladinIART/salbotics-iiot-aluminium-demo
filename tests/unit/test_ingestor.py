from __future__ import annotations

import json
from types import SimpleNamespace
from unittest.mock import Mock

from iiot_stack.settings import IngestorSettings
from services.ingestor.app import Ingestor


def make_message(topic: str, payload: dict[str, object]) -> SimpleNamespace:
    return SimpleNamespace(topic=topic, payload=json.dumps(payload).encode("utf-8"))


def test_ingestor_buffers_valid_messages() -> None:
    ingestor = Ingestor(IngestorSettings())
    ingestor.on_message(
        None,
        None,
        make_message(
            "iiot/v1/site-a/line-1/asset-1/energy_kwh",
            {"v": 1, "ts": 1730000000000, "asset": "asset-1", "signal": "energy_kwh", "value": 12.3, "quality": "good", "seq": 9},
        ),
    )
    assert len(ingestor.buffer) == 1
    assert ingestor.buffer[0]["signal"] == "energy_kwh"


def test_ingestor_drops_invalid_messages() -> None:
    ingestor = Ingestor(IngestorSettings())
    ingestor.on_message(
        None,
        None,
        make_message("iiot/v1/site-a/line-1/asset-1/energy_kwh", {"bad": "payload"}),
    )
    assert ingestor.buffer == []


def test_flush_if_due_writes_batch() -> None:
    ingestor = Ingestor(IngestorSettings(), max_batch=1)
    ingestor.buffer.append(
        {
            "ts": 1730000000000,
            "site": "site-a",
            "line": "line-1",
            "asset": "asset-1",
            "signal": "energy_kwh",
            "value": 12.3,
            "quality": "good",
            "seq": 9,
        }
    )
    cur = Mock()
    ingestor.flush_if_due(cur)
    cur.executemany.assert_called_once()
    assert ingestor.buffer == []
