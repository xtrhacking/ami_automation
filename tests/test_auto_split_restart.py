#!/usr/bin/env python3
"""
Unit tests for auto_split_restart.py

This test suite validates the Windows PowerShell script splitting functionality
for scripts that contain Restart-Computer commands.
"""

import pytest
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock, mock_open
import tempfile
import shutil

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))

from auto_split_restart import (
    find_restart_commands,
    split_script,
    update_template,
)


class TestFindRestartCommands:
    """Test detection of Restart-Computer commands in PowerShell scripts."""

    def test_find_single_restart(self, tmp_path):
        """Test finding a single Restart-Computer command."""
        script = tmp_path / "test.ps1"
        script.write_text(
            "Write-Host 'Before'\n"
            "Restart-Computer -Force\n"
            "Write-Host 'After'\n"
        )

        restart_lines = find_restart_commands(script)
        assert restart_lines == [2]

    def test_find_multiple_restarts(self, tmp_path):
        """Test finding multiple Restart-Computer commands."""
        script = tmp_path / "test.ps1"
        script.write_text(
            "Write-Host 'Part 1'\n"
            "Restart-Computer -Force\n"
            "Write-Host 'Part 2'\n"
            "Restart-Computer\n"
            "Write-Host 'Part 3'\n"
        )

        restart_lines = find_restart_commands(script)
        assert restart_lines == [2, 4]

    def test_find_no_restart(self, tmp_path):
        """Test script without Restart-Computer commands."""
        script = tmp_path / "test.ps1"
        script.write_text(
            "Write-Host 'Line 1'\n"
            "Write-Host 'Line 2'\n"
            "Write-Host 'Line 3'\n"
        )

        restart_lines = find_restart_commands(script)
        assert restart_lines == []

    def test_find_restart_case_insensitive(self, tmp_path):
        """Test case-insensitive detection of Restart-Computer."""
        script = tmp_path / "test.ps1"
        script.write_text(
            "restart-computer -Force\n"
            "RESTART-COMPUTER\n"
            "Restart-Computer\n"
        )

        restart_lines = find_restart_commands(script)
        assert restart_lines == [1, 2, 3]

    def test_find_restart_with_whitespace(self, tmp_path):
        """Test detection with various whitespace patterns."""
        script = tmp_path / "test.ps1"
        script.write_text(
            "  Restart-Computer -Force\n"
            "\t\tRestart-Computer\n"
            "    Restart-Computer    \n"
        )

        restart_lines = find_restart_commands(script)
        assert restart_lines == [1, 2, 3]

    def test_ignore_commented_restart(self, tmp_path):
        """Test that commented Restart-Computer is ignored."""
        script = tmp_path / "test.ps1"
        script.write_text(
            "Write-Host 'Before'\n"
            "# Restart-Computer -Force\n"
            "Write-Host 'After'\n"
        )

        restart_lines = find_restart_commands(script)
        assert restart_lines == []


