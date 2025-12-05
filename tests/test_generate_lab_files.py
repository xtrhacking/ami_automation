"""
Unit tests for generate_lab_files.py
"""

import subprocess
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock
from datetime import datetime

import pytest
import yaml

# Add scripts directory to path
SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from generate_lab_files import (
    check_command_exists,
    load_os_config,
    get_ami_name,
    get_git_hash,
    generate_communicator_config,
    generate_variables_file,
    generate_template_file,
    Colors
)


class TestColors:
    """Test color constants."""

    def test_colors_defined(self):
        """Test that all color constants are defined."""
        assert hasattr(Colors, 'RED')
        assert hasattr(Colors, 'GREEN')
        assert hasattr(Colors, 'YELLOW')
        assert hasattr(Colors, 'BLUE')
        assert hasattr(Colors, 'NC')


class TestCheckCommandExists:
    """Tests for check_command_exists function."""

    def test_existing_command(self):
        """Test that existing commands return True."""
        assert check_command_exists("python3") is True

    def test_nonexistent_command(self):
        """Test that non-existent commands return False."""
        assert check_command_exists("nonexistent_command_xyz") is False


class TestLoadOsConfig:
    """Tests for load_os_config function."""

    def test_load_valid_config(self, config_file):
        """Test loading a valid OS configuration."""
        config = load_os_config(config_file, "ubuntu-24")
        assert config['name'] == 'Ubuntu 24.04 LTS'
        assert config['owner'] == '099720109477'

    def test_nonexistent_os_type(self, config_file):
        """Test that non-existent OS type raises SystemExit."""
        with pytest.raises(SystemExit):
            load_os_config(config_file, "nonexistent-os")


class TestGetAmiName:
    """Tests for get_ami_name function."""

    @patch('subprocess.run')
    def test_successful_ami_name_lookup(self, mock_run):
        """Test successful AMI name lookup."""
        mock_run.return_value = MagicMock(
            stdout="ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20240101\n",
            returncode=0
        )

        result = get_ami_name("ami-0123456789abcdef0")
        assert result == "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20240101"

    @patch('subprocess.run')
    def test_ami_name_not_found(self, mock_run):
        """Test AMI name lookup when AMI not found."""
        mock_run.return_value = MagicMock(
            stdout="None\n",
            returncode=0
        )

        result = get_ami_name("ami-invalid")
        assert result == "unknown"

    @patch('subprocess.run')
    def test_ami_name_aws_error(self, mock_run):
        """Test AMI name lookup when AWS returns error."""
        mock_run.side_effect = subprocess.CalledProcessError(1, 'aws')

        result = get_ami_name("ami-invalid")
        assert result == "unknown"


class TestGetGitHash:
    """Tests for get_git_hash function."""

    @patch('subprocess.run')
    def test_successful_git_hash(self, mock_run):
        """Test successful git hash retrieval."""
        mock_run.return_value = MagicMock(
            stdout="abc1234\n",
            returncode=0
        )

        result = get_git_hash()
        assert result == "abc1234"

    @patch('subprocess.run')
    def test_git_not_available(self, mock_run):
        """Test git hash when git is not available."""
        mock_run.side_effect = subprocess.CalledProcessError(1, 'git')

        result = get_git_hash()
        assert result == "unknown"


class TestGenerateCommunicatorConfig:
    """Tests for generate_communicator_config function."""

    def test_ssh_communicator(self):
        """Test SSH communicator configuration."""
        result = generate_communicator_config("ssh", "ubuntu")
        assert 'ssh_username = "ubuntu"' in result
        assert "winrm" not in result

    def test_winrm_communicator(self):
        """Test WinRM communicator configuration."""
        result = generate_communicator_config("winrm", "Administrator")
        assert 'communicator = "winrm"' in result
        assert 'winrm_username = "Administrator"' in result
        assert 'winrm_insecure = true' in result
        assert 'winrm_use_ssl = true' in result
        assert 'winrm_timeout = "30m"' in result

    def test_default_is_ssh(self):
        """Test that default communicator is SSH."""
        result = generate_communicator_config("", "ec2-user")
        assert 'ssh_username = "ec2-user"' in result


