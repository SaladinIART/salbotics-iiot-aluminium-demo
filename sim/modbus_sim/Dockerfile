FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml README.md ./
COPY src ./src
COPY contracts ./contracts
COPY sim/modbus_sim ./sim/modbus_sim

RUN pip install --no-cache-dir . flask

ENV APP_ROOT=/app
# scenario_api.py and scenario_state.py are siblings of app.py in /app/sim/modbus_sim
ENV PYTHONPATH=/app/sim/modbus_sim

EXPOSE 1502
EXPOSE 5001

CMD ["python", "sim/modbus_sim/app.py"]
