#!/bin/bash
#
# generate-lab-files.sh - Generates Packer HCL files from templates
#
# Usage: ./generate-lab-files.sh <folder> <os-type>
# Example: ./generate-lab-files.sh sql-injection ubuntu-24
#
# Generates:
#   - laboratory/<folder>/variables.pkr.hcl
#   - laboratory/<folder>/template.pkr.hcl

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/templates/os-mappings.yaml"
TEMPLATES_DIR="${PROJECT_ROOT}/templates"

# Function to display error messages
error() {
    echo -e "${RED}ERROR: $*${NC}" >&2
    exit 1
}

# Function to display info messages
info() {
    echo -e "${BLUE}INFO: $*${NC}" >&2
}

# Function to display success messages
success() {
    echo -e "${GREEN}SUCCESS: $*${NC}" >&2
}

# Check arguments
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    error "Usage: $0 <folder> <os-type> [ami-id]\nExample: $0 sql-injection ubuntu-24\nExample: $0 sql-injection ubuntu-24 ami-0123456789abcdef0"
fi

FOLDER="$1"
OS_TYPE="$2"
CUSTOM_AMI_ID="${3:-}"  # Optional third parameter
LAB_DIR="${PROJECT_ROOT}/laboratory/${FOLDER}"

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    error "yq is not installed. Please install it: brew install yq"
fi

# Check if lab directory exists
if [ ! -d "$LAB_DIR" ]; then
    error "Laboratory directory not found: $LAB_DIR"
fi

# Check if OS type exists in config
OWNER=$(yq eval ".os_mappings.${OS_TYPE}.owner" "$CONFIG_FILE")
if [ "$OWNER" == "null" ] || [ -z "$OWNER" ]; then
    error "OS type '$OS_TYPE' not found in $CONFIG_FILE\nRun 'make list-os' to see available OS types"
fi

# Get OS configuration
OS_NAME=$(yq eval ".os_mappings.${OS_TYPE}.name" "$CONFIG_FILE")
SSH_USERNAME=$(yq eval ".os_mappings.${OS_TYPE}.ssh_username" "$CONFIG_FILE")
USER_DATA_TYPE=$(yq eval ".os_mappings.${OS_TYPE}.user_data_type" "$CONFIG_FILE")
COMMUNICATOR=$(yq eval ".os_mappings.${OS_TYPE}.communicator" "$CONFIG_FILE")

# Set default communicator if not specified
if [ "$COMMUNICATOR" == "null" ] || [ -z "$COMMUNICATOR" ]; then
    COMMUNICATOR="ssh"
fi

info "Generating Packer files for laboratory: $FOLDER"
info "  OS Type: $OS_TYPE ($OS_NAME)"
info "  SSH Username: $SSH_USERNAME"
info "  User Data Type: $USER_DATA_TYPE"
info "  Communicator: $COMMUNICATOR"

# Get AMI ID (use custom if provided, otherwise fetch latest)
if [ -n "$CUSTOM_AMI_ID" ]; then
    info "Using custom AMI ID: $CUSTOM_AMI_ID"
    SOURCE_AMI="$CUSTOM_AMI_ID"
else
    info "Fetching latest AMI for $OS_TYPE..."
    SOURCE_AMI=$("${SCRIPT_DIR}/get-latest-ami.sh" "$OS_TYPE" 2>/dev/null | tail -n 1)

    if [ -z "$SOURCE_AMI" ]; then
        error "Failed to fetch latest AMI for $OS_TYPE"
    fi

    info "Source AMI: $SOURCE_AMI"
fi

# Get AMI name from AWS
info "Fetching AMI name..."
SOURCE_AMI_NAME=$(aws ec2 describe-images --image-ids "$SOURCE_AMI" --query 'Images[0].Name' --output text 2>/dev/null || echo "unknown")
if [ -z "$SOURCE_AMI_NAME" ] || [ "$SOURCE_AMI_NAME" == "None" ]; then
    SOURCE_AMI_NAME="unknown"
fi
info "Source AMI Name: $SOURCE_AMI_NAME"