class TestSplitScript:
    """Test PowerShell script splitting functionality."""

    def test_split_with_single_restart(self, tmp_path):
        """Test splitting a script with one Restart-Computer."""
        script = tmp_path / "userdata.ps1"
        script.write_text(
            "Write-Host 'Part 1'\n"
            "Install-Feature\n"
            "Restart-Computer -Force\n"
            "Write-Host 'Part 2'\n"
            "Configure-System\n"
        )

        part_files = split_script(script, [3])

        assert len(part_files) == 2
        assert part_files[0].name == "split-userdata-1.ps1"
        assert part_files[1].name == "split-userdata-2.ps1"

        # Verify part 1 content (before restart, excluding restart line)
        part1_content = part_files[0].read_text()
        assert "Write-Host 'Part 1'" in part1_content
        assert "Install-Feature" in part1_content
        assert "Restart-Computer" not in part1_content
        assert "Write-Host 'Part 2'" not in part1_content

        # Verify part 2 content (after restart)
        part2_content = part_files[1].read_text()
        assert "Write-Host 'Part 2'" in part2_content
        assert "Configure-System" in part2_content
        assert "Restart-Computer" not in part2_content
        assert "Write-Host 'Part 1'" not in part2_content

    def test_split_with_multiple_restarts(self, tmp_path):
        """Test splitting a script with multiple Restart-Computer commands."""
        script = tmp_path / "userdata.ps1"
        script.write_text(
            "Write-Host 'Part 1'\n"
            "Restart-Computer\n"
            "Write-Host 'Part 2'\n"
            "Restart-Computer\n"
            "Write-Host 'Part 3'\n"
        )

        part_files = split_script(script, [2, 4])

        assert len(part_files) == 3
        assert part_files[0].name == "split-userdata-1.ps1"
        assert part_files[1].name == "split-userdata-2.ps1"
        assert part_files[2].name == "split-userdata-3.ps1"

    def test_split_with_no_restart(self, tmp_path):
        """Test that no split occurs without Restart-Computer."""
        script = tmp_path / "userdata.ps1"
        script.write_text("Write-Host 'No restart'\n")

        part_files = split_script(script, [])

        assert len(part_files) == 1
        assert part_files[0] == script

    def test_split_preserves_encoding(self, tmp_path):
        """Test that UTF-8 encoding is preserved during split."""
        script = tmp_path / "userdata.ps1"
        content = "Write-Host 'Configuração'\nRestart-Computer\nWrite-Host 'Após'\n"
        script.write_text(content, encoding='utf-8')

        part_files = split_script(script, [2])

        # Verify UTF-8 characters are preserved
        part1 = part_files[0].read_text(encoding='utf-8')
        assert 'Configuração' in part1

        part2 = part_files[1].read_text(encoding='utf-8')
        assert 'Após' in part2


