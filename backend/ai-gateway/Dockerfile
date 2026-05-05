FROM python:3.12-slim

# Non-root user for least-privilege execution
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

# Install dependencies first for layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .
COPY app/ ./app/

USER appuser

# Cloud Run injects PORT env var; default to 8080 for local dev
ENV PORT=8080

EXPOSE 8080

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port $PORT --workers 2"]
