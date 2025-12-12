#!/usr/bin/env python3
"""
generate_lab_files.py - Generates Packer HCL files from templates

Usage: python generate_lab_files.py <folder> <os-type> [ami-id]
Example: python generate_lab_files.py sql-injection ubuntu-24
         python generate_lab_files.py sql-injection ubuntu-24 ami-0123456789abcdef0

Generates:
  - laboratory/<folder>/variables.pkr.hcl
  - laboratory/<folder>/template.pkr.hcl
"""

import sys
import subprocess
import json
from pathlib import Path
from datetime import datetime, timezone
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


def get_latest_ami(script_dir: Path, os_type: str) -> str:
    """Get the latest AMI ID using the get_latest_ami.py script."""
    get_ami_script = script_dir / "get_latest_ami.py"

    try:
        result = subprocess.run(
            ["python3", str(get_ami_script), os_type],
            capture_output=True,
            text=True,
            check=True
        )
        # Get the last non-empty line (AMI ID)
        lines = [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]
        if lines:
            return lines[-1]
        error(f"Failed to fetch latest AMI for {os_type}")
    except subprocess.CalledProcessError as e:
        error(f"Failed to fetch latest AMI for {os_type}:\n{e.stderr}")

    return ""


def get_ami_name(ami_id: str) -> str:
    """Get AMI name from AWS."""
    try:
        result = subprocess.run(
            [
                "aws", "ec2", "describe-images",
                "--image-ids", ami_id,
                "--query", "Images[0].Name",
                "--output", "text"
            ],
            capture_output=True,
            text=True,
            check=True
        )
        name = result.stdout.strip()
        if name and name != "None":
            return name
    except subprocess.CalledProcessError:
        pass

    return "unknown"


