FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml README.md ./
COPY src ./src
COPY contracts ./contracts
COPY services/collector ./services/collector

RUN pip install --no-cache-dir .

CMD ["python", "services/collector/app.py"]
