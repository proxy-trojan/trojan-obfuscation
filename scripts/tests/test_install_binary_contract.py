import hashlib
import json
import os
import shlex
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def test_install_binary_from_lock_verifies_checksum_and_promotes(tmp_path: Path) -> None:
    source = tmp_path / "trojan-linux-amd64"
    source.write_text("#!/bin/sh\necho trojan\n", encoding="utf-8")
    sha256 = hashlib.sha256(source.read_bytes()).hexdigest()

    lock_path = tmp_path / "binaries.lock.json"
    lock_path.write_text(
        json.dumps(
            {
                "trojan": {
                    "linux-amd64": {
                        "url": source.as_uri(),
                        "sha256": sha256,
                        "version": "1.0.0",
                    }
                }
            }
        ),
        encoding="utf-8",
    )

    dest = tmp_path / "root" / "usr" / "local" / "bin" / "trojan"
    cmd = [
        "bash",
        "-lc",
        "source scripts/install/lib/common.sh && "
        "source scripts/install/lib/install-binaries.sh && "
        f"install_binary_from_lock {shlex.quote(str(lock_path))} trojan linux-amd64 {shlex.quote(str(dest))}",
    ]
    proc = subprocess.run(cmd, text=True, capture_output=True, cwd=REPO_ROOT, check=False)

    assert proc.returncode == 0
    assert dest.exists()
    assert os.access(dest, os.X_OK)
    assert "installed_asset=trojan" in proc.stdout
    assert "installed_version=1.0.0" in proc.stdout
