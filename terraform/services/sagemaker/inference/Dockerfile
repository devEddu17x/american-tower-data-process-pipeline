FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /opt/program

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY serve.py .

EXPOSE 8080

# SageMaker invokes the container with `serve` as argument
ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--timeout", "120", "serve:app"]
