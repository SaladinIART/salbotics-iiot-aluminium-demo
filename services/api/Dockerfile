FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml README.md ./
COPY src ./src
COPY contracts ./contracts
COPY services/api ./services/api

RUN pip install --no-cache-dir .

ENV APP_ROOT=/app
ENV PYTHONPATH=/app

EXPOSE 8000

CMD ["python", "-m", "services.api.main"]
