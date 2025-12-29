#!/bin/bash
#
# Secure WhatsApp Chat Export Script
# This script automates the secure export process using Docker
#
# Usage: ./secure_export.sh [command] [options]
#
# Commands:
#   check_deps              Check if required dependencies are installed
#   build                   Build the Docker image
#   export_android <dir>    Export Android WhatsApp data from directory
#   export_ios <dir>        Export iOS WhatsApp data from directory
#   encrypt <dir>           Encrypt exported data in directory
#   all_android <dir>       Run all steps for Android (build + export + encrypt)
#   all_ios <dir>           Run all steps for iOS (build + export + encrypt)
#   help                    Show this help message
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Common Docker flags for security hardening
DOCKER_SECURITY_FLAGS=(
    --network none
    --read-only
    --tmpfs /tmp
    --security-opt=no-new-privileges:true
    --cap-drop=ALL
)

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

cmd_check_deps() {
    log_info "Checking dependencies..."
    
    local all_ok=true
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        all_ok=false
    else
        log_info "✓ Docker is installed"
    fi
    
    if ! command -v gpg &> /dev/null; then
        log_warn "GPG is not installed. Encryption will be skipped."
    else
        log_info "✓ GPG is installed"
    fi
    
    if [ "$all_ok" = true ]; then
        log_info "All required dependencies are installed!"
        return 0
    else
        return 1
    fi
}

cmd_build() {
    log_info "Building Docker image..."
    
    cd "${SCRIPT_DIR}"
    docker build -t whatsapp-exporter:secure . || {
        log_error "Failed to build Docker image"
        return 1
    }
    
    log_info "✓ Docker image built successfully: whatsapp-exporter:secure"
}

cmd_export_android() {
    local input_dir="${1:?Input directory required}"
    
    # Resolve to absolute path
    input_dir="$(cd "$input_dir" && pwd)"
    
    # Create output directory
    local output_dir="${input_dir}_output_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output_dir"
    chmod 700 "$output_dir"
    
    log_info "Starting Android export process (this may take a while)..."
    log_info "Input directory: ${input_dir}"
    log_info "Output directory: ${output_dir}"
    log_info "Network access is DISABLED for security"
    
    # Run the export with common security flags
    docker run --rm \
        "${DOCKER_SECURITY_FLAGS[@]}" \
        -v "${input_dir}:/data/input:ro" \
        -v "${output_dir}:/data/output" \
        -u "$(id -u):$(id -g)" \
        whatsapp-exporter:secure \
        wtsexporter -a \
            -d /data/input/msgstore.db \
            -w /data/input/wa.db \
            -m /data/input/WhatsApp \
            -o /data/output/result
    
    log_info "✓ Export completed successfully!"
    log_info "Results in: ${output_dir}/result"
    echo ""
    echo "To encrypt the output, run:"
    echo "  $0 encrypt ${output_dir}"
}

cmd_export_ios() {
    local input_dir="${1:?Input directory required}"
    
    # Resolve to absolute path
    input_dir="$(cd "$input_dir" && pwd)"
    
    # Create output directory
    local output_dir="${input_dir}_output_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output_dir"
    chmod 700 "$output_dir"
    
    log_info "Starting iOS export process (this may take a while)..."
    log_info "Input directory: ${input_dir}"
    log_info "Output directory: ${output_dir}"
    log_info "Network access is DISABLED for security"
    
    # Run the export with common security flags
    docker run --rm \
        "${DOCKER_SECURITY_FLAGS[@]}" \
        -v "${input_dir}:/data/input:ro" \
        -v "${output_dir}:/data/output" \
        -u "$(id -u):$(id -g)" \
        whatsapp-exporter:secure \
        wtsexporter -i \
            -b /data/input \
            -o /data/output/result
    
    log_info "✓ Export completed successfully!"
    log_info "Results in: ${output_dir}/result"
    echo ""
    echo "To encrypt the output, run:"
    echo "  $0 encrypt ${output_dir}"
}

