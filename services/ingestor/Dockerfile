FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml README.md ./
COPY src ./src
COPY contracts ./contracts
COPY services/ingestor ./services/ingestor

RUN pip install --no-cache-dir .

CMD ["python", "services/ingestor/app.py"]
