"""
Unit tests for get_latest_ami.py
"""

import json
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest
import yaml

# Add scripts directory to path
SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from get_latest_ami import (
    check_command_exists,
    load_os_config,
    get_latest_ami,
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

    def test_colors_are_ansi_codes(self):
        """Test that colors are valid ANSI escape codes."""
        assert Colors.RED.startswith('\033[')
        assert Colors.GREEN.startswith('\033[')
        assert Colors.NC == '\033[0m'


class TestCheckCommandExists:
    """Tests for check_command_exists function."""

    def test_existing_command(self):
        """Test that existing commands return True."""
        # 'python3' should exist since we're running tests
        assert check_command_exists("python3") is True

    def test_nonexistent_command(self):
        """Test that non-existent commands return False."""
        assert check_command_exists("nonexistent_command_xyz") is False

    @patch('subprocess.run')
    def test_command_check_uses_which(self, mock_run):
        """Test that command check uses 'which'."""
        mock_run.return_value = MagicMock()
        check_command_exists("test_command")
        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        assert args[0] == "which"
        assert args[1] == "test_command"


class TestLoadOsConfig:
    """Tests for load_os_config function."""

    def test_load_valid_config(self, config_file):
        """Test loading a valid OS configuration."""
        config = load_os_config(config_file, "ubuntu-24")

        assert config['name'] == 'Ubuntu 24.04 LTS'
        assert config['owner'] == '099720109477'
        assert config['ssh_username'] == 'ubuntu'
        assert config['user_data_type'] == 'shell'

    def test_load_windows_config(self, config_file):
        """Test loading Windows OS configuration."""
        config = load_os_config(config_file, "windows-server-2022")

        assert config['name'] == 'Windows Server 2022 Base'
        assert config['communicator'] == 'winrm'
        assert config['user_data_type'] == 'powershell'

    def test_nonexistent_os_type(self, config_file):
        """Test that non-existent OS type raises SystemExit."""
        with pytest.raises(SystemExit):
            load_os_config(config_file, "nonexistent-os")

    def test_nonexistent_config_file(self, temp_dir):
        """Test that non-existent config file raises SystemExit."""
        fake_path = temp_dir / "nonexistent.yaml"
        with pytest.raises(SystemExit):
            load_os_config(fake_path, "ubuntu-24")


class TestGetLatestAmi:
    """Tests for get_latest_ami function."""

    @patch('subprocess.run')
    def test_successful_ami_lookup(self, mock_run, mock_aws_ami_response):
        """Test successful AMI lookup."""
        mock_run.return_value = MagicMock(
            stdout=json.dumps(mock_aws_ami_response),
            returncode=0
        )

        result = get_latest_ami("099720109477", "ubuntu/images/*")

        assert result is not None
        assert result['ami_id'] == 'ami-0123456789abcdef0'
        assert 'ubuntu' in result['name'].lower()

    @patch('subprocess.run')
    def test_no_ami_found(self, mock_run):
        """Test when no AMI is found."""
        mock_run.return_value = MagicMock(
            stdout="null",
            returncode=0
        )

        result = get_latest_ami("099720109477", "nonexistent-filter-*")
        assert result is None

    @patch('subprocess.run')
    def test_empty_response(self, mock_run):
        """Test when AWS returns empty response."""
        mock_run.return_value = MagicMock(
            stdout="",
            returncode=0
        )

        result = get_latest_ami("099720109477", "some-filter-*")
        assert result is None

    @patch('subprocess.run')
    def test_aws_error(self, mock_run):
        """Test handling of AWS CLI errors."""
        mock_run.side_effect = subprocess.CalledProcessError(
            1, 'aws', stderr="Access denied"
        )

        with pytest.raises(SystemExit):
            get_latest_ami("invalid-owner", "some-filter-*")

    @patch('subprocess.run')
    def test_json_parse_error(self, mock_run):
        """Test handling of invalid JSON response."""
        mock_run.return_value = MagicMock(
            stdout="invalid json {{{",
            returncode=0
        )

        with pytest.raises(SystemExit):
            get_latest_ami("099720109477", "some-filter-*")

    @patch('subprocess.run')
    def test_aws_command_format(self, mock_run):
        """Test that AWS command is properly formatted."""
        mock_run.return_value = MagicMock(
            stdout=json.dumps({'ImageId': 'ami-123'}),
            returncode=0
        )

        get_latest_ami("test-owner", "test-filter-*")

        call_args = mock_run.call_args[0][0]
        assert "aws" in call_args
        assert "ec2" in call_args
        assert "describe-images" in call_args
        assert "--owners" in call_args
        assert "test-owner" in call_args


class TestIntegration:
    """Integration tests (require mocking external dependencies)."""

    @patch('subprocess.run')
    def test_full_workflow(self, mock_run, config_file, mock_aws_ami_response):
        """Test the full workflow of loading config and fetching AMI."""
        # Mock AWS CLI response
        mock_run.return_value = MagicMock(
            stdout=json.dumps(mock_aws_ami_response),
            returncode=0
        )

        # Load config
        config = load_os_config(config_file, "ubuntu-24")

        # Get AMI
        result = get_latest_ami(config['owner'], config['filter'])

        assert result is not None
        assert result['ami_id'].startswith('ami-')
