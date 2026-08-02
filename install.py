#!/usr/bin/env python3
"""
Cross-platform installer for agy-tier-fix (Windows / Linux / macOS).
Usage: python install.py
"""
import os
import sys
import subprocess
from pathlib import Path

def main():
    script_dir = Path(__file__).resolve().parent
    is_win = sys.platform.startswith("win")
    
    # flush: stdout is block-buffered when piped, otherwise this header
    # lands after the child installer's output
    print(f"=== Installing agy-tier-fix ({'Windows' if is_win else 'Linux/macOS'}) ===", flush=True)
    
    if is_win:
        ps1_installer = script_dir / "install.ps1"
        if not ps1_installer.exists():
            print(f"Error: {ps1_installer} not found.", file=sys.stderr)
            sys.exit(1)
        cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(ps1_installer)]
        sys.exit(subprocess.call(cmd))
    else:
        sh_installer = script_dir / "install.sh"
        if not sh_installer.exists():
            print(f"Error: {sh_installer} not found.", file=sys.stderr)
            sys.exit(1)
        cmd = ["bash", str(sh_installer)]
        sys.exit(subprocess.call(cmd))

if __name__ == "__main__":
    main()
