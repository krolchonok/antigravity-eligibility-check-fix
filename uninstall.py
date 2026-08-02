#!/usr/bin/env python3
"""
Cross-platform uninstaller for agy-tier-fix (Windows / Linux / macOS).
Usage: python uninstall.py
"""
import os
import sys
import subprocess
from pathlib import Path

def main():
    script_dir = Path(__file__).resolve().parent
    is_win = sys.platform.startswith("win")
    
    print(f"=== Uninstalling agy-tier-fix ({'Windows' if is_win else 'Linux/macOS'}) ===", flush=True)
    
    if is_win:
        install_dir = Path(os.environ.get("LOCALAPPDATA", "")) / "agy-tier-fix"
        ps1_uninstaller = install_dir / "uninstall.ps1" if (install_dir / "uninstall.ps1").exists() else script_dir / "uninstall.ps1"
        cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(ps1_uninstaller)]
        sys.exit(subprocess.call(cmd))
    else:
        install_dir = Path.home() / ".local" / "share" / "agy-tier-fix"
        sh_uninstaller = install_dir / "uninstall.sh" if (install_dir / "uninstall.sh").exists() else script_dir / "uninstall.sh"
        cmd = ["bash", str(sh_uninstaller)]
        sys.exit(subprocess.call(cmd))

if __name__ == "__main__":
    main()