class TestUpdateTemplate:
    """Test template.pkr.hcl update functionality."""

    def test_update_template_with_split_provisioners(self, tmp_path):
        """Test updating template with split provisioners."""
        template = tmp_path / "template.pkr.hcl"
        template_content = '''
  # Execute the main setup script
  provisioner "powershell" {
    script = "${path.root}/userdata.ps1"
    environment_vars = [
      "LAB_NAME=test",
      "OS_TYPE=windows-server-2022",
      "BUILD_FILES=C:\\\\temp\\\\build-files"
    ]
  }
'''
        template.write_text(template_content)

        # Create mock split files
        part1 = tmp_path / "split-userdata-1.ps1"
        part2 = tmp_path / "split-userdata-2.ps1"
        part1.write_text("Part 1")
        part2.write_text("Part 2")

        update_template(template, [part1, part2], "test-lab", "windows-server-2022")

        updated_content = template.read_text()

        # Verify split provisioners were added
        assert "split-userdata-1.ps1" in updated_content
        assert "split-userdata-2.ps1" in updated_content

        # Verify restart provisioner was added
        assert 'provisioner "windows-restart"' in updated_content
        assert 'restart_timeout = "10m"' in updated_content

        # Verify original userdata.ps1 reference was removed
        assert 'script = "${path.root}/userdata.ps1"' not in updated_content

        # Verify proper escaping for BUILD_FILES
        assert 'BUILD_FILES=C:\\\\temp\\\\build-files' in updated_content

    def test_update_template_with_correct_lab_vars(self, tmp_path):
        """Test that lab name and OS type are correctly inserted."""
        template = tmp_path / "template.pkr.hcl"
        template_content = '''
  # Execute the main setup script
  provisioner "powershell" {
    script = "${path.root}/userdata.ps1"
    environment_vars = [
      "LAB_NAME=old-lab",
      "OS_TYPE=old-os"
    ]
  }
'''
        template.write_text(template_content)

        part1 = tmp_path / "split-userdata-1.ps1"
        part1.write_text("Test")

        update_template(template, [part1], "jekroast", "windows-server-2022")

        updated_content = template.read_text()

        assert 'LAB_NAME=jekroast' in updated_content
        assert 'OS_TYPE=windows-server-2022' in updated_content

    def test_update_template_multiple_parts(self, tmp_path):
        """Test template update with 3+ split files."""
        template = tmp_path / "template.pkr.hcl"
        template_content = '''
  # Execute the main setup script
  provisioner "powershell" {
    script = "${path.root}/userdata.ps1"
  }
'''
        template.write_text(template_content)

        # Create 3 split files
        parts = []
        for i in range(1, 4):
            part = tmp_path / f"split-userdata-{i}.ps1"
            part.write_text(f"Part {i}")
            parts.append(part)

        update_template(template, parts, "test", "windows-server-2022")

        updated_content = template.read_text()

        # Verify all parts are present
        assert "split-userdata-1.ps1" in updated_content
        assert "split-userdata-2.ps1" in updated_content
        assert "split-userdata-3.ps1" in updated_content

        # Count restart provisioners (should be 2 for 3 parts)
        restart_count = updated_content.count('provisioner "windows-restart"')
        assert restart_count == 2

    def test_update_template_no_restart_after_last_part(self, tmp_path):
        """Test that no restart provisioner is added after the last part."""
        template = tmp_path / "template.pkr.hcl"
        template_content = '''
  # Execute the main setup script
  provisioner "powershell" {
    script = "${path.root}/userdata.ps1"
  }
'''
        template.write_text(template_content)

        part1 = tmp_path / "split-userdata-1.ps1"
        part2 = tmp_path / "split-userdata-2.ps1"
        part1.write_text("Part 1")
        part2.write_text("Part 2")

        update_template(template, [part1, part2], "test", "windows-server-2022")

        updated_content = template.read_text()

        # Split content and verify restart only appears once (between parts)
        lines = updated_content.split('\n')

        # Find the last occurrence of split-userdata-2.ps1
        last_part2_line = -1
        for i, line in enumerate(lines):
            if 'split-userdata-2.ps1' in line:
                last_part2_line = i

        # After the last part, there should be no restart provisioner
        remaining_content = '\n'.join(lines[last_part2_line:])

        # Count restarts - should only be 1 (between part 1 and part 2)
        restart_count = updated_content.count('provisioner "windows-restart"')
        assert restart_count == 1


