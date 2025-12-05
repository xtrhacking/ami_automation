#!/usr/bin/env python3
"""
add_os_mapping.py - Adds a new OS mapping to templates/os-mappings.yaml

Usage: python add_os_mapping.py <os-key>
Example: python add_os_mapping.py ubuntu-26

Interactively prompts for OS configuration details
"""

import sys
import subprocess
import re
import json
from pathlib import Path
from typing import Dict, Any, Optional

import yaml

# Colors for output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color


def error(message: str) -> None:
    """Display error message and exit."""
    print(f"{Colors.RED}❌ ERROR: {message}{Colors.NC}", file=sys.stderr)
    sys.exit(1)


def info(message: str) -> None:
    """Display info message."""
    print(f"{Colors.BLUE}ℹ️  {message}{Colors.NC}")


def success(message: str) -> None:
    """Display success message."""
    print(f"{Colors.GREEN}✅ {message}{Colors.NC}")


def prompt(message: str) -> None:
    """Display prompt message."""
    print(f"{Colors.CYAN}{message}{Colors.NC}")


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


def validate_os_key(os_key: str) -> bool:
    """Validate OS key format (lowercase, alphanumeric and hyphens only)."""
    return bool(re.match(r'^[a-z0-9-]+$', os_key))


def load_config(config_file: Path) -> Dict[str, Any]:
    """Load configuration from YAML file."""
    if not config_file.exists():
        error(f"Config file not found: {config_file}")

    with open(config_file, 'r') as f:
        return yaml.safe_load(f) or {}


def save_config(config_file: Path, config: Dict[str, Any]) -> None:
    """Save configuration to YAML file."""
    with open(config_file, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)


def lookup_ami(owner: str, ami_filter: str) -> Optional[Dict[str, str]]:
    """Test AMI lookup with provided configuration."""
    try:
        result = subprocess.run(
            [
                "aws", "ec2", "describe-images",
                "--owners", owner,
                "--filters", f"Name=name,Values={ami_filter}", "Name=state,Values=available",
                "--query", "Images | sort_by(@, &CreationDate) | [-1].[ImageId,Name]",
                "--output", "text"
            ],
            capture_output=True,
            text=True,
            check=True
        )

        output = result.stdout.strip()
        if not output or output == "None":
            return None

        parts = output.split('\t')
        if len(parts) >= 2:
            return {
                'ami_id': parts[0],
                'ami_name': parts[1] if len(parts) > 1 else 'unknown'
            }
    except subprocess.CalledProcessError:
        return None

    return None


def get_input(prompt_text: str, default: str = None, required: bool = True) -> str:
    """Get user input with optional default value."""
    if default:
        prompt_with_default = f"{prompt_text} [{default}]: "
    else:
        prompt_with_default = f"{prompt_text}: "

    value = input(f"   > ").strip()

    if not value and default:
        return default
    elif not value and required:
        error(f"This field cannot be empty")

    return value


