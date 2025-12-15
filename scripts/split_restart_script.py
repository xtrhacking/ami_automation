#!/usr/bin/env python3
"""
split_restart_script.py - Splits a PowerShell script that contains Restart-Computer

This script detects Restart-Computer commands in a PowerShell script and:
1. Splits the script into multiple parts (before restart, after restart)
2. Creates separate .ps1 files for each part
3. Outputs the provisioner configuration to add to template.pkr.hcl

Usage: python split_restart_script.py <script.ps1>
Example: python split_restart_script.py laboratory/my-lab/userdata.ps1
"""

import sys
import re
from pathlib import Path
from typing import List, Tuple

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'


def info(message: str) -> None:
    """Display info message."""
    print(f"{Colors.BLUE}INFO: {message}{Colors.NC}", file=sys.stderr)


def success(message: str) -> None:
    """Display success message."""
    print(f"{Colors.GREEN}SUCCESS: {message}{Colors.NC}", file=sys.stderr)


def warning(message: str) -> None:
    """Display warning message."""
    print(f"{Colors.YELLOW}WARNING: {message}{Colors.NC}", file=sys.stderr)


def error(message: str) -> None:
    """Display error message and exit."""
    print(f"{Colors.RED}ERROR: {message}{Colors.NC}", file=sys.stderr)
    sys.exit(1)


def find_restart_commands(script_path: Path) -> List[int]:
    """Find line numbers where Restart-Computer appears."""
    restart_pattern = re.compile(r'^\s*Restart-Computer\s', re.IGNORECASE)
    restart_lines = []

    with open(script_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            if restart_pattern.match(line):
                restart_lines.append(line_num)

    return restart_lines


def split_script(script_path: Path, restart_lines: List[int]) -> List[Tuple[int, int, List[str]]]:
    """Split script into parts based on restart commands."""
    parts = []

    with open(script_path, 'r', encoding='utf-8') as f:
        all_lines = f.readlines()

    # Add part before first restart
    if restart_lines:
        start = 0
        for restart_line in restart_lines:
            # Part before restart (exclude the Restart-Computer line)
            end = restart_line - 1
            part_lines = all_lines[start:end]
            parts.append((start + 1, end, part_lines))
            start = restart_line  # Start after the restart line

        # Add final part after last restart
        if start < len(all_lines):
            part_lines = all_lines[start:]
            parts.append((start + 1, len(all_lines), part_lines))

    return parts


def write_parts(script_path: Path, parts: List[Tuple[int, int, List[str]]]) -> List[Path]:
    """Write script parts to separate files."""
    script_dir = script_path.parent
    script_name = script_path.stem  # e.g., "userdata"
    script_ext = script_path.suffix  # e.g., ".ps1"

    part_files = []

    for idx, (start_line, end_line, lines) in enumerate(parts, 1):
        part_filename = f"{script_name}-part{idx}{script_ext}"
        part_path = script_dir / part_filename

        with open(part_path, 'w', encoding='utf-8') as f:
            f.writelines(lines)

        part_files.append(part_path)
        success(f"Created {part_filename} (lines {start_line}-{end_line})")

    return part_files


def generate_provisioner_config(part_files: List[Path], lab_name: str, os_type: str) -> str:
    """Generate provisioner configuration for template.pkr.hcl."""
    config_lines = []

    for idx, part_file in enumerate(part_files, 1):
        # Add PowerShell provisioner
        config_lines.append(f"  # Execute part {idx} of setup script")
        config_lines.append("  provisioner \"powershell\" {")
        config_lines.append(f"    script = \"${{path.root}}/{part_file.name}\"")
        config_lines.append("    environment_vars = [")
        config_lines.append(f"      \"LAB_NAME={lab_name}\",")
        config_lines.append(f"      \"OS_TYPE={os_type}\",")
        config_lines.append("      \"BUILD_FILES=C:\\\\temp\\\\build-files\"")
        config_lines.append("    ]")
        config_lines.append("  }")
        config_lines.append("")

        # Add restart provisioner between parts (except after last part)
        if idx < len(part_files):
            config_lines.append("  # Restart Windows")
            config_lines.append("  provisioner \"windows-restart\" {")
            config_lines.append("    restart_timeout = \"15m\"")
            config_lines.append("  }")
            config_lines.append("")

    return "\n".join(config_lines)


def main() -> None:
    """Main function."""
    if len(sys.argv) != 2:
        error(f"Usage: {sys.argv[0]} <script.ps1>")

    script_path = Path(sys.argv[1])

    if not script_path.exists():
        error(f"Script not found: {script_path}")

    if not script_path.suffix.lower() == '.ps1':
        error(f"Script must be a PowerShell file (.ps1): {script_path}")

    info(f"Analyzing script: {script_path}")

    # Find restart commands
    restart_lines = find_restart_commands(script_path)

    if not restart_lines:
        warning("No Restart-Computer commands found in script")
        info("Script does not require splitting")
        sys.exit(0)

    info(f"Found {len(restart_lines)} Restart-Computer command(s) at line(s): {', '.join(map(str, restart_lines))}")

    # Split script
    parts = split_script(script_path, restart_lines)
    info(f"Script will be split into {len(parts)} parts")

    # Write parts
    part_files = write_parts(script_path, parts)

    # Try to extract lab info from path
    lab_name = "{{LAB_NAME}}"
    os_type = "{{OS_TYPE}}"
    if "laboratory" in script_path.parts:
        lab_idx = script_path.parts.index("laboratory")
        if lab_idx + 1 < len(script_path.parts):
            lab_name = script_path.parts[lab_idx + 1]

    # Generate provisioner config
    print("\n" + "="*60, file=sys.stderr)
    success("Script split completed!")
    print("="*60 + "\n", file=sys.stderr)

    info("Add this configuration to your template.pkr.hcl:")
    print("\n" + "="*60)
    print(generate_provisioner_config(part_files, lab_name, os_type))
    print("="*60 + "\n")

    info(f"Original script: {script_path}")
    info("You can now remove or rename the original script")
    print("", file=sys.stderr)


if __name__ == "__main__":
    main()
