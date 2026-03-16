FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml README.md ./
COPY src ./src
COPY sim/modbus_sim ./sim/modbus_sim

RUN pip install --no-cache-dir .

CMD ["python", "sim/modbus_sim/app.py"]