def main() -> None:
    """Main function."""
    # Check if AWS CLI is installed
    if not check_command_exists("aws"):
        error("AWS CLI is not installed. Please install it first.")

    # Check arguments
    if len(sys.argv) != 2:
        error(f"Usage: {sys.argv[0]} <os-key>\nExample: {sys.argv[0]} ubuntu-26")

    os_key = sys.argv[1]

    # Validate OS key format
    if not validate_os_key(os_key):
        error(
            "Invalid OS key format. Use lowercase letters, numbers, and hyphens only.\n"
            "Example: ubuntu-26, centos-8, windows-server-2025"
        )

    # Get paths
    script_dir = Path(__file__).parent.resolve()
    project_root = script_dir.parent
    config_file = project_root / "templates" / "os-mappings.yaml"

    # Load existing configuration
    config = load_config(config_file)
    os_mappings = config.get('os_mappings', {})

    # Check if OS key already exists
    if os_key in os_mappings:
        error(f"OS mapping '{os_key}' already exists in {config_file}")

    # Display header
    print("")
    print(f"{Colors.CYAN}╔════════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.CYAN}║          Adding New OS Mapping Configuration                  ║{Colors.NC}")
    print(f"{Colors.CYAN}╔════════════════════════════════════════════════════════════════╝{Colors.NC}")
    print("")
    info(f"Creating OS mapping: {Colors.YELLOW}{os_key}{Colors.NC}")
    print("")

    # Prompt for OS name
    prompt("📋 Full OS name (e.g., Ubuntu 26.04 LTS, Windows Server 2025):")
    os_name = get_input("Full OS name")

    # Prompt for AWS Owner ID
    print("")
    prompt("🔑 AWS Owner ID (e.g., 099720109477 for Canonical, 'amazon' for AWS):")
    info("   Common owners: amazon, 099720109477 (Canonical), 125523088429 (CentOS), 136693071363 (Debian)")
    owner = get_input("Owner ID")

    # Prompt for AMI filter
    print("")
    prompt("🔍 AMI name filter (e.g., ubuntu/images/hvm-ssd-gp3/ubuntu-*-26.04-amd64-server-*):")
    info("   Use wildcards (*) to match AMI naming patterns")
    ami_filter = get_input("AMI filter")

    # Prompt for user data type
    print("")
    prompt("📝 User data type [shell/powershell] (default: shell):")
    user_data_type_input = input("   > ").strip()
    user_data_type = user_data_type_input if user_data_type_input else "shell"

    if user_data_type not in ("shell", "powershell"):
        error("Invalid user data type. Must be 'shell' or 'powershell'")

    # Prompt for SSH username
    print("")
    prompt("👤 SSH username (e.g., ubuntu, admin, ec2-user, Administrator):")
    info("   Common usernames: ubuntu, admin, ec2-user, centos, Administrator")
    ssh_username = get_input("SSH username")

    # Prompt for communicator (optional for Windows)
    communicator = None
    if user_data_type == "powershell":
        print("")
        prompt("🔌 Communicator type [ssh/winrm] (default: winrm for Windows):")
        communicator_input = input("   > ").strip()
        communicator = communicator_input if communicator_input else "winrm"

    # Display summary
    print("")
    print(f"{Colors.YELLOW}═══════════════════════════════════════════════════════════════{Colors.NC}")
    print(f"{Colors.YELLOW}Summary of Configuration:{Colors.NC}")
    print(f"{Colors.YELLOW}═══════════════════════════════════════════════════════════════{Colors.NC}")
    print("")
    info(f"OS Key:          {os_key}")
    info(f"OS Name:         {os_name}")
    info(f"Owner ID:        {owner}")
    info(f"AMI Filter:      {ami_filter}")
    info(f"User Data Type:  {user_data_type}")
    info(f"SSH Username:    {ssh_username}")
    if communicator:
        info(f"Communicator:    {communicator}")
    print("")

    # Test AMI lookup
    info("Testing AMI lookup with provided configuration...")
    print("")

    ami_result = lookup_ami(owner, ami_filter)

    if not ami_result:
        print(f"{Colors.YELLOW}⚠️  WARNING: Could not find any AMIs matching this configuration{Colors.NC}")
        print(f"{Colors.YELLOW}   This might be normal if the AMI doesn't exist yet.{Colors.NC}")
        print("")
        prompt("Do you want to continue anyway? [y/N]:")
        continue_choice = input("   > ").strip().lower()
        if continue_choice not in ('y', 'yes'):
            error("Operation cancelled by user")
    else:
        success("Found matching AMI:")
        info(f"   AMI ID:   {ami_result['ami_id']}")
        info(f"   AMI Name: {ami_result['ami_name']}")

    print("")
    prompt("Confirm adding this OS mapping to configuration? [Y/n]:")
    confirm = input("   > ").strip()
    if confirm.lower() not in ('', 'y', 'yes'):
        error("Operation cancelled by user")

    # Add to configuration
    info(f"Adding OS mapping to {config_file}...")

    new_mapping = {
        'name': os_name,
        'owner': owner,
        'filter': ami_filter,
        'user_data_type': user_data_type,
        'ssh_username': ssh_username,
    }

    if communicator:
        new_mapping['communicator'] = communicator

    os_mappings[os_key] = new_mapping
    config['os_mappings'] = os_mappings

    save_config(config_file, config)

    print("")
    success(f"OS mapping '{os_key}' added successfully!")
    print("")
    info(f"Configuration saved to: {config_file}")
    print("")
    info("Next steps:")
    info(f"  1. Verify the configuration: make list-os")
    info(f"  2. Create a test lab: make init-lab FOLDER=test-{os_key} OS={os_key}")
    info(f"  3. Test AMI lookup: python scripts/get_latest_ami.py {os_key}")
    print("")
    success("Done! 🎉")
    print("")


if __name__ == "__main__":
    main()
