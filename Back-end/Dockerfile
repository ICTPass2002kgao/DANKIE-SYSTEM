# Use an official Python runtime as a parent image (Debian based)
# Using python:3.11-slim for better compatibility with ML libraries
FROM python:3.11-slim 
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
 
RUN apt-get update && \
    apt-get install -y \
    cmake \
    build-essential \
    libgl1 \
    libx11-dev \
    libgtk-3-dev \
    python3-dev \
    && \
    rm -rf /var/lib/apt/lists/* WORKDIR /app
 
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt
 
COPY . /app/
 
ENV PORT=8080
 
# Shell form execution allows environment variables ($PORT) to be evaluated and chains migration commands
CMD sh -c "python manage.py migrate && python manage.py collectstatic --noinput && gunicorn tact_api.wsgi --forwarded-allow-ips '*' --bind 0.0.0.0:$PORT --timeout 90"