class TestIntegration:
    """Integration tests for the complete workflow."""

    def test_full_workflow(self, tmp_path):
        """Test the complete split and update workflow."""
        # Create a lab directory structure
        lab_dir = tmp_path / "test-lab"
        lab_dir.mkdir()

        # Create userdata.ps1 with restart
        userdata = lab_dir / "userdata.ps1"
        userdata.write_text(
            "Write-Host 'Installing features'\n"
            "Install-WindowsFeature AD-Domain-Services\n"
            "Restart-Computer -Force\n"
            "Write-Host 'Configuring domain'\n"
            "Install-ADDSForest -DomainName 'test.local'\n"
        )

        # Create template.pkr.hcl
        template = lab_dir / "template.pkr.hcl"
        template_content = '''build {
  # Execute the main setup script
  provisioner "powershell" {
    script = "${path.root}/userdata.ps1"
    environment_vars = [
      "LAB_NAME=test-lab",
      "OS_TYPE=windows-server-2022",
      "BUILD_FILES=C:\\\\temp\\\\build-files"
    ]
  }
}'''
        template.write_text(template_content)

        # Find restart commands
        restart_lines = find_restart_commands(userdata)
        assert restart_lines == [3]

        # Split the script
        part_files = split_script(userdata, restart_lines)
        assert len(part_files) == 2

        # Update template
        update_template(template, part_files, "test-lab", "windows-server-2022")

        # Verify final template
        updated_content = template.read_text()

        assert "split-userdata-1.ps1" in updated_content
        assert "split-userdata-2.ps1" in updated_content
        assert 'provisioner "windows-restart"' in updated_content
        assert 'restart_timeout = "10m"' in updated_content
        assert 'BUILD_FILES=C:\\\\temp\\\\build-files' in updated_content

        # Verify original userdata.ps1 is preserved
        assert userdata.exists()
        original_content = userdata.read_text()
        assert "Restart-Computer" in original_content

    def test_cleanup_old_splits(self, tmp_path):
        """Test that old split files are cleaned up."""
        lab_dir = tmp_path / "test-lab"
        lab_dir.mkdir()

        # Create old split files
        old_split1 = lab_dir / "split-userdata-1.ps1"
        old_split2 = lab_dir / "split-userdata-2.ps1"
        old_split3 = lab_dir / "split-userdata-3.ps1"

        old_split1.write_text("Old part 1")
        old_split2.write_text("Old part 2")
        old_split3.write_text("Old part 3")

        # Create userdata with only one restart (should create 2 parts)
        userdata = lab_dir / "userdata.ps1"
        userdata.write_text(
            "Part 1\n"
            "Restart-Computer\n"
            "Part 2\n"
        )

        # Find and split
        restart_lines = find_restart_commands(userdata)
        part_files = split_script(userdata, restart_lines)

        # Should only have 2 new split files
        assert len(part_files) == 2

        # Old split-userdata-3.ps1 should still exist until main() cleanup
        # (this test validates split_script doesn't delete old files)
        assert old_split3.exists()


class TestEdgeCases:
    """Test edge cases and error conditions."""

    def test_empty_script(self, tmp_path):
        """Test handling of empty script."""
        script = tmp_path / "empty.ps1"
        script.write_text("")

        restart_lines = find_restart_commands(script)
        assert restart_lines == []

    def test_restart_on_first_line(self, tmp_path):
        """Test restart command on the first line."""
        script = tmp_path / "test.ps1"
        script.write_text(
            "Restart-Computer\n"
            "Write-Host 'After restart'\n"
        )

        restart_lines = find_restart_commands(script)
        assert restart_lines == [1]

        part_files = split_script(script, restart_lines)
        assert len(part_files) == 2

        # Part 1 should be empty
        part1_content = part_files[0].read_text()
        assert part1_content == ""

    def test_restart_on_last_line(self, tmp_path):
        """Test restart command on the last line."""
        script = tmp_path / "test.ps1"
        script.write_text(
            "Write-Host 'Before restart'\n"
            "Restart-Computer\n"
        )

        restart_lines = find_restart_commands(script)
        assert restart_lines == [2]

        part_files = split_script(script, restart_lines)

        # When restart is on last line, only one part is created
        # (no content after restart, so no second file)
        assert len(part_files) == 1

        # Part 1 should have content before restart
        part1_content = part_files[0].read_text()
        assert "Write-Host 'Before restart'" in part1_content
        assert "Restart-Computer" not in part1_content

    def test_consecutive_restarts(self, tmp_path):
        """Test consecutive Restart-Computer commands."""
        script = tmp_path / "test.ps1"
        script.write_text(
            "Write-Host 'Before'\n"
            "Restart-Computer\n"
            "Restart-Computer\n"
            "Write-Host 'After'\n"
        )

        restart_lines = find_restart_commands(script)
        assert restart_lines == [2, 3]

        part_files = split_script(script, restart_lines)
        assert len(part_files) == 3

    def test_restart_with_parameters(self, tmp_path):
        """Test Restart-Computer with various parameters."""
        script = tmp_path / "test.ps1"
        script.write_text(
            "Restart-Computer -Force\n"
            "Restart-Computer -Force -Timeout 30\n"
            "Restart-Computer -ComputerName localhost\n"
        )

        restart_lines = find_restart_commands(script)
        assert restart_lines == [1, 2, 3]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
