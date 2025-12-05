"""
Pytest configuration and shared fixtures for AMI Automation tests.
"""

import os
import sys
import tempfile
from pathlib import Path
from typing import Dict, Any

import pytest
import yaml

# Add scripts directory to path for imports
SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))


@pytest.fixture
def temp_dir():
    """Create a temporary directory for test files."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def sample_os_mappings() -> Dict[str, Any]:
    """Sample OS mappings configuration for testing."""
    return {
        'os_mappings': {
            'ubuntu-24': {
                'name': 'Ubuntu 24.04 LTS',
                'owner': '099720109477',
                'filter': 'ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*',
                'user_data_type': 'shell',
                'ssh_username': 'ubuntu'
            },
            'ubuntu-22': {
                'name': 'Ubuntu 22.04 LTS',
                'owner': '099720109477',
                'filter': 'ubuntu/images/hvm-ssd-gp3/ubuntu-jammy-22.04-amd64-server-*',
                'user_data_type': 'shell',
                'ssh_username': 'ubuntu'
            },
            'windows-server-2022': {
                'name': 'Windows Server 2022 Base',
                'owner': 'amazon',
                'filter': 'Windows_Server-2022-English-Full-Base-*',
                'user_data_type': 'powershell',
                'ssh_username': 'Administrator',
                'communicator': 'winrm'
            },
            'amazon-linux-2023': {
                'name': 'Amazon Linux 2023',
                'owner': 'amazon',
                'filter': 'al2023-ami-*-x86_64',
                'user_data_type': 'shell',
                'ssh_username': 'ec2-user'
            }
        }
    }


@pytest.fixture
def config_file(temp_dir, sample_os_mappings):
    """Create a temporary config file with sample OS mappings."""
    config_path = temp_dir / "templates" / "os-mappings.yaml"
    config_path.parent.mkdir(parents=True, exist_ok=True)

    with open(config_path, 'w') as f:
        yaml.dump(sample_os_mappings, f)

    return config_path


@pytest.fixture
def project_structure(temp_dir, sample_os_mappings):
    """Create a mock project structure for testing."""
    # Create directories
    (temp_dir / "scripts").mkdir(parents=True, exist_ok=True)
    (temp_dir / "templates").mkdir(parents=True, exist_ok=True)
    (temp_dir / "laboratory" / "test-lab" / "build-files").mkdir(parents=True, exist_ok=True)

    # Create config file
    config_path = temp_dir / "templates" / "os-mappings.yaml"
    with open(config_path, 'w') as f:
        yaml.dump(sample_os_mappings, f)

    # Create variables template
    variables_template = temp_dir / "templates" / "variables.pkr.hcl.tpl"
    variables_template.write_text('''# Auto-generated variables file for {{LAB_NAME}}
variable "lab_name" {
  type        = string
  default     = "{{LAB_NAME}}"
}

variable "os_type" {
  type        = string
  default     = "{{OS_TYPE}}"
}

variable "source_ami" {
  type        = string
  default     = "{{SOURCE_AMI}}"
}

variable "source_ami_name" {
  type        = string
  default     = "{{SOURCE_AMI_NAME}}"
}
''')

    # Create Linux template
    linux_template = temp_dir / "templates" / "template-linux.pkr.hcl.tpl"
    linux_template.write_text('''# Auto-generated Packer template for {{LAB_NAME}}
# Generated at: {{TIMESTAMP_ISO}}
# Lab: {{LAB_NAME}}
# OS: {{OS_TYPE}}
# Git Hash: {{GIT_HASH}}

packer {
  required_version = ">= 1.8.0"
}

source "amazon-ebs" "{{LAB_NAME}}" {
  ami_name      = "lab-{{LAB_NAME}}"
  source_ami    = "{{SOURCE_AMI}}"
  {{COMMUNICATOR_CONFIG}}
}

build {
  sources = ["source.amazon-ebs.{{LAB_NAME}}"]

  provisioner "shell" {
    script = "${path.root}/{{USERDATA_SCRIPT}}"
  }
}
''')

    # Create userdata.sh
    userdata = temp_dir / "laboratory" / "test-lab" / "userdata.sh"
    userdata.write_text('''#!/bin/bash
echo "Test lab setup"
''')

    return temp_dir


@pytest.fixture
def mock_aws_ami_response():
    """Mock AWS AMI response data."""
    return {
        'ImageId': 'ami-0123456789abcdef0',
        'Name': 'ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20240101',
        'CreationDate': '2024-01-01T00:00:00.000Z',
        'Description': 'Ubuntu 24.04 LTS'
    }
