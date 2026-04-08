from __future__ import annotations

import logging
import math
import struct
import threading
import time

from pymodbus.datastore import ModbusDeviceContext, ModbusSequentialDataBlock, ModbusServerContext
from pymodbus.server import StartTcpServer

from iiot_stack.industrial import load_assets
from iiot_stack.logging_utils import configure_logging
import scenario_state
import scenario_api


LOG = logging.getLogger("modbus_sim")


def float_words(value: float) -> list[int]:
    packed = struct.pack(">f", value)
    return list(struct.unpack(">HH", packed))


def uint32_words(value: int) -> list[int]:
    return [(value >> 16) & 0xFFFF, value & 0xFFFF]


def uint16_words(value: int) -> list[int]:
    return [value & 0xFFFF]


def build_context() -> ModbusServerContext:
    block = ModbusSequentialDataBlock(0, [0] * 128)
    slave = ModbusDeviceContext(hr=block)
    return ModbusServerContext(devices={1: slave}, single=False)


def serve() -> None:
    configure_logging()

    # Start scenario HTTP API on port 5001 (background thread)
    threading.Thread(target=scenario_api.run, daemon=True).start()
    LOG.info("scenario API started on :5001")

    context = build_context()
    store = context[1]
    start = time.time()
    assets = load_assets()

    # 90-second cycling scenario windows (used when no scenario lock is active)
    scenario_windows = {
        "feeder-01":   [(0, 8, 1, 0), (8, 34, 2, 0), (34, 43, 3, 101), (43, 55, 2, 0), (55, 66, 4, 0), (66, 90, 2, 0)],
        "mixer-01":    [(0, 10, 1, 0), (10, 45, 2, 0), (45, 52, 3, 201), (52, 70, 2, 0), (70, 90, 2, 0)],
        "conveyor-01": [(0, 7, 0, 0), (7, 40, 2, 0), (40, 49, 3, 301), (49, 65, 2, 0), (65, 90, 2, 0)],
        "packer-01":   [(0, 12, 1, 0), (12, 58, 2, 0), (58, 68, 3, 401), (68, 77, 4, 0), (77, 90, 2, 0)],
    }

    counters = {asset["asset_id"]: 0 for asset in assets}

    def cycling_state(asset_id: str, elapsed: float) -> tuple[int, int]:
        second = int(elapsed) % 90
        for start_second, end_second, state_code, fault_code in scenario_windows[asset_id]:
            if start_second <= second < end_second:
                return state_code, fault_code
        return 2, 0

    def analog_values(asset_id: str, elapsed: float, state_code: int, fault_code: int) -> tuple[float, float]:
        phase = elapsed / 5.0
        if asset_id == "feeder-01":
            primary = 96.0 + math.sin(phase) * 7.0
            secondary = 61.0 + math.cos(phase / 1.7) * 18.0
            if fault_code == 101:
                secondary = 14.0
            if state_code in {0, 4}:
                primary *= 0.15
        elif asset_id == "mixer-01":
            primary = 71.0 + math.sin(phase / 1.2) * 4.0
            secondary = 4.7 + math.cos(phase / 1.5) * 0.5
            if fault_code == 201:
                primary = 88.0 + math.sin(phase) * 2.0
            if fault_code == 202:
                secondary = 2.5
            if state_code in {0, 4}:
                secondary = 0.8
        elif asset_id == "conveyor-01":
            primary = 31.0 + math.sin(phase / 1.3) * 3.0
            secondary = 3.2 + math.cos(phase / 2.1) * 0.8
            if fault_code == 301:
                primary = 6.0
                secondary = 8.8
            if state_code in {0, 4}:
                primary = 0.0
        else:
            primary = 181.0 + math.sin(phase / 1.4) * 6.0
            secondary = 61.0 + math.cos(phase / 2.0) * 5.0
            if fault_code == 401:
                secondary = 18.0
            if state_code == 4:
                primary = 152.0
                secondary = 0.0
        return float(primary), float(secondary)

    def updater() -> None:
        while True:
            elapsed = time.time() - start
            cycle_snapshot: dict[str, dict[str, float | int]] = {}
            for asset in assets:
                asset_id = asset["asset_id"]
                base_address = asset["base_address"]

                # Check for active scenario lock; fall back to 90-second cycling
                override = scenario_state.get_override(asset_id)
                if override is not None:
                    state_code, fault_code = override
                else:
                    state_code, fault_code = cycling_state(asset_id, elapsed)

                primary, secondary = analog_values(asset_id, elapsed, state_code, fault_code)

                if state_code == 2:
                    increment = max(1, int(abs(primary) / 8))
                elif state_code == 1:
                    increment = 1
                else:
                    increment = 0
                counters[asset_id] += increment

                store.setValues(3, base_address, float_words(primary))
                store.setValues(3, base_address + 2, float_words(secondary))
                store.setValues(3, base_address + 4, uint32_words(counters[asset_id]))
                store.setValues(3, base_address + 6, uint16_words(state_code))
                store.setValues(3, base_address + 7, uint16_words(fault_code))

                cycle_snapshot[asset_id] = {
                    "primary": round(primary, 2),
                    "secondary": round(secondary, 2),
                    "count": counters[asset_id],
                    "state_code": state_code,
                    "fault_code": fault_code,
                }

            LOG.info("updated line registers", extra={"event": cycle_snapshot})
            time.sleep(1.0)

    threading.Thread(target=updater, daemon=True).start()
    StartTcpServer(context, address=("0.0.0.0", 1502))


if __name__ == "__main__":
    serve()
