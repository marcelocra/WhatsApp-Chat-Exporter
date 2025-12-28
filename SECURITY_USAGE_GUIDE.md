# Security Usage Guide for WhatsApp Chat Exporter

## Table of Contents
1. [Introduction](#introduction)
2. [Threat Model](#threat-model)
3. [Quick Start - Most Secure Setup](#quick-start---most-secure-setup)
4. [Detailed Security Configurations](#detailed-security-configurations)
5. [Docker/Container Setup (Recommended)](#dockercontainer-setup-recommended)
6. [Virtual Machine Setup](#virtual-machine-setup)
7. [Operating System Specific Guides](#operating-system-specific-guides)
8. [Post-Export Security](#post-export-security)
9. [Troubleshooting](#troubleshooting)
10. [Security Checklist](#security-checklist)

## Introduction

This guide provides step-by-step instructions for using WhatsApp Chat Exporter in the most secure manner possible to protect your personal conversation history. Your WhatsApp data contains highly sensitive information including:

- Private conversations and messages
- Contact information
- Photos, videos, and documents
- Location data
- Call history

**Important**: Even though the code has been reviewed and found to be safe (see SECURITY.md), implementing additional layers of security is a best practice when handling sensitive personal data.

## Threat Model

### What We're Protecting Against:

1. **Network Data Exfiltration**: Malicious software transmitting your data over the internet
2. **Local Data Leakage**: Other applications accessing your exported data
3. **Persistence of Sensitive Data**: Temporary files remaining on disk after use
4. **Unauthorized Access**: Other users on the same system accessing your data
5. **Supply Chain Attacks**: Compromised dependencies or malicious updates

### Defense-in-Depth Strategy:

This guide uses multiple layers of security:
- **Network Isolation**: Prevent any network access during processing
- **Filesystem Isolation**: Use containers or VMs to isolate the tool
- **Encryption**: Encrypt data at rest
- **Access Control**: Restrict who can access the data
- **Secure Deletion**: Properly remove data after use

## Quick Start - Most Secure Setup

If you want the highest level of security without reading the entire guide, follow these steps:

### Option 1: Docker with No Network (Recommended for Most Users)

```bash
# 1. Create a secure working directory
mkdir -p ~/whatsapp_export_secure
cd ~/whatsapp_export_secure

# 2. Copy your WhatsApp data here
# (msgstore.db, wa.db, WhatsApp media folder, key file if encrypted)

# 3. Build Docker image
cat > Dockerfile << 'EOF'
FROM python:3.11-slim
RUN pip install --no-cache-dir whatsapp-chat-exporter[all]
WORKDIR /data
EOF

docker build -t whatsapp-exporter .

# 4. Run with NO NETWORK ACCESS
docker run --rm \
  --network none \
  -v "$(pwd):/data" \
  -it whatsapp-exporter \
  wtsexporter -a

# 5. Export is now in ./result/ directory
# Review and encrypt the output:
tar -czf whatsapp_export.tar.gz result/
gpg --symmetric --cipher-algo AES256 whatsapp_export.tar.gz

# 6. Securely delete unencrypted data
rm -rf result/ whatsapp_export.tar.gz
# Also delete input files if no longer needed
shred -uvz msgstore.db wa.db key 2>/dev/null || rm -f msgstore.db wa.db key
```

### Option 2: Air-Gapped System (Maximum Security)

For maximum security, use a completely offline computer:

1. Download dependencies on a trusted computer
2. Transfer to offline computer via USB
3. Run the exporter on offline computer
4. Export results to encrypted USB drive
5. Delete all data from offline computer

## Detailed Security Configurations

### Configuration Level 1: Basic (Minimal Effort)

**Security Level**: ⭐⭐ (Better than nothing)

```bash
# 1. Create isolated directory
mkdir ~/whatsapp_export
cd ~/whatsapp_export

# 2. Install in virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install whatsapp-chat-exporter

# 3. Disable network during export
# On Linux/Mac:
sudo ifconfig en0 down  # or your network interface

# On Windows (as Administrator):
# Disable-NetAdapter -Name "Ethernet"

# 4. Run export
wtsexporter -a -o secure_output

# 5. Re-enable network
sudo ifconfig en0 up

# 6. Set restrictive permissions
chmod 700 secure_output
```

**Pros**: Easy to set up  
**Cons**: Network disable requires privileges; data not strongly isolated

### Configuration Level 2: Container Isolation (Recommended)

**Security Level**: ⭐⭐⭐⭐ (Good balance of security and usability)

See "Quick Start" above for Docker commands.

**Additional Docker Security Options**:

```bash
# Run with additional security restrictions
docker run --rm \
  --network none \
  --read-only \
  --tmpfs /tmp \
  --security-opt=no-new-privileges \
  --cap-drop=ALL \
  -v "$(pwd):/data" \
  -u $(id -u):$(id -g) \
  -it whatsapp-exporter \
  wtsexporter -a
```

**Pros**: Strong isolation, no network, easy to clean up  
**Cons**: Requires Docker installation

### Configuration Level 3: Virtual Machine (Maximum Isolation)

**Security Level**: ⭐⭐⭐⭐⭐ (Maximum security for personal use)

1. **Create a VM** (using VirtualBox, VMware, or similar)
   - Use a minimal Linux distribution (e.g., Ubuntu Server)
   - Allocate minimal resources (1-2 GB RAM is sufficient)
   - No shared folders initially

2. **Disable Network in VM**:
   ```bash
   # In VM settings, disable all network adapters
   # OR inside VM:
   sudo ip link set dev eth0 down
   ```

3. **Transfer Data Securely**:
   - Use encrypted USB drive or
   - Use shared folders (enable briefly, then disable)

4. **Install and Run**:
   ```bash
   # Inside VM
   sudo apt update && sudo apt install python3 python3-pip
   python3 -m pip install whatsapp-chat-exporter[all]
   wtsexporter -a
   ```

5. **Export Data**:
   - Compress and encrypt output
   - Transfer to host via USB or temporary shared folder
   - Delete VM snapshot when done

**Pros**: Complete isolation, can snapshot and revert  
**Cons**: Requires more resources and setup time

## Docker/Container Setup (Recommended)

### Full Docker Setup with Encrypted Storage

This setup uses Docker with an encrypted volume for maximum protection:

```bash
#!/bin/bash
# setup_secure_export.sh

# 1. Create encrypted volume (requires cryptsetup)
sudo cryptsetup luksFormat /dev/loop0  # or a spare partition
sudo cryptsetup open /dev/loop0 whatsapp_secure
sudo mkfs.ext4 /dev/mapper/whatsapp_secure

# 2. Mount encrypted volume
sudo mkdir -p /mnt/whatsapp_secure
sudo mount /dev/mapper/whatsapp_secure /mnt/whatsapp_secure

# 3. Create Docker container
docker run --rm \
  --network none \
  --read-only \
  --tmpfs /tmp \
  -v /mnt/whatsapp_secure:/data \
  -it whatsapp-exporter \
  wtsexporter -a -o /data/result

# 4. Unmount and close encrypted volume
sudo umount /mnt/whatsapp_secure
sudo cryptsetup close whatsapp_secure
```

### Podman (Rootless Alternative to Docker)

```bash
# Install podman
sudo apt install podman  # Debian/Ubuntu
# or: brew install podman  # macOS

# Run without root privileges
podman run --rm \
  --network none \
  -v "$(pwd):/data:Z" \
  -it docker.io/library/python:3.11-slim \
  bash -c "pip install whatsapp-chat-exporter && wtsexporter -a"
```

### Docker Compose Configuration

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  whatsapp-exporter:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - ./input:/input:ro  # Read-only input
      - ./output:/output
    network_mode: none
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    tmpfs:
      - /tmp
    user: "${UID}:${GID}"
    command: wtsexporter -a -d /input/msgstore.db -w /input/wa.db -m /input/WhatsApp -o /output
```

Run with:
```bash
UID=$(id -u) GID=$(id -g) docker-compose run --rm whatsapp-exporter
```

## Virtual Machine Setup

### Using VirtualBox

1. **Download and Install VirtualBox**: https://www.virtualbox.org/

2. **Create New VM**:
   ```
   - Name: WhatsApp Export Secure
   - Type: Linux
   - Version: Ubuntu (64-bit)
   - Memory: 2048 MB
   - Hard disk: 10 GB (dynamically allocated)
   ```

3. **Install Ubuntu Server** (minimal installation)

4. **Configure Network**:
   - Before starting VM: Settings → Network → Adapter 1 → Not attached
   - This completely isolates the VM from network

5. **Transfer Files**:
   - Create shared folder in VirtualBox
   - Mount inside VM:
     ```bash
     sudo mount -t vboxsf shared_folder /mnt/shared
     cp /mnt/shared/msgstore.db ~/
     sudo umount /mnt/shared
     ```
   - Disable shared folder after transfer

6. **Install and Run**:
   ```bash
   sudo apt install python3-pip
   pip3 install whatsapp-chat-exporter[all]
   ~/.local/bin/wtsexporter -a
   ```

7. **Extract Results**:
   - Re-enable shared folder temporarily
   - Copy encrypted archive out
   - Delete all data in VM
   - Create snapshot for future use

### Using QEMU/KVM

```bash
# Create VM
virt-install \
  --name whatsapp-export \
  --memory 2048 \
  --vcpus 2 \
  --disk size=10 \
  --network none \
  --cdrom ubuntu-22.04-live-server-amd64.iso

# Start without network
virsh start whatsapp-export --console
```

## Operating System Specific Guides

### Linux

#### Using AppArmor Profile

Create `/etc/apparmor.d/usr.local.bin.wtsexporter`:

```
#include <tunables/global>

/usr/local/bin/wtsexporter {
  #include <abstractions/base>
  #include <abstractions/python>
  
  # Read access to input files
  /home/*/whatsapp_export/** r,
  
  # Write access to output directory
  /home/*/whatsapp_export/result/** w,
  
  # Deny network
  deny network inet,
  deny network inet6,
  
  # Deny unnecessary capabilities
  deny capability sys_admin,
  deny capability sys_module,
}
```

Activate:
```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.wtsexporter
```

#### Using Firejail

```bash
# Install firejail
sudo apt install firejail

# Run with restrictions
firejail \
  --net=none \
  --private=~/whatsapp_export \
  --private-tmp \
  --caps.drop=all \
  wtsexporter -a
```

### macOS

#### Using Built-in Sandboxing

```bash
# Create sandbox profile
cat > whatsapp_export.sb << 'EOF'
(version 1)
(deny default)
(allow file-read* file-write*
  (subpath "/Users/$(whoami)/whatsapp_export"))
(deny network*)
EOF

# Run with sandbox
sandbox-exec -f whatsapp_export.sb wtsexporter -a
```

#### Disable Network for Specific Application

```bash
# Create a pfctl rule
echo "block drop out proto {tcp udp} from any to any" | sudo pfctl -f -

# Run export
wtsexporter -a

# Re-enable network
sudo pfctl -F all
```

### Windows

#### Using Windows Sandbox

1. Enable Windows Sandbox (Windows 10 Pro/Enterprise)
   - Settings → Apps → Optional Features → Add → Windows Sandbox

2. Create configuration file `whatsapp_export.wsb`:
   ```xml
   <Configuration>
     <VGpu>Disable</VGpu>
     <Networking>Disable</Networking>
     <MappedFolders>
       <MappedFolder>
         <HostFolder>C:\WhatsApp_Export</HostFolder>
         <ReadOnly>false</ReadOnly>
       </MappedFolder>
     </MappedFolders>
     <LogonCommand>
       <Command>python -m pip install whatsapp-chat-exporter</Command>
     </LogonCommand>
   </Configuration>
   ```

3. Double-click to launch sandbox

4. Run export inside sandbox

5. Close sandbox (everything is automatically deleted)

#### Using Windows Firewall

```powershell
# Block Python from network (as Administrator)
New-NetFirewallRule -DisplayName "Block Python" -Direction Outbound -Program "C:\Python311\python.exe" -Action Block

# Run export
python -m pip install whatsapp-chat-exporter  # do this before blocking
wtsexporter -a

# Remove rule
Remove-NetFirewallRule -DisplayName "Block Python"
```

## Post-Export Security

### Encrypting Your Export

#### Using GPG (Recommended)

```bash
# Compress and encrypt
tar -czf - result/ | gpg --symmetric --cipher-algo AES256 -o whatsapp_export.tar.gz.gpg

# Later, decrypt
gpg -d whatsapp_export.tar.gz.gpg | tar -xzf -
```

#### Using 7-Zip with AES-256

```bash
# Linux/Mac
7z a -p -mhe=on -t7z whatsapp_export.7z result/

# Windows
"C:\Program Files\7-Zip\7z.exe" a -p -mhe=on -t7z whatsapp_export.7z result\
```

#### Using VeraCrypt

1. Download VeraCrypt: https://www.veracrypt.fr/
2. Create encrypted volume:
   - Tools → Volume Creation Wizard
   - Create encrypted file container
   - AES encryption
   - Size: Based on your data
3. Mount volume and copy export
4. Dismount when done

### Secure Deletion

#### Linux/macOS

```bash
# Secure delete individual files
shred -uvz -n 3 msgstore.db wa.db key

# Secure delete directory
find result/ -type f -exec shred -uvz -n 3 {} \;
rm -rf result/

# Or use srm (secure-delete package)
sudo apt install secure-delete
srm -r result/
```

#### macOS Specific

```bash
# Use rm with secure deletion (deprecated in newer macOS, but still works)
rm -P msgstore.db

# Alternative: use diskutil
# This works only on APFS volumes
diskutil secureErase freespace 3 /Volumes/YourDrive
```

#### Windows

```powershell
# Using cipher
cipher /w:C:\WhatsApp_Export

# Using SDelete (Sysinternals)
sdelete -p 3 -s C:\WhatsApp_Export

# Or use built-in PowerShell
Remove-Item -Path result -Recurse -Force
```

### Setting Up Access Controls

#### Linux/macOS

```bash
# Set restrictive permissions
chmod 700 ~/whatsapp_export
chmod 600 ~/whatsapp_export/whatsapp_export.tar.gz.gpg

# Use ACLs for fine-grained control
setfacl -m u:nobody:--- ~/whatsapp_export
```

#### Windows

```powershell
# Remove all inherited permissions
icacls "C:\WhatsApp_Export" /inheritance:r

# Grant only to current user
icacls "C:\WhatsApp_Export" /grant:r "%USERNAME%:(OI)(CI)F"
```

### Automated Cleanup Script

Save as `cleanup_export.sh`:

```bash
#!/bin/bash
set -euo pipefail

EXPORT_DIR="$HOME/whatsapp_export"
ENCRYPTED_OUTPUT="whatsapp_backup_$(date +%Y%m%d_%H%M%S).tar.gz.gpg"

echo "Starting secure cleanup..."

# 1. Verify export exists
if [ ! -d "$EXPORT_DIR/result" ]; then
    echo "Error: Export directory not found"
    exit 1
fi

# 2. Create encrypted backup
echo "Creating encrypted backup..."
cd "$EXPORT_DIR"
tar -czf - result/ | gpg --symmetric --cipher-algo AES256 -o "$ENCRYPTED_OUTPUT"

# 3. Verify encryption
if [ ! -f "$ENCRYPTED_OUTPUT" ]; then
    echo "Error: Encryption failed"
    exit 1
fi

# 4. Secure delete unencrypted data
echo "Securely deleting unencrypted data..."
find result/ -type f -exec shred -uvz -n 3 {} \;
rm -rf result/

# 5. Delete input files
if [ -f msgstore.db ]; then shred -uvz -n 3 msgstore.db; fi
if [ -f wa.db ]; then shred -uvz -n 3 wa.db; fi
if [ -f key ]; then shred -uvz -n 3 key; fi

# 6. Set permissions on encrypted file
chmod 600 "$ENCRYPTED_OUTPUT"

echo "Cleanup complete. Encrypted export: $ENCRYPTED_OUTPUT"
```

## Troubleshooting

### "Permission Denied" in Docker

**Problem**: Cannot access files in Docker container

**Solution**:
```bash
# Run as your user
docker run -u $(id -u):$(id -g) ...

# Or fix permissions
sudo chown -R $(id -u):$(id -g) ./result
```

### Network Still Working Despite Disable

**Problem**: Applications can still access network

**Solution**:
```bash
# Verify network is disabled in container
docker run --network none alpine ping -c 1 google.com
# Should fail with "bad address"

# For host-level blocking, verify with:
ping google.com
# Should fail
```

### GPG Encryption Takes Too Long

**Problem**: Encrypting large exports is slow

**Solution**:
```bash
# Use pigz for parallel compression
tar -cf - result/ | pigz | gpg --symmetric --cipher-algo AES256 -o export.tar.gz.gpg

# Or use zstd for faster compression
tar --zstd -cf - result/ | gpg --symmetric --cipher-algo AES256 -o export.tar.zst.gpg
```

### Cannot Delete Files Completely

**Problem**: Shred not available or not working on SSD

**Solution**:
```bash
# For SSDs, encryption is more important than deletion
# Modern SSDs wear leveling makes secure deletion difficult
# Focus on:
# 1. Encrypt before storing
# 2. Encrypt the entire disk (LUKS/FileVault/BitLocker)
# 3. Normal deletion + full disk encryption = adequate security
```

## Security Checklist

Before running the exporter, verify:

- [ ] Working directory is created and isolated
- [ ] Network is disabled or container has `--network none`
- [ ] Input files are present (msgstore.db, wa.db, etc.)
- [ ] Running with minimal privileges (not root/administrator)
- [ ] Disk encryption is enabled (optional but recommended)

During export:

- [ ] Monitor process for unexpected behavior
- [ ] Verify no network activity (check firewall logs)
- [ ] Ensure sufficient disk space

After export:

- [ ] Review exported content
- [ ] Encrypt the export
- [ ] Verify encrypted archive integrity
- [ ] Securely delete unencrypted data
- [ ] Set restrictive permissions on encrypted file
- [ ] Store encrypted backup in secure location
- [ ] Document the encryption password securely

Regular maintenance:

- [ ] Update exporter: `pip install --upgrade whatsapp-chat-exporter`
- [ ] Check for security advisories
- [ ] Review access logs (if any)
- [ ] Rotate encryption keys annually

## Additional Resources

### Security Tools

- **Docker**: https://www.docker.com/
- **VirtualBox**: https://www.virtualbox.org/
- **VeraCrypt**: https://www.veracrypt.fr/
- **GnuPG**: https://gnupg.org/
- **Firejail**: https://firejail.wordpress.com/

### Learning Resources

- Docker Security Best Practices: https://docs.docker.com/engine/security/
- Linux Security Modules: https://www.kernel.org/doc/html/latest/admin-guide/LSM/index.html
- NIST Cybersecurity Framework: https://www.nist.gov/cyberframework

### Reporting Security Issues

If you discover a security vulnerability in WhatsApp Chat Exporter:

1. **Do not** open a public issue
2. Email the maintainer privately (check README for contact)
3. Provide detailed information about the vulnerability
4. Wait for acknowledgment before public disclosure

## Conclusion

By following this guide, you can process your WhatsApp data with confidence that:

1. ✅ Your data never leaves your control
2. ✅ No network access during processing
3. ✅ Data is isolated from other applications
4. ✅ Exports are encrypted at rest
5. ✅ Temporary data is securely deleted
6. ✅ Access is restricted to authorized users only

**Remember**: Security is a process, not a product. Regularly review and update your security practices.

---

**Last Updated**: 2025-12-28  
**Guide Version**: 1.0  
**Compatible with WhatsApp Chat Exporter**: 0.12.1+
