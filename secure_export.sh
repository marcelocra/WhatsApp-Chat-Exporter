#!/bin/bash
#
# Secure WhatsApp Chat Export Script
# This script automates the secure export process using Docker
#
# Usage: ./secure_export.sh [android|ios]
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/whatsapp_export_$(date +%Y%m%d_%H%M%S)"
INPUT_DIR="${WORK_DIR}/input"
OUTPUT_DIR="${WORK_DIR}/output"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v gpg &> /dev/null; then
        log_warn "GPG is not installed. Encryption will be skipped."
    fi
}

setup_directories() {
    log_info "Creating secure working directory: ${WORK_DIR}"
    mkdir -p "${INPUT_DIR}" "${OUTPUT_DIR}"
    chmod 700 "${WORK_DIR}"
}

copy_input_files() {
    local platform=$1
    
    log_info "Please copy your WhatsApp data files to: ${INPUT_DIR}"
    
    if [ "$platform" == "android" ]; then
        echo ""
        echo "Required files:"
        echo "  - msgstore.db (or msgstore.db.crypt14/15 + key)"
        echo "  - wa.db (optional, for contact names)"
        echo "  - WhatsApp/ directory (for media files)"
        echo ""
    else
        echo ""
        echo "Required files:"
        echo "  - iOS backup directory (from ~/Library/Application Support/MobileSync/Backup/[device-id])"
        echo ""
    fi
    
    read -p "Press Enter when files are ready..."
    
    # Verify files exist
    if [ ! "$(ls -A "${INPUT_DIR}")" ]; then
        log_error "Input directory is empty. Please add your WhatsApp data files."
        exit 1
    fi
}

build_docker_image() {
    log_info "Building Docker image..."
    
    cd "${SCRIPT_DIR}"
    docker build -t whatsapp-exporter:secure . || {
        log_error "Failed to build Docker image"
        exit 1
    }
}

run_export() {
    local platform=$1
    
    log_info "Starting export process (this may take a while)..."
    log_info "Network access is DISABLED for security"
    
    # Note: Network is disabled with --network none
    # We rely on Docker's network isolation rather than testing it
    # as error messages vary across Docker versions
    
    # Run the export
    if [ "$platform" == "android" ]; then
        docker run --rm \
            --network none \
            --read-only \
            --tmpfs /tmp \
            --security-opt=no-new-privileges:true \
            --cap-drop=ALL \
            -v "${INPUT_DIR}:/data/input:ro" \
            -v "${OUTPUT_DIR}:/data/output" \
            -u "$(id -u):$(id -g)" \
            whatsapp-exporter:secure \
            wtsexporter -a \
                -d /data/input/msgstore.db \
                -w /data/input/wa.db \
                -m /data/input/WhatsApp \
                -o /data/output/result
    else
        docker run --rm \
            --network none \
            --read-only \
            --tmpfs /tmp \
            --security-opt=no-new-privileges:true \
            --cap-drop=ALL \
            -v "${INPUT_DIR}:/data/input:ro" \
            -v "${OUTPUT_DIR}:/data/output" \
            -u "$(id -u):$(id -g)" \
            whatsapp-exporter:secure \
            wtsexporter -i \
                -b /data/input/backup \
                -o /data/output/result
    fi
    
    log_info "Export completed successfully!"
}

encrypt_output() {
    if ! command -v gpg &> /dev/null; then
        log_warn "GPG not available, skipping encryption"
        return
    fi
    
    log_info "Encrypting exported data..."
    
    cd "${WORK_DIR}"
    tar -czf - output/result | gpg --symmetric --cipher-algo AES256 -o whatsapp_export.tar.gz.gpg
    
    if [ -f whatsapp_export.tar.gz.gpg ]; then
        log_info "Encrypted export created: ${WORK_DIR}/whatsapp_export.tar.gz.gpg"
        
        read -p "Delete unencrypted output? [y/N]: " confirm
        if [[ $confirm == [yY] ]]; then
            log_info "Securely deleting unencrypted data..."
            if command -v shred &> /dev/null; then
                find output/ -type f -exec shred -uvz -n 3 {} \;
            fi
            rm -rf output/
            log_info "Unencrypted data deleted"
        fi
    fi
}

cleanup_input() {
    read -p "Delete input files? [y/N]: " confirm
    if [[ $confirm == [yY] ]]; then
        log_info "Securely deleting input data..."
        if command -v shred &> /dev/null; then
            find "${INPUT_DIR}" -type f -exec shred -uvz -n 3 {} \;
        fi
        rm -rf "${INPUT_DIR}"
        log_info "Input data deleted"
    fi
}

show_summary() {
    echo ""
    echo "=========================================="
    echo "          Export Summary"
    echo "=========================================="
    echo "Work directory: ${WORK_DIR}"
    
    if [ -f "${WORK_DIR}/whatsapp_export.tar.gz.gpg" ]; then
        echo "Encrypted export: whatsapp_export.tar.gz.gpg"
        echo "Size: $(du -h ${WORK_DIR}/whatsapp_export.tar.gz.gpg | cut -f1)"
    elif [ -d "${OUTPUT_DIR}/result" ]; then
        echo "Unencrypted export: output/result/"
        echo "Size: $(du -sh ${OUTPUT_DIR}/result | cut -f1)"
    fi
    
    echo ""
    echo "Security measures applied:"
    echo "  ✓ Network isolated (Docker --network none)"
    echo "  ✓ Read-only filesystem"
    echo "  ✓ Dropped all capabilities"
    echo "  ✓ Non-root user execution"
    
    if [ -f "${WORK_DIR}/whatsapp_export.tar.gz.gpg" ]; then
        echo "  ✓ AES-256 encryption"
    fi
    
    echo ""
    echo "Next steps:"
    echo "  1. Store the encrypted file in a secure location"
    echo "  2. Back up to multiple secure locations"
    echo "  3. Document the encryption password securely"
    echo "  4. Delete the work directory when no longer needed:"
    echo "     rm -rf ${WORK_DIR}"
    echo "=========================================="
}

# Main script
main() {
    echo "WhatsApp Chat Exporter - Secure Export Script"
    echo "=============================================="
    echo ""
    
    # Check platform
    local platform=${1:-}
    if [ "$platform" != "android" ] && [ "$platform" != "ios" ]; then
        echo "Usage: $0 [android|ios]"
        echo ""
        echo "Examples:"
        echo "  $0 android    # Export Android WhatsApp data"
        echo "  $0 ios        # Export iOS WhatsApp data"
        exit 1
    fi
    
    log_info "Platform: $platform"
    echo ""
    
    # Execute workflow
    check_dependencies
    setup_directories
    copy_input_files "$platform"
    build_docker_image
    run_export "$platform"
    encrypt_output
    cleanup_input
    show_summary
}

# Run main function
main "$@"
