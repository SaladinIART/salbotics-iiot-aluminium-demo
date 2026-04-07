FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml README.md ./
COPY src ./src
COPY contracts ./contracts
COPY services/alerting ./services/alerting

RUN pip install --no-cache-dir .

ENV APP_ROOT=/app
ENV PYTHONPATH=/app

CMD ["python", "-m", "services.alerting.router"]
