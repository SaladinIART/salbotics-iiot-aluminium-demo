from __future__ import annotations

from typing import Any

from iiot_stack.contracts import load_register_map


def load_assets() -> list[dict[str, Any]]:
    return load_register_map()["assets"]


def asset_lookup() -> dict[str, dict[str, Any]]:
    return {asset["asset_id"]: asset for asset in load_assets()}


def signal_lookup(asset: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {signal["tag_id"]: signal for signal in asset["signals"]}


def state_name(asset: dict[str, Any], code: int) -> str:
    return asset["state_map"].get(str(code), "IDLE")


def fault_name(asset: dict[str, Any], code: int) -> str:
    return asset["fault_map"].get(str(code), "UNKNOWN")


def fault_severity(state: str, fault_code: int) -> str:
    if state == "FAULTED" or fault_code != 0:
        return "critical"
    if state in {"MAINTENANCE", "STARTUP"}:
        return "warning"
    return "info"