# Get git short hash (if in git repo)
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_HASH=$(git rev-parse --short=7 HEAD 2>/dev/null || echo "unknown")
else
    GIT_HASH="unknown"
fi

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TIMESTAMP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Generate variables.pkr.hcl
info "Generating variables.pkr.hcl..."
cat "${TEMPLATES_DIR}/variables.pkr.hcl.tpl" | \
    sed "s|{{LAB_NAME}}|${FOLDER}|g" | \
    sed "s|{{OS_TYPE}}|${OS_TYPE}|g" | \
    sed "s|{{SOURCE_AMI}}|${SOURCE_AMI}|g" | \
    sed "s|{{SOURCE_AMI_NAME}}|${SOURCE_AMI_NAME}|g" \
    > "${LAB_DIR}/variables.pkr.hcl"

success "Created: ${LAB_DIR}/variables.pkr.hcl"

# Generate template.pkr.hcl
info "Generating template.pkr.hcl..."

# Determine provisioner script extension and template to use
if [ "$USER_DATA_TYPE" == "powershell" ]; then
    USERDATA_SCRIPT="userdata.ps1"
    TEMPLATE_FILE="${TEMPLATES_DIR}/template-windows.pkr.hcl.tpl"
    info "Using Windows template (PowerShell)"
else
    USERDATA_SCRIPT="userdata.sh"
    TEMPLATE_FILE="${TEMPLATES_DIR}/template-linux.pkr.hcl.tpl"
    info "Using Linux template (Shell)"
fi

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    error "Template file not found: $TEMPLATE_FILE"
fi

# Generate template using sed for simple replacements first
cat "$TEMPLATE_FILE" | \
    sed "s|{{LAB_NAME}}|${FOLDER}|g" | \
    sed "s|{{OS_TYPE}}|${OS_TYPE}|g" | \
    sed "s|{{TIMESTAMP}}|${TIMESTAMP}|g" | \
    sed "s|{{TIMESTAMP_ISO}}|${TIMESTAMP_ISO}|g" | \
    sed "s|{{GIT_HASH}}|${GIT_HASH}|g" | \
    sed "s|{{SSH_USER}}|${SSH_USERNAME}|g" | \
    sed "s|{{USERDATA_SCRIPT}}|${USERDATA_SCRIPT}|g" > "${LAB_DIR}/template.pkr.hcl.tmp"

# Now handle the COMMUNICATOR_CONFIG replacement using awk
if [ "$COMMUNICATOR" == "winrm" ]; then
    awk -v user="${SSH_USERNAME}" '
        /{{COMMUNICATOR_CONFIG}}/ {
            print "  communicator = \"winrm\""
            print "  winrm_username = \"" user "\""
            print "  winrm_insecure = true"
            print "  winrm_use_ssl = true"
            print "  winrm_timeout = \"15m\""
            next
        }
        { print }
    ' "${LAB_DIR}/template.pkr.hcl.tmp" > "${LAB_DIR}/template.pkr.hcl"
else
    sed "s|{{COMMUNICATOR_CONFIG}}|  ssh_username = \"${SSH_USERNAME}\"|g" \
        "${LAB_DIR}/template.pkr.hcl.tmp" > "${LAB_DIR}/template.pkr.hcl"
fi

# Clean up temp file
rm -f "${LAB_DIR}/template.pkr.hcl.tmp"

success "Created: ${LAB_DIR}/template.pkr.hcl"

# Display summary
echo ""
info "Generated files for laboratory: $FOLDER"
info "  variables.pkr.hcl: ✅"
info "  template.pkr.hcl: ✅"
echo ""
info "Next steps:"
info "  1. Edit ${LAB_DIR}/${USERDATA_SCRIPT} with your setup commands"
info "  2. Add build files to ${LAB_DIR}/build-files/"
info "  3. Run: make validate FOLDER=${FOLDER}"
info "  4. Run: make build-ami FOLDER=${FOLDER} OS=${OS_TYPE}"
echo ""

success "File generation completed!"
