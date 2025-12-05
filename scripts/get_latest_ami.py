#!/usr/bin/env python3
"""
get_latest_ami.py - Retrieves the latest AMI ID for a given OS type

Usage: python get_latest_ami.py <os-type>
Example: python get_latest_ami.py ubuntu-24

Returns: AMI ID on stdout, or exits with error code 1
"""

import sys
import subprocess
import json
from pathlib import Path
from typing import Optional, Dict, Any

import yaml

# Colors for output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color


def error(message: str) -> None:
    """Display error message and exit."""
    print(f"{Colors.RED}ERROR: {message}{Colors.NC}", file=sys.stderr)
    sys.exit(1)


def info(message: str) -> None:
    """Display info message."""
    print(f"{Colors.BLUE}INFO: {message}{Colors.NC}", file=sys.stderr)


def success(message: str) -> None:
    """Display success message."""
    print(f"{Colors.GREEN}SUCCESS: {message}{Colors.NC}", file=sys.stderr)


def check_command_exists(command: str) -> bool:
    """Check if a command exists in the system."""
    try:
        subprocess.run(
            ["which", command],
            capture_output=True,
            check=True
        )
        return True
    except subprocess.CalledProcessError:
        return False


def load_os_config(config_file: Path, os_type: str) -> Dict[str, Any]:
    """Load OS configuration from YAML file."""
    if not config_file.exists():
        error(f"Config file not found: {config_file}")

    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)

    os_mappings = config.get('os_mappings', {})

    if os_type not in os_mappings:
        error(f"OS type '{os_type}' not found in {config_file}\nRun 'make list-os' to see available OS types")

    return os_mappings[os_type]


def get_latest_ami(owner: str, ami_filter: str) -> Optional[Dict[str, str]]:
    """Query AWS for the latest AMI matching the filter."""
    try:
        result = subprocess.run(
            [
                "aws", "ec2", "describe-images",
                "--owners", owner,
                "--filters", f"Name=name,Values={ami_filter}", "Name=state,Values=available",
                "--query", "Images | sort_by(@, &CreationDate) | [-1]",
                "--output", "json"
            ],
            capture_output=True,
            text=True,
            check=True
        )

        if not result.stdout.strip() or result.stdout.strip() == "null":
            return None

        ami_data = json.loads(result.stdout)

        if not ami_data:
            return None

        return {
            'ami_id': ami_data.get('ImageId'),
            'name': ami_data.get('Name'),
            'creation_date': ami_data.get('CreationDate'),
            'description': ami_data.get('Description')
        }
    except subprocess.CalledProcessError as e:
        error(f"Failed to query AWS for AMI:\n{e.stderr}")
    except json.JSONDecodeError as e:
        error(f"Failed to parse AWS response: {e}")

    return None


def main() -> None:
    """Main function."""
    # Check arguments
    if len(sys.argv) != 2:
        error(f"Usage: {sys.argv[0]} <os-type>\nExample: {sys.argv[0]} ubuntu-24")

    os_type = sys.argv[1]

    # Check if AWS CLI is installed
    if not check_command_exists("aws"):
        error("AWS CLI is not installed. Please install it first.")

    # Get script directory and config file path
    script_dir = Path(__file__).parent.resolve()
    project_root = script_dir.parent
    config_file = project_root / "templates" / "os-mappings.yaml"

    # Read configuration
    info(f"Reading configuration for OS: {os_type}")
    os_config = load_os_config(config_file, os_type)

    owner = os_config.get('owner')
    ami_filter = os_config.get('filter')
    os_name = os_config.get('name')

    info("Searching for latest AMI:")
    info(f"  OS Name: {os_name}")
    info(f"  Owner: {owner}")
    info(f"  Filter: {ami_filter}")

    # Query AWS for the latest AMI
    ami_info = get_latest_ami(owner, ami_filter)

    if not ami_info or not ami_info.get('ami_id'):
        error(f"No AMI found for OS type '{os_type}' with filter '{ami_filter}'")

    # Display AMI information
    info("Found latest AMI:")
    info(f"  AMI ID: {ami_info['ami_id']}")
    info(f"  Name: {ami_info['name']}")
    info(f"  Created: {ami_info['creation_date']}")

    # Output only the AMI ID to stdout (for script consumption)
    print(ami_info['ami_id'])

    success("AMI lookup completed successfully")


if __name__ == "__main__":
    main()
