#!/usr/bin/env python3
"""
auto_split_restart.py - Automatically splits PowerShell scripts with Restart-Computer and updates template

This script:
1. Detects Restart-Computer in PowerShell scripts
2. Splits the script into multiple parts
3. Updates the template.pkr.hcl with the correct provisioners

Usage: python auto_split_restart.py <lab_folder>
Example: python auto_split_restart.py laboratory/test-windows
"""

import sys
import re
from pathlib import Path
from typing import List, Tuple, Optional

def find_restart_commands(script_path: Path) -> List[int]:
    """Find line numbers where Restart-Computer appears."""
    restart_pattern = re.compile(r'^\s*Restart-Computer\s', re.IGNORECASE)
    restart_lines = []

    with open(script_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            if restart_pattern.match(line):
                restart_lines.append(line_num)

    return restart_lines


def split_script(script_path: Path, restart_lines: List[int]) -> List[Path]:
    """Split script into parts based on restart commands."""
    if not restart_lines:
        return [script_path]

    with open(script_path, 'r', encoding='utf-8') as f:
        all_lines = f.readlines()

    script_dir = script_path.parent
    script_ext = script_path.suffix
    part_files = []

    start = 0
    part_num = 1

    for restart_line in restart_lines:
        # Part before restart (exclude the Restart-Computer line)
        end = restart_line - 1
        part_lines = all_lines[start:end]

        part_filename = f"split-userdata-{part_num}{script_ext}"
        part_path = script_dir / part_filename

        with open(part_path, 'w', encoding='utf-8') as f:
            f.writelines(part_lines)

        part_files.append(part_path)
        start = restart_line  # Start after the restart line
        part_num += 1

    # Add final part after last restart
    if start < len(all_lines):
        part_lines = all_lines[start:]
        part_filename = f"split-userdata-{part_num}{script_ext}"
        part_path = script_dir / part_filename

        with open(part_path, 'w', encoding='utf-8') as f:
            f.writelines(part_lines)

        part_files.append(part_path)

    return part_files


def update_template(template_path: Path, part_files: List[Path], lab_name: str, os_type: str) -> None:
    """Update template.pkr.hcl to use split scripts with restart provisioners."""
    with open(template_path, 'r', encoding='utf-8') as f:
        template_content = f.read()

    # Find and replace the single provisioner with multiple provisioners
    # Pattern to match the entire "Execute the main setup script" section
    # including all comments and the provisioner block
    provisioner_pattern = re.compile(
        r'(  # Execute the main setup script[\s\S]*?provisioner "powershell" \{\s*script = "\$\{path\.root\}/userdata\.ps1"[\s\S]*?  \})\n',
        re.MULTILINE
    )

    # Generate new provisioners
    new_provisioners = []
    for idx, part_file in enumerate(part_files, 1):
        # Add PowerShell provisioner
        new_provisioners.append(f"  # Execute part {idx} of setup script")
        new_provisioners.append('  provisioner "powershell" {')
        new_provisioners.append(f'    script = "${{path.root}}/{part_file.name}"')
        new_provisioners.append('    environment_vars = [')
        new_provisioners.append(f'      "LAB_NAME={lab_name}",')
        new_provisioners.append(f'      "OS_TYPE={os_type}",')
        new_provisioners.append('      "BUILD_FILES=C:\\\\\\\\temp\\\\\\\\build-files"')
        new_provisioners.append('    ]')
        new_provisioners.append('  }')

        # Add restart provisioner between parts (except after last part)
        if idx < len(part_files):
            new_provisioners.append('')
            new_provisioners.append('  # Restart Windows')
            new_provisioners.append('  provisioner "windows-restart" {')
            new_provisioners.append('    restart_timeout = "10m"')
            new_provisioners.append('  }')

    new_provisioner_block = '\n'.join(new_provisioners)

    # Replace the old provisioner
    updated_content = provisioner_pattern.sub(new_provisioner_block + '\n', template_content)

    # Verify that replacement occurred
    if updated_content == template_content:
        print(f"WARNING: Template update may have failed - no changes detected", file=sys.stderr)
        print(f"WARNING: Looking for provisioner with userdata.ps1", file=sys.stderr)
        # Debug: show what we're looking for
        if 'userdata.ps1' in template_content:
            print(f"INFO: Found userdata.ps1 reference in template", file=sys.stderr)
        else:
            print(f"WARNING: No userdata.ps1 reference found in template", file=sys.stderr)

    with open(template_path, 'w', encoding='utf-8') as f:
        f.write(updated_content)


def main() -> None:
    """Main function."""
    if len(sys.argv) != 2:
        print(f"ERROR: Usage: {sys.argv[0]} <lab-folder>", file=sys.stderr)
        sys.exit(1)

    lab_folder = Path(sys.argv[1])

    if not lab_folder.exists():
        print(f"ERROR: Laboratory folder not found: {lab_folder}", file=sys.stderr)
        sys.exit(1)

    # Find userdata.ps1
    userdata_script = lab_folder / "userdata.ps1"

    if not userdata_script.exists():
        # No PowerShell script, nothing to do
        sys.exit(0)

    # Clean up old split files
    for old_split in lab_folder.glob("split-userdata-*.ps1"):
        old_split.unlink()
        print(f"INFO: Removed old split: {old_split.name}", file=sys.stderr)

    # Check for Restart-Computer
    restart_lines = find_restart_commands(userdata_script)

    if not restart_lines:
        # No restart needed, use original script as-is
        print(f"INFO: No Restart-Computer found, using original script", file=sys.stderr)
        sys.exit(0)

    # Split the script
    print(f"INFO: Found {len(restart_lines)} Restart-Computer command(s)", file=sys.stderr)
    print(f"INFO: Splitting script into parts...", file=sys.stderr)

    part_files = split_script(userdata_script, restart_lines)

    print(f"SUCCESS: Created {len(part_files)} script parts", file=sys.stderr)

    # Update template.pkr.hcl
    template_path = lab_folder / "template.pkr.hcl"

    if template_path.exists():
        # Extract lab name and OS from variables.pkr.hcl
        variables_path = lab_folder / "variables.pkr.hcl"
        lab_name = lab_folder.name
        os_type = "windows-server-2022"  # default

        if variables_path.exists():
            with open(variables_path, 'r', encoding='utf-8') as f:
                vars_content = f.read()
                lab_match = re.search(r'default\s*=\s*"([^"]+)"\s*#.*lab_name', vars_content, re.IGNORECASE)
                os_match = re.search(r'default\s*=\s*"([^"]+)"\s*#.*os_type', vars_content, re.IGNORECASE)

                if not lab_match:
                    lab_match = re.search(r'variable\s+"lab_name"[\s\S]*?default\s*=\s*"([^"]+)"', vars_content)
                if not os_match:
                    os_match = re.search(r'variable\s+"os_type"[\s\S]*?default\s*=\s*"([^"]+)"', vars_content)

                if lab_match:
                    lab_name = lab_match.group(1)
                if os_match:
                    os_type = os_match.group(1)

        print(f"INFO: Updating template.pkr.hcl...", file=sys.stderr)
        update_template(template_path, part_files, lab_name, os_type)
        print(f"SUCCESS: Template updated with restart provisioners", file=sys.stderr)

    # Keep original script - do not rename or backup
    print(f"INFO: Original script preserved: userdata.ps1", file=sys.stderr)


if __name__ == "__main__":
    main()
