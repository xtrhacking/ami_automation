FROM python:3.11-slim

LABEL maintainer="ExtremeHacking Labs"
LABEL description="Example API LAB"

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    iputils-ping \
    net-tools \
    curl && \
    rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy application files
COPY requirements.txt .
COPY app.py .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose port
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]