cmd_encrypt() {
    local work_dir="${1:?Work directory required}"
    
    if ! command -v gpg &> /dev/null; then
        log_error "GPG is not installed. Please install GPG to encrypt the output."
        return 1
    fi
    
    # Resolve to absolute path
    work_dir="$(cd "$work_dir" && pwd)"
    
    if [ ! -d "${work_dir}/result" ]; then
        log_error "No result directory found in ${work_dir}"
        return 1
    fi
    
    log_info "Encrypting exported data in: ${work_dir}"
    
    cd "${work_dir}"
    tar -czf - result | gpg --symmetric --cipher-algo AES256 -o whatsapp_export.tar.gz.gpg
    
    if [ -f whatsapp_export.tar.gz.gpg ]; then
        log_info "✓ Encrypted export created: ${work_dir}/whatsapp_export.tar.gz.gpg"
        log_info "Size: $(du -h whatsapp_export.tar.gz.gpg | cut -f1)"
        echo ""
        echo "IMPORTANT: To securely delete unencrypted data, run:"
        echo "  # Delete output (if shred is available):"
        echo "  find ${work_dir}/result -type f -exec shred -uvz -n 3 {} \\;"
        echo "  rm -rf ${work_dir}/result"
        echo ""
        echo "  # Or simple delete (less secure on HDDs):"
        echo "  rm -rf ${work_dir}/result"
        echo ""
        echo "To securely delete input files, run:"
        echo "  # With shred (more secure):"
        echo "  find /path/to/input -type f -exec shred -uvz -n 3 {} \\;"
        echo "  rm -rf /path/to/input"
        echo ""
        echo "  # Or simple delete:"
        echo "  rm -rf /path/to/input"
    fi
}

cmd_all_android() {
    local input_dir="${1:?Input directory required}"
    
    log_info "Running complete Android export workflow..."
    echo ""
    
    cmd_build || return 1
    echo ""
    
    cmd_export_android "$input_dir" || return 1
    
    # Get the output directory that was created
    local output_dir=$(ls -dt "${input_dir}_output_"* 2>/dev/null | head -1)
    
    if [ -n "$output_dir" ] && [ -d "$output_dir" ]; then
        echo ""
        cmd_encrypt "$output_dir" || return 1
    fi
    
    echo ""
    log_info "✓ Complete workflow finished successfully!"
}

cmd_all_ios() {
    local input_dir="${1:?Input directory required}"
    
    log_info "Running complete iOS export workflow..."
    echo ""
    
    cmd_build || return 1
    echo ""
    
    cmd_export_ios "$input_dir" || return 1
    
    # Get the output directory that was created
    local output_dir=$(ls -dt "${input_dir}_output_"* 2>/dev/null | head -1)
    
    if [ -n "$output_dir" ] && [ -d "$output_dir" ]; then
        echo ""
        cmd_encrypt "$output_dir" || return 1
    fi
    
    echo ""
    log_info "✓ Complete workflow finished successfully!"
}

cmd_help() {
    cat << 'EOF'
WhatsApp Chat Exporter - Secure Export Script
==============================================

USAGE:
    ./secure_export.sh <command> [options]

COMMANDS:
    check_deps              Check if required dependencies are installed
    build                   Build the Docker image
    export_android <dir>    Export Android WhatsApp data from directory
    export_ios <dir>        Export iOS WhatsApp data from directory
    encrypt <dir>           Encrypt exported data in directory
    all_android <dir>       Run all steps for Android (build + export + encrypt)
    all_ios <dir>           Run all steps for iOS (build + export + encrypt)
    help                    Show this help message

EXAMPLES:
    # Check dependencies
    ./secure_export.sh check_deps
    
    # Build Docker image once
    ./secure_export.sh build
    
    # Export Android data (points to existing directory with your data)
    ./secure_export.sh export_android /path/to/whatsapp_data
    
    # Export iOS data (points to iOS backup directory)
    ./secure_export.sh export_ios ~/Library/Application\ Support/MobileSync/Backup/[device-id]
    
    # Encrypt the output
    ./secure_export.sh encrypt /path/to/whatsapp_data_output_20231228_120000
    
    # Run complete workflow for Android
    ./secure_export.sh all_android /path/to/whatsapp_data
    
    # Run complete workflow for iOS
    ./secure_export.sh all_ios ~/Library/Application\ Support/MobileSync/Backup/[device-id]

DIRECTORY STRUCTURE:
    For Android, your input directory should contain:
        - msgstore.db (or msgstore.db.crypt14/15 with key file)
        - wa.db (optional, for contact names)
        - WhatsApp/ directory (for media files)
    
    For iOS, point to the iOS backup directory:
        ~/Library/Application Support/MobileSync/Backup/[device-id]

SECURITY MEASURES:
    ✓ Network isolated (Docker --network none)
    ✓ Read-only input filesystem
    ✓ Dropped all capabilities
    ✓ Non-root user execution
    ✓ AES-256 encryption (with encrypt command)

For more information, see SECURITY_USAGE_GUIDE.md
EOF
}

# Main script
main() {
    local command="${1:-help}"
    
    case "$command" in
        check_deps)
            cmd_check_deps
            ;;
        build)
            cmd_build
            ;;
        export_android)
            shift
            cmd_export_android "$@"
            ;;
        export_ios)
            shift
            cmd_export_ios "$@"
            ;;
        encrypt)
            shift
            cmd_encrypt "$@"
            ;;
        all_android)
            shift
            cmd_all_android "$@"
            ;;
        all_ios)
            shift
            cmd_all_ios "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            echo "Unknown command: $command"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
