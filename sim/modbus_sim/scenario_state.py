"""Shared in-memory scenario lock for the Modbus simulator.

The scenario_api Flask endpoint writes here; the Modbus updater thread reads here.
All access is protected by a single threading.Lock for thread safety.
"""
from __future__ import annotations

import threading
import time

_lock = threading.Lock()
_scenario: str = "NORMAL"
_expires_at: float = 0.0  # epoch seconds; 0 = auto-cycling (no lock)

# ─── Scenario definitions ──────────────────────────────────────────────────────
# Each entry maps asset_id → (state_code, fault_code)
# State codes: 0=IDLE, 1=STARTUP, 2=RUNNING, 3=FAULTED, 4=MAINTENANCE
SCENARIO_STATES: dict[str, dict[str, tuple[int, int]]] = {
    "NORMAL": {
        "feeder-01":   (2, 0),
        "mixer-01":    (2, 0),
        "conveyor-01": (2, 0),
        "packer-01":   (2, 0),
    },
    "QUALITY_HOLD": {
        # Reflow oven drifting — HIGH_TEMP fault (201). Production rate cut to 60%.
        "feeder-01":   (2, 0),
        "mixer-01":    (3, 201),
        "conveyor-01": (2, 0),
        "packer-01":   (2, 0),
    },
    "LINE_FAULT": {
        # Conveyor jammed + packer film break — line stopped.
        "feeder-01":   (2, 0),
        "mixer-01":    (2, 0),
        "conveyor-01": (3, 301),
        "packer-01":   (3, 401),
    },
    "EMERGENCY": {
        # Feeder motor trip + reflow oven auto-shutdown — full line down.
        "feeder-01":   (3, 102),
        "mixer-01":    (3, 201),
        "conveyor-01": (0, 0),
        "packer-01":   (0, 0),
    },
}

SCENARIO_MESSAGES: dict[str, str] = {
    "NORMAL":       "All systems nominal. Production on target. No action required.",
    "QUALITY_HOLD": "Reflow oven temperature drift detected. Production at 60%. Batch #2024-034 on quality hold.",
    "LINE_FAULT":   "Line stopped — conveyor jam + packer film break. Order PO-2024-089 delivery at risk.",
    "EMERGENCY":    "FULL LINE SHUTDOWN — motor trip + oven auto-shutdown. All 3 customer orders at risk. Invoke BCP.",
}

SCENARIO_HEALTH: dict[str, str] = {
    "NORMAL":       "GREEN",
    "QUALITY_HOLD": "AMBER",
    "LINE_FAULT":   "RED",
    "EMERGENCY":    "CRITICAL",
}

AUTO_EXPIRE_SECONDS = 600  # 10 minutes


def set_scenario(name: str) -> None:
    """Lock the simulator to a named scenario for AUTO_EXPIRE_SECONDS."""
    if name not in SCENARIO_STATES:
        raise ValueError(f"Unknown scenario: {name!r}. Valid: {list(SCENARIO_STATES)}")
    with _lock:
        global _scenario, _expires_at
        _scenario = name
        _expires_at = time.time() + AUTO_EXPIRE_SECONDS if name != "NORMAL" else 0.0


def get_scenario() -> str:
    """Return the current active scenario name, resetting expired locks."""
    with _lock:
        global _scenario, _expires_at
        if _expires_at and time.time() > _expires_at:
            _scenario = "NORMAL"
            _expires_at = 0.0
        return _scenario


def get_override(asset_id: str) -> tuple[int, int] | None:
    """Return (state_code, fault_code) override for an asset, or None if in NORMAL cycling."""
    scenario = get_scenario()
    if scenario == "NORMAL":
        return None
    return SCENARIO_STATES[scenario].get(asset_id)


def status() -> dict:
    """Return full status dict for the scenario API response."""
    scenario = get_scenario()
    with _lock:
        remaining = max(0.0, _expires_at - time.time()) if _expires_at else 0.0
    return {
        "scenario": scenario,
        "health": SCENARIO_HEALTH[scenario],
        "message": SCENARIO_MESSAGES[scenario],
        "auto_resets_in_seconds": int(remaining) if remaining else None,
        "valid_scenarios": list(SCENARIO_STATES.keys()),
    }
