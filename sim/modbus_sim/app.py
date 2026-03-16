from __future__ import annotations

import logging
import math
import struct
import threading
import time

from pymodbus.datastore import ModbusDeviceContext, ModbusSequentialDataBlock, ModbusServerContext
from pymodbus.server import StartTcpServer

from iiot_stack.logging_utils import configure_logging


LOG = logging.getLogger("modbus_sim")


def float_words(value: float) -> list[int]:
    packed = struct.pack(">f", value)
    return list(struct.unpack(">HH", packed))


def uint32_words(value: int) -> list[int]:
    return [(value >> 16) & 0xFFFF, value & 0xFFFF]


def build_context() -> ModbusServerContext:
    block = ModbusSequentialDataBlock(0, [0] * 32)
    slave = ModbusDeviceContext(hr=block)
    return ModbusServerContext(devices={1: slave}, single=False)


def serve() -> None:
    configure_logging()
    context = build_context()
    store = context[1]
    start = time.time()

    def updater() -> None:
        while True:
            elapsed = time.time() - start
            energy = 100_000 + int(elapsed * 12)
            temperature = 22.5 + math.sin(elapsed / 5.0) * 2.0
            pressure = 4.2 + math.cos(elapsed / 7.0) * 0.4

            store.setValues(3, 0, uint32_words(energy))
            store.setValues(3, 2, float_words(float(temperature)))
            store.setValues(3, 4, float_words(float(pressure)))
            LOG.info(
                "updated register values",
                extra={
                    "event": {
                        "energy_raw": energy,
                        "temperature_c": round(temperature, 3),
                        "pressure_bar": round(pressure, 3),
                    }
                },
            )
            time.sleep(1.0)

    threading.Thread(target=updater, daemon=True).start()
    StartTcpServer(context, address=("0.0.0.0", 1502))


if __name__ == "__main__":
    serve()
