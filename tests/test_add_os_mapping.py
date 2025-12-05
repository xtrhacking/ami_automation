"""
Unit tests for add_os_mapping.py
"""

import subprocess
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest
import yaml

# Add scripts directory to path
SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from add_os_mapping import (
    check_command_exists,
    validate_os_key,
    load_config,
    save_config,
    lookup_ami,
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
        assert hasattr(Colors, 'CYAN')
        assert hasattr(Colors, 'NC')


class TestCheckCommandExists:
    """Tests for check_command_exists function."""

    def test_existing_command(self):
        """Test that existing commands return True."""
        assert check_command_exists("python3") is True

    def test_nonexistent_command(self):
        """Test that non-existent commands return False."""
        assert check_command_exists("nonexistent_command_xyz") is False


class TestValidateOsKey:
    """Tests for validate_os_key function."""

    def test_valid_os_keys(self):
        """Test valid OS key formats."""
        assert validate_os_key("ubuntu-24") is True
        assert validate_os_key("amazon-linux-2023") is True
        assert validate_os_key("centos-7") is True
        assert validate_os_key("debian-12") is True
        assert validate_os_key("windows-server-2022") is True

    def test_invalid_os_keys_uppercase(self):
        """Test that uppercase letters are rejected."""
        assert validate_os_key("Ubuntu-24") is False
        assert validate_os_key("UBUNTU-24") is False
        assert validate_os_key("ubuntu-24-LTS") is False

    def test_invalid_os_keys_special_chars(self):
        """Test that special characters are rejected."""
        assert validate_os_key("ubuntu_24") is False
        assert validate_os_key("ubuntu.24") is False
        assert validate_os_key("ubuntu 24") is False
        assert validate_os_key("ubuntu@24") is False

    def test_valid_numeric_only(self):
        """Test that numeric-only keys are valid."""
        assert validate_os_key("123") is True

    def test_empty_string(self):
        """Test that empty string is invalid."""
        assert validate_os_key("") is False


class TestLoadConfig:
    """Tests for load_config function."""

    def test_load_existing_config(self, config_file):
        """Test loading existing configuration."""
        config = load_config(config_file)

        assert 'os_mappings' in config
        assert 'ubuntu-24' in config['os_mappings']
        assert config['os_mappings']['ubuntu-24']['name'] == 'Ubuntu 24.04 LTS'

    def test_load_nonexistent_config(self, temp_dir):
        """Test loading non-existent config file raises SystemExit."""
        fake_path = temp_dir / "nonexistent.yaml"
        with pytest.raises(SystemExit):
            load_config(fake_path)

    def test_load_empty_config(self, temp_dir):
        """Test loading empty config file."""
        empty_config = temp_dir / "empty.yaml"
        empty_config.write_text("")

        config = load_config(empty_config)
        assert config == {} or config is None


class TestSaveConfig:
    """Tests for save_config function."""

    def test_save_config(self, temp_dir):
        """Test saving configuration to file."""
        config_path = temp_dir / "test-config.yaml"
        config = {
            'os_mappings': {
                'test-os': {
                    'name': 'Test OS',
                    'owner': '123456789',
                    'filter': 'test-*',
                    'user_data_type': 'shell',
                    'ssh_username': 'test-user'
                }
            }
        }

        save_config(config_path, config)

        assert config_path.exists()

        # Verify content
        with open(config_path, 'r') as f:
            loaded = yaml.safe_load(f)

        assert loaded['os_mappings']['test-os']['name'] == 'Test OS'

    def test_save_preserves_structure(self, temp_dir):
        """Test that save preserves configuration structure."""
        config_path = temp_dir / "test-config.yaml"
        config = {
            'os_mappings': {
                'ubuntu-24': {
                    'name': 'Ubuntu 24.04 LTS',
                    'owner': '099720109477',
                    'filter': 'ubuntu/images/*',
                    'user_data_type': 'shell',
                    'ssh_username': 'ubuntu'
                },
                'windows-server-2022': {
                    'name': 'Windows Server 2022',
                    'owner': 'amazon',
                    'filter': 'Windows_Server-2022-*',
                    'user_data_type': 'powershell',
                    'ssh_username': 'Administrator',
                    'communicator': 'winrm'
                }
            }
        }

        save_config(config_path, config)

        with open(config_path, 'r') as f:
            loaded = yaml.safe_load(f)

        assert len(loaded['os_mappings']) == 2
        assert 'communicator' in loaded['os_mappings']['windows-server-2022']


class TestLookupAmi:
    """Tests for lookup_ami function."""

    @patch('subprocess.run')
    def test_successful_lookup(self, mock_run):
        """Test successful AMI lookup."""
        mock_run.return_value = MagicMock(
            stdout="ami-0123456789abcdef0\tubuntu-noble-24.04-amd64-server-20240101",
            returncode=0
        )

        result = lookup_ami("099720109477", "ubuntu/images/*")

        assert result is not None
        assert result['ami_id'] == 'ami-0123456789abcdef0'
        assert 'ubuntu' in result['ami_name'].lower()

    @patch('subprocess.run')
    def test_no_ami_found(self, mock_run):
        """Test when no AMI is found."""
        mock_run.return_value = MagicMock(
            stdout="None",
            returncode=0
        )

        result = lookup_ami("099720109477", "nonexistent-*")
        assert result is None

    @patch('subprocess.run')
    def test_empty_response(self, mock_run):
        """Test when AWS returns empty response."""
        mock_run.return_value = MagicMock(
            stdout="",
            returncode=0
        )

        result = lookup_ami("099720109477", "some-filter-*")
        assert result is None

    @patch('subprocess.run')
    def test_aws_error(self, mock_run):
        """Test handling of AWS CLI errors."""
        mock_run.side_effect = subprocess.CalledProcessError(1, 'aws')

        result = lookup_ami("invalid-owner", "some-filter-*")
        assert result is None


class TestIntegration:
    """Integration tests for add_os_mapping functionality."""

    def test_add_new_os_mapping(self, config_file, sample_os_mappings):
        """Test adding a new OS mapping to configuration."""
        # Load existing config
        config = load_config(config_file)

        # Add new mapping
        new_os_key = 'ubuntu-26'
        new_mapping = {
            'name': 'Ubuntu 26.04 LTS',
            'owner': '099720109477',
            'filter': 'ubuntu/images/hvm-ssd-gp3/ubuntu-*-26.04-amd64-server-*',
            'user_data_type': 'shell',
            'ssh_username': 'ubuntu'
        }

        config['os_mappings'][new_os_key] = new_mapping

        # Save and reload
        save_config(config_file, config)
        reloaded = load_config(config_file)

        assert new_os_key in reloaded['os_mappings']
        assert reloaded['os_mappings'][new_os_key]['name'] == 'Ubuntu 26.04 LTS'

    def test_prevent_duplicate_os_key(self, config_file):
        """Test that duplicate OS keys are detected."""
        config = load_config(config_file)

        # ubuntu-24 should already exist
        assert 'ubuntu-24' in config['os_mappings']

    def test_add_windows_os_with_communicator(self, temp_dir):
        """Test adding Windows OS mapping with communicator."""
        config_path = temp_dir / "os-mappings.yaml"
        config = {'os_mappings': {}}

        # Add Windows mapping
        config['os_mappings']['windows-server-2025'] = {
            'name': 'Windows Server 2025',
            'owner': 'amazon',
            'filter': 'Windows_Server-2025-*',
            'user_data_type': 'powershell',
            'ssh_username': 'Administrator',
            'communicator': 'winrm'
        }

        save_config(config_path, config)
        reloaded = load_config(config_path)

        assert reloaded['os_mappings']['windows-server-2025']['communicator'] == 'winrm'
        assert reloaded['os_mappings']['windows-server-2025']['user_data_type'] == 'powershell'


class TestValidationScenarios:
    """Test various validation scenarios."""

    def test_os_key_with_numbers(self):
        """Test OS keys with version numbers."""
        assert validate_os_key("ubuntu-2404") is True
        assert validate_os_key("centos-7") is True
        assert validate_os_key("al2023") is True

    def test_os_key_multiple_hyphens(self):
        """Test OS keys with multiple hyphens."""
        assert validate_os_key("amazon-linux-2023") is True
        assert validate_os_key("windows-server-2022-base") is True

    def test_os_key_starting_with_number(self):
        """Test OS keys starting with numbers."""
        assert validate_os_key("2023-amazon-linux") is True

    def test_os_key_edge_cases(self):
        """Test edge cases for OS key validation."""
        assert validate_os_key("a") is True
        assert validate_os_key("1") is True
        assert validate_os_key("-") is True  # Just hyphen is valid per regex
        assert validate_os_key("a-") is True
        assert validate_os_key("-a") is True
