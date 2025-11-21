#!/bin/bash
#
# add-os-mapping.sh - Adds a new OS mapping to config/os-mappings.yaml
#
# Usage: ./add-os-mapping.sh <os-key>
# Example: ./add-os-mapping.sh ubuntu-26
#
# Interactively prompts for OS configuration details

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/templates/os-mappings.yaml"

# Function to display error messages
error() {
    echo -e "${RED}❌ ERROR: $*${NC}" >&2
    exit 1
}

# Function to display info messages
info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

# Function to display success messages
success() {
    echo -e "${GREEN}✅ $*${NC}"
}

# Function to display prompts
prompt() {
    echo -e "${CYAN}$*${NC}"
}

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    error "yq is not installed. Please install it: brew install yq"
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    error "AWS CLI is not installed. Please install it first."
fi

# Check arguments
if [ $# -ne 1 ]; then
    error "Usage: $0 <os-key>\nExample: $0 ubuntu-26"
fi

OS_KEY="$1"

# Validate OS key format (lowercase, alphanumeric and hyphens only)
if ! [[ "$OS_KEY" =~ ^[a-z0-9-]+$ ]]; then
    error "Invalid OS key format. Use lowercase letters, numbers, and hyphens only.\nExample: ubuntu-26, centos-8, windows-server-2025"
fi

# Check if OS key already exists
EXISTING=$(yq eval ".os_mappings.${OS_KEY}" "$CONFIG_FILE" 2>/dev/null || echo "null")
if [ "$EXISTING" != "null" ]; then
    error "OS mapping '$OS_KEY' already exists in $CONFIG_FILE"
fi

# Display header
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          Adding New OS Mapping Configuration                  ║${NC}"
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo ""
info "Creating OS mapping: ${YELLOW}${OS_KEY}${NC}"
echo ""

# Prompt for OS name
prompt "📋 Full OS name (e.g., Ubuntu 26.04 LTS, Windows Server 2025):"
read -r -p "   > " OS_NAME
if [ -z "$OS_NAME" ]; then
    error "OS name cannot be empty"
fi

# Prompt for AWS Owner ID
echo ""
prompt "🔑 AWS Owner ID (e.g., 099720109477 for Canonical, 'amazon' for AWS):"
info "   Common owners: amazon, 099720109477 (Canonical), 125523088429 (CentOS), 136693071363 (Debian)"
read -r -p "   > " OWNER
if [ -z "$OWNER" ]; then
    error "Owner ID cannot be empty"
fi

# Prompt for AMI filter
echo ""
prompt "🔍 AMI name filter (e.g., ubuntu/images/hvm-ssd-gp3/ubuntu-*-26.04-amd64-server-*):"
info "   Use wildcards (*) to match AMI naming patterns"
read -r -p "   > " FILTER
if [ -z "$FILTER" ]; then
    error "Filter cannot be empty"
fi

# Prompt for user data type
echo ""
prompt "📝 User data type [shell/powershell] (default: shell):"
read -r -p "   > " USER_DATA_TYPE
USER_DATA_TYPE="${USER_DATA_TYPE:-shell}"

if [ "$USER_DATA_TYPE" != "shell" ] && [ "$USER_DATA_TYPE" != "powershell" ]; then
    error "Invalid user data type. Must be 'shell' or 'powershell'"
fi

# Prompt for SSH username
echo ""
prompt "👤 SSH username (e.g., ubuntu, admin, ec2-user, Administrator):"
info "   Common usernames: ubuntu, admin, ec2-user, centos, Administrator"
read -r -p "   > " SSH_USERNAME
if [ -z "$SSH_USERNAME" ]; then
    error "SSH username cannot be empty"
fi

# Prompt for communicator (optional for Windows)
COMMUNICATOR=""
if [ "$USER_DATA_TYPE" == "powershell" ]; then
    echo ""
    prompt "🔌 Communicator type [ssh/winrm] (default: winrm for Windows):"
    read -r -p "   > " COMMUNICATOR_INPUT
    COMMUNICATOR="${COMMUNICATOR_INPUT:-winrm}"
fi

# Display summary
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Summary of Configuration:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""
info "OS Key:          ${OS_KEY}"
info "OS Name:         ${OS_NAME}"
info "Owner ID:        ${OWNER}"
info "AMI Filter:      ${FILTER}"
info "User Data Type:  ${USER_DATA_TYPE}"
info "SSH Username:    ${SSH_USERNAME}"
if [ -n "$COMMUNICATOR" ]; then
    info "Communicator:    ${COMMUNICATOR}"
fi
echo ""

# Test AMI lookup
info "Testing AMI lookup with provided configuration..."
echo ""

AMI_TEST=$(aws ec2 describe-images \
    --owners "$OWNER" \
    --filters "Name=name,Values=$FILTER" "Name=state,Values=available" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].[ImageId,Name]' \
    --output text 2>&1 || echo "ERROR")

if [[ "$AMI_TEST" == *"ERROR"* ]] || [ -z "$AMI_TEST" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Could not find any AMIs matching this configuration${NC}"
    echo -e "${YELLOW}   This might be normal if the AMI doesn't exist yet.${NC}"
    echo ""
    prompt "Do you want to continue anyway? [y/N]:"
    read -r -p "   > " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        error "Operation cancelled by user"
    fi
else
    AMI_ID=$(echo "$AMI_TEST" | awk '{print $1}')
    AMI_NAME=$(echo "$AMI_TEST" | awk '{$1=""; print $0}' | sed 's/^ *//')
    success "Found matching AMI:"
    info "   AMI ID:   ${AMI_ID}"
    info "   AMI Name: ${AMI_NAME}"
fi

echo ""
prompt "Confirm adding this OS mapping to configuration? [Y/n]:"
read -r -p "   > " CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    error "Operation cancelled by user"
fi

# Add to YAML file using yq
info "Adding OS mapping to $CONFIG_FILE..."

# Build yq command
yq eval -i ".os_mappings.${OS_KEY}.name = \"${OS_NAME}\"" "$CONFIG_FILE"
yq eval -i ".os_mappings.${OS_KEY}.owner = \"${OWNER}\"" "$CONFIG_FILE"
yq eval -i ".os_mappings.${OS_KEY}.filter = \"${FILTER}\"" "$CONFIG_FILE"
yq eval -i ".os_mappings.${OS_KEY}.user_data_type = \"${USER_DATA_TYPE}\"" "$CONFIG_FILE"
yq eval -i ".os_mappings.${OS_KEY}.ssh_username = \"${SSH_USERNAME}\"" "$CONFIG_FILE"

if [ -n "$COMMUNICATOR" ]; then
    yq eval -i ".os_mappings.${OS_KEY}.communicator = \"${COMMUNICATOR}\"" "$CONFIG_FILE"
fi

echo ""
success "OS mapping '${OS_KEY}' added successfully!"
echo ""
info "Configuration saved to: $CONFIG_FILE"
echo ""
info "Next steps:"
info "  1. Verify the configuration: make list-os"
info "  2. Create a test lab: make init-lab FOLDER=test-${OS_KEY} OS=${OS_KEY}"
info "  3. Test AMI lookup: ./scripts/get-latest-ami.sh ${OS_KEY}"
echo ""
success "Done! 🎉"
echo ""