def get_git_hash() -> str:
    """Get the current git short hash."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short=7", "HEAD"],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return "unknown"


def generate_communicator_config(communicator: str, ssh_username: str) -> str:
    """Generate the communicator configuration block."""
    if communicator == "winrm":
        return f'''  communicator = "winrm"
  winrm_username = "{ssh_username}"
  winrm_port = 5986
  winrm_insecure = true
  winrm_use_ssl = true
  winrm_timeout = "10m"

  # Additional WinRM settings for better reliability
  winrm_use_ntlm = true'''
    else:
        return f'  ssh_username = "{ssh_username}"'


def generate_variables_file(
    template_path: Path,
    output_path: Path,
    replacements: Dict[str, str]
) -> None:
    """Generate variables.pkr.hcl from template."""
    with open(template_path, 'r') as f:
        content = f.read()

    for key, value in replacements.items():
        content = content.replace(f"{{{{{key}}}}}", value)

    with open(output_path, 'w') as f:
        f.write(content)


def generate_template_file(
    template_path: Path,
    output_path: Path,
    replacements: Dict[str, str],
    communicator_config: str
) -> None:
    """Generate template.pkr.hcl from template."""
    with open(template_path, 'r') as f:
        content = f.read()

    for key, value in replacements.items():
        content = content.replace(f"{{{{{key}}}}}", value)

    # Handle COMMUNICATOR_CONFIG replacement
    content = content.replace("{{COMMUNICATOR_CONFIG}}", communicator_config)

    with open(output_path, 'w') as f:
        f.write(content)


def main() -> None:
    """Main function."""
    # Check arguments
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        error(
            f"Usage: {sys.argv[0]} <folder> <os-type> [ami-id]\n"
            f"Example: {sys.argv[0]} sql-injection ubuntu-24\n"
            f"Example: {sys.argv[0]} sql-injection ubuntu-24 ami-0123456789abcdef0"
        )

    folder = sys.argv[1]
    os_type = sys.argv[2]
    custom_ami_id = sys.argv[3] if len(sys.argv) == 4 else None

    # Check if yq is installed (for compatibility check, though we use Python yaml)
    if not check_command_exists("aws"):
        error("AWS CLI is not installed. Please install it first.")

    # Get paths
    script_dir = Path(__file__).parent.resolve()
    project_root = script_dir.parent
    config_file = project_root / "templates" / "os-mappings.yaml"
    templates_dir = project_root / "templates"
    lab_dir = project_root / "laboratory" / folder

    # Check if lab directory exists
    if not lab_dir.exists():
        error(f"Laboratory directory not found: {lab_dir}")

    # Load OS configuration
    os_config = load_os_config(config_file, os_type)
    os_name = os_config.get('name', 'Unknown')
    ssh_username = os_config.get('ssh_username', 'ubuntu')
    user_data_type = os_config.get('user_data_type', 'shell')
    communicator = os_config.get('communicator', 'ssh')

    info(f"Generating Packer files for laboratory: {folder}")
    info(f"  OS Type: {os_type} ({os_name})")
    info(f"  SSH Username: {ssh_username}")
    info(f"  User Data Type: {user_data_type}")
    info(f"  Communicator: {communicator}")

    # Get AMI ID
    if custom_ami_id:
        info(f"Using custom AMI ID: {custom_ami_id}")
        source_ami = custom_ami_id
    else:
        info(f"Fetching latest AMI for {os_type}...")
        source_ami = get_latest_ami(script_dir, os_type)
        if not source_ami:
            error(f"Failed to fetch latest AMI for {os_type}")
        info(f"Source AMI: {source_ami}")

    # Get AMI name
    info("Fetching AMI name...")
    source_ami_name = get_ami_name(source_ami)
    info(f"Source AMI Name: {source_ami_name}")

    # Get git hash
    git_hash = get_git_hash()

    # Generate timestamps
    now = datetime.now()
    timestamp = now.strftime("%Y%m%d-%H%M%S")
    timestamp_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # Determine userdata script
    if user_data_type == "powershell":
        userdata_script = "userdata.ps1"
        template_file = templates_dir / "template-windows.pkr.hcl.tpl"
        info("Using Windows template (PowerShell)")
    else:
        userdata_script = "userdata.sh"
        template_file = templates_dir / "template-linux.pkr.hcl.tpl"
        info("Using Linux template (Shell)")

    # Check if template exists
    if not template_file.exists():
        error(f"Template file not found: {template_file}")

    # Prepare replacements
    replacements = {
        'LAB_NAME': folder,
        'OS_TYPE': os_type,
        'SOURCE_AMI': source_ami,
        'SOURCE_AMI_NAME': source_ami_name,
        'TIMESTAMP': timestamp,
        'TIMESTAMP_ISO': timestamp_iso,
        'GIT_HASH': git_hash,
        'SSH_USER': ssh_username,
        'USERDATA_SCRIPT': userdata_script,
    }

    # Generate variables.pkr.hcl
    info("Generating variables.pkr.hcl...")
    variables_template = templates_dir / "variables.pkr.hcl.tpl"
    variables_output = lab_dir / "variables.pkr.hcl"
    generate_variables_file(variables_template, variables_output, replacements)
    success(f"Created: {variables_output}")

    # Generate template.pkr.hcl
    info("Generating template.pkr.hcl...")
    communicator_config = generate_communicator_config(communicator, ssh_username)
    template_output = lab_dir / "template.pkr.hcl"
    generate_template_file(template_file, template_output, replacements, communicator_config)
    success(f"Created: {template_output}")

    # Display summary
    print("", file=sys.stderr)
    info(f"Generated files for laboratory: {folder}")
    info("  variables.pkr.hcl: ✅")
    info("  template.pkr.hcl: ✅")
    print("", file=sys.stderr)
    info("Next steps:")
    info(f"  1. Edit {lab_dir}/{userdata_script} with your setup commands")
    info(f"  2. Add build files to {lab_dir}/build-files/")
    info(f"  3. Run: make validate FOLDER={folder}")
    info(f"  4. Run: make build-ami FOLDER={folder} OS={os_type}")
    print("", file=sys.stderr)

    success("File generation completed!")


if __name__ == "__main__":
    main()
