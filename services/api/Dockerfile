FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml README.md ./
COPY src ./src
COPY contracts ./contracts
COPY services/api ./services/api

RUN pip install --no-cache-dir .

EXPOSE 8000

CMD ["python", "services/api/main.py"]