class TestGenerateVariablesFile:
    """Tests for generate_variables_file function."""

    def test_generate_variables(self, temp_dir):
        """Test generating variables file from template."""
        template_path = temp_dir / "template.tpl"
        output_path = temp_dir / "output.hcl"

        template_path.write_text('''variable "lab_name" {
  default = "{{LAB_NAME}}"
}

variable "os_type" {
  default = "{{OS_TYPE}}"
}

variable "source_ami" {
  default = "{{SOURCE_AMI}}"
}
''')

        replacements = {
            'LAB_NAME': 'test-lab',
            'OS_TYPE': 'ubuntu-24',
            'SOURCE_AMI': 'ami-0123456789abcdef0',
        }

        generate_variables_file(template_path, output_path, replacements)

        content = output_path.read_text()
        assert 'default = "test-lab"' in content
        assert 'default = "ubuntu-24"' in content
        assert 'default = "ami-0123456789abcdef0"' in content
        assert '{{' not in content  # No unreplaced placeholders

    def test_all_placeholders_replaced(self, temp_dir):
        """Test that all placeholders are replaced."""
        template_path = temp_dir / "template.tpl"
        output_path = temp_dir / "output.hcl"

        template_path.write_text('{{LAB_NAME}} {{OS_TYPE}} {{SOURCE_AMI}} {{SOURCE_AMI_NAME}}')

        replacements = {
            'LAB_NAME': 'my-lab',
            'OS_TYPE': 'amazon-linux-2023',
            'SOURCE_AMI': 'ami-test',
            'SOURCE_AMI_NAME': 'amazon-linux-2023-ami',
        }

        generate_variables_file(template_path, output_path, replacements)

        content = output_path.read_text()
        assert content == 'my-lab amazon-linux-2023 ami-test amazon-linux-2023-ami'


class TestGenerateTemplateFile:
    """Tests for generate_template_file function."""

    def test_generate_linux_template(self, temp_dir):
        """Test generating Linux template file."""
        template_path = temp_dir / "template.tpl"
        output_path = temp_dir / "output.hcl"

        template_path.write_text('''# Lab: {{LAB_NAME}}
# OS: {{OS_TYPE}}
source "amazon-ebs" "{{LAB_NAME}}" {
  {{COMMUNICATOR_CONFIG}}
}

provisioner "shell" {
  script = "{{USERDATA_SCRIPT}}"
}
''')

        replacements = {
            'LAB_NAME': 'test-lab',
            'OS_TYPE': 'ubuntu-24',
            'USERDATA_SCRIPT': 'userdata.sh',
        }

        communicator_config = '  ssh_username = "ubuntu"'

        generate_template_file(template_path, output_path, replacements, communicator_config)

        content = output_path.read_text()
        assert '# Lab: test-lab' in content
        assert '# OS: ubuntu-24' in content
        assert 'ssh_username = "ubuntu"' in content
        assert 'script = "userdata.sh"' in content

    def test_generate_windows_template(self, temp_dir):
        """Test generating Windows template file."""
        template_path = temp_dir / "template.tpl"
        output_path = temp_dir / "output.hcl"

        template_path.write_text('''source "amazon-ebs" "{{LAB_NAME}}" {
  {{COMMUNICATOR_CONFIG}}
}
''')

        replacements = {
            'LAB_NAME': 'windows-lab',
        }

        communicator_config = '''  communicator = "winrm"
  winrm_username = "Administrator"'''

        generate_template_file(template_path, output_path, replacements, communicator_config)

        content = output_path.read_text()
        assert 'communicator = "winrm"' in content
        assert 'winrm_username = "Administrator"' in content


class TestIntegration:
    """Integration tests."""

    def test_full_file_generation(self, project_structure):
        """Test full file generation workflow."""
        templates_dir = project_structure / "templates"
        lab_dir = project_structure / "laboratory" / "test-lab"

        # Read template
        template_path = templates_dir / "variables.pkr.hcl.tpl"
        output_path = lab_dir / "variables.pkr.hcl"

        replacements = {
            'LAB_NAME': 'test-lab',
            'OS_TYPE': 'ubuntu-24',
            'SOURCE_AMI': 'ami-test123',
            'SOURCE_AMI_NAME': 'ubuntu-24-test',
        }

        generate_variables_file(template_path, output_path, replacements)

        assert output_path.exists()
        content = output_path.read_text()
        assert 'test-lab' in content
        assert 'ubuntu-24' in content
        assert 'ami-test123' in content

    def test_linux_template_integration(self, project_structure):
        """Test Linux template generation integration."""
        templates_dir = project_structure / "templates"
        lab_dir = project_structure / "laboratory" / "test-lab"

        template_path = templates_dir / "template-linux.pkr.hcl.tpl"
        output_path = lab_dir / "template.pkr.hcl"

        replacements = {
            'LAB_NAME': 'test-lab',
            'OS_TYPE': 'ubuntu-24',
            'TIMESTAMP_ISO': '2024-01-01T00:00:00Z',
            'GIT_HASH': 'abc1234',
            'SOURCE_AMI': 'ami-test123',
            'USERDATA_SCRIPT': 'userdata.sh',
        }

        communicator_config = '  ssh_username = "ubuntu"'

        generate_template_file(template_path, output_path, replacements, communicator_config)

        assert output_path.exists()
        content = output_path.read_text()
        assert 'test-lab' in content
        assert 'ubuntu-24' in content
        assert 'ssh_username = "ubuntu"' in content
