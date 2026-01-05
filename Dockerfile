# Stage 1: Build from local source
FROM python:3.11-slim AS builder

# Install build dependencies (required for some C-extensions)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy the local repository content into the image
WORKDIR /src
COPY . .

# Install from local source code instead of PyPI
# This assumes there is a setup.py or pyproject.toml in the root
RUN pip install --no-cache-dir .[all]

# Stage 2: Final runtime image (Minimal and Secure)
FROM python:3.11-slim

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash whatsapp && \
    mkdir -p /data && \
    chown -R whatsapp:whatsapp /data

# Copy the installed environment from builder
COPY --from=builder /opt/venv /opt/venv

# Set runtime environment
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /data
USER whatsapp

# Disable healthcheck for extra security
HEALTHCHECK NONE

CMD ["wtsexporter", "--help"]