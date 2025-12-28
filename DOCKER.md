# Docker Usage for WhatsApp Chat Exporter

This directory contains Docker configurations for running WhatsApp Chat Exporter in a secure, isolated environment.

## Quick Start

### Prerequisites
- Docker installed on your system
- Docker Compose (optional, for easier management)
- Your WhatsApp data files

### Basic Usage with Docker

1. **Prepare your data:**
```bash
mkdir -p input output
# Copy your WhatsApp files to input/
cp msgstore.db wa.db input/
cp -r WhatsApp/ input/
```

2. **Build the Docker image:**
```bash
docker build -t whatsapp-exporter .
```

3. **Run the exporter (Android):**
```bash
docker run --rm \
  --network none \
  -v "$(pwd)/input:/data/input:ro" \
  -v "$(pwd)/output:/data/output" \
  -u $(id -u):$(id -g) \
  whatsapp-exporter \
  wtsexporter -a -d /data/input/msgstore.db -w /data/input/wa.db -m /data/input/WhatsApp -o /data/output
```

4. **Your exported data will be in:**
```bash
./output/result/
```

### Using Docker Compose

1. **Prepare directories:**
```bash
mkdir -p input output
```

2. **Copy your data to input/**

3. **Run with Docker Compose:**
```bash
# For Android
UID=$(id -u) GID=$(id -g) docker-compose run --rm whatsapp-exporter

# For iOS
UID=$(id -u) GID=$(id -g) docker-compose run --rm whatsapp-exporter-ios
```

## Security Features

This Docker configuration includes multiple security layers:

### Network Isolation
- **No network access**: `--network none` prevents all network communication
- Data cannot be exfiltrated over the network
- Tool cannot download malicious updates

### Filesystem Isolation
- **Read-only root filesystem**: Prevents container modification
- **Input directory is read-only**: Source data cannot be corrupted
- **Temporary files in memory**: `/tmp` is a tmpfs mount

### Process Isolation
- **Non-root user**: Container runs as your UID/GID, not root
- **Dropped capabilities**: All Linux capabilities are dropped
- **No new privileges**: `security-opt=no-new-privileges` prevents escalation

### Resource Limits
- **CPU limit**: Maximum 2 cores
- **Memory limit**: Maximum 2GB RAM
- Prevents resource exhaustion attacks

## Advanced Usage

### Encrypted Backup Decryption

If you have an encrypted Android backup:

```bash
# Place your key file in input/
docker run --rm \
  --network none \
  -v "$(pwd)/input:/data/input:ro" \
  -v "$(pwd)/output:/data/output" \
  -u $(id -u):$(id -g) \
  whatsapp-exporter \
  wtsexporter -a \
    -k /data/input/key \
    -b /data/input/msgstore.db.crypt15 \
    -o /data/output
```

### Custom Export Options

```bash
# JSON export with pretty printing
docker run --rm \
  --network none \
  -v "$(pwd)/input:/data/input:ro" \
  -v "$(pwd)/output:/data/output" \
  -u $(id -u):$(id -g) \
  whatsapp-exporter \
  wtsexporter -a \
    -d /data/input/msgstore.db \
    -o /data/output \
    -j /data/output/export.json \
    --pretty-print-json
```

### Interactive Mode

```bash
docker run --rm -it \
  --network none \
  -v "$(pwd)/input:/data/input:ro" \
  -v "$(pwd)/output:/data/output" \
  -u $(id -u):$(id -g) \
  whatsapp-exporter \
  /bin/bash

# Inside container:
# wtsexporter -a -d /data/input/msgstore.db -o /data/output
```

## Troubleshooting

### Permission Errors

If you get permission errors on output files:

```bash
# Run with your user ID
docker run -u $(id -u):$(id -g) ...

# Or fix permissions after
sudo chown -R $(id -u):$(id -g) output/
```

### Cannot Access Input Files

Ensure files are readable:
```bash
chmod -R 644 input/*
chmod 755 input/
```

### Out of Memory

Increase memory limit in docker-compose.yml:
```yaml
deploy:
  resources:
    limits:
      memory: 4G
```

### Network Verification

Verify network is truly disabled:
```bash
docker run --network none alpine ping -c 1 google.com
# Should fail with "bad address"
```

## Building from Source

To build with local source code:

```bash
# Clone the repository
git clone https://github.com/KnugiHK/WhatsApp-Chat-Exporter.git
cd WhatsApp-Chat-Exporter

# Build Docker image
docker build -t whatsapp-exporter .

# Run as usual
docker run --rm --network none -v ./input:/data/input:ro -v ./output:/data/output whatsapp-exporter wtsexporter -a
```

## Security Best Practices

1. **Always use `--network none`** to ensure no network access
2. **Mount input as read-only** (`:ro`) to prevent data corruption
3. **Run as non-root user** with `-u $(id -u):$(id -g)`
4. **Verify the Docker image** before using it
5. **Encrypt your exports** after processing:
   ```bash
   tar -czf - output/ | gpg --symmetric --cipher-algo AES256 -o export.tar.gz.gpg
   ```
6. **Securely delete unencrypted data**:
   ```bash
   rm -rf input/ output/
   ```

## Docker Image Verification

To verify the integrity of your Docker image:

```bash
# List image details
docker image inspect whatsapp-exporter

# Check image layers
docker history whatsapp-exporter

# Scan for vulnerabilities (if you have trivy installed)
trivy image whatsapp-exporter
```

## Cleanup

Remove containers and images:

```bash
# Remove all stopped containers
docker container prune

# Remove the image
docker image rm whatsapp-exporter

# Remove all unused data
docker system prune -a
```

## Additional Resources

- [Main Security Documentation](SECURITY.md)
- [Detailed Usage Guide](SECURITY_USAGE_GUIDE.md)
- [Project README](README.md)

## Support

For issues specific to Docker usage:
1. Check the [Troubleshooting](#troubleshooting) section
2. Verify your Docker version: `docker --version` (requires 20.10+)
3. Check Docker Compose version: `docker-compose --version` (requires 1.29+)
4. Review logs: `docker logs <container_id>`

For general exporter issues, see the main [README](README.md).
