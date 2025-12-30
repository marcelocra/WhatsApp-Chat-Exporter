# WhatsApp Chat Exporter - Secure Docker Configuration
# This Dockerfile creates a minimal, secure container for running the exporter

FROM python:3.11-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment and install dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install the exporter with all optional dependencies
RUN pip install --no-cache-dir whatsapp-chat-exporter[all]

# Final stage - minimal runtime image
FROM python:3.11-slim

# Create non-root user for running the application
RUN useradd -m -u 1000 -s /bin/bash whatsapp && \
    mkdir -p /data && \
    chown -R whatsapp:whatsapp /data

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Set environment variables
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Set working directory
WORKDIR /data

# Switch to non-root user
USER whatsapp

# Add health check
HEALTHCHECK NONE

# Default command shows help
CMD ["wtsexporter", "--help"]

# Security labels
LABEL org.opencontainers.image.title="WhatsApp Chat Exporter" \
      org.opencontainers.image.description="Secure container for exporting WhatsApp chat history" \
      org.opencontainers.image.vendor="WhatsApp Chat Exporter Project" \
      org.opencontainers.image.licenses="MIT" \
      security.isolated="true" \
      security.network="none"
