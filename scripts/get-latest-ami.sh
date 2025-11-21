#!/bin/bash
#
# get-latest-ami.sh - Retrieves the latest AMI ID for a given OS type
#
# Usage: ./get-latest-ami.sh <os-type>
# Example: ./get-latest-ami.sh ubuntu-24
#
# Returns: AMI ID on stdout, or exits with error code 1

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

# Check if OS type is provided
if [ $# -ne 1 ]; then
    error "Usage: $0 <os-type>\nExample: $0 ubuntu-24"
fi

OS_TYPE="$1"

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    error "yq is not installed. Please install it: brew install yq"
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    error "AWS CLI is not installed. Please install it first."
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    error "Config file not found: $CONFIG_FILE"
fi

# Read configuration from YAML
info "Reading configuration for OS: $OS_TYPE"

OWNER=$(yq eval ".os_mappings.${OS_TYPE}.owner" "$CONFIG_FILE")
FILTER=$(yq eval ".os_mappings.${OS_TYPE}.filter" "$CONFIG_FILE")
OS_NAME=$(yq eval ".os_mappings.${OS_TYPE}.name" "$CONFIG_FILE")

# Check if OS mapping exists
if [ "$OWNER" == "null" ] || [ -z "$OWNER" ]; then
    error "OS type '$OS_TYPE' not found in $CONFIG_FILE\nRun 'make list-os' to see available OS types"
fi

info "Searching for latest AMI:"
info "  OS Name: $OS_NAME"
info "  Owner: $OWNER"
info "  Filter: $FILTER"

# Query AWS for the latest AMI
AMI_INFO=$(aws ec2 describe-images \
    --owners "$OWNER" \
    --filters "Name=name,Values=$FILTER" "Name=state,Values=available" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].[ImageId,Name,CreationDate,Description]' \
    --output text 2>&1)

if [ $? -ne 0 ]; then
    error "Failed to query AWS for AMI:\n$AMI_INFO"
fi

# Parse the result
AMI_ID=$(echo "$AMI_INFO" | awk '{print $1}')
AMI_NAME=$(echo "$AMI_INFO" | awk '{$1=""; print $0}' | sed 's/^ *//' | cut -f1)
CREATION_DATE=$(echo "$AMI_INFO" | awk '{print $(NF-1), $NF}')

# Check if AMI was found
if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
    error "No AMI found for OS type '$OS_TYPE' with filter '$FILTER'"
fi

# Display AMI information
info "Found latest AMI:"
info "  AMI ID: $AMI_ID"
info "  Name: $AMI_NAME"
info "  Created: $CREATION_DATE"

# Output only the AMI ID to stdout (for script consumption)
echo "$AMI_ID"

success "AMI lookup completed successfully"
