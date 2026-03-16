from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONTRACTS_DIR = ROOT / "contracts"


@lru_cache(maxsize=1)
def load_register_map() -> dict[str, Any]:
    with (CONTRACTS_DIR / "register_map.json").open("r", encoding="utf-8") as handle:
        return json.load(handle)


@lru_cache(maxsize=1)
def load_payload_schema() -> dict[str, Any]:
    with (CONTRACTS_DIR / "telemetry_payload.schema.json").open("r", encoding="utf-8") as handle:
        return json.load(handle)
