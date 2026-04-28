import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CLI_PATH = REPO_ROOT / "scripts" / "install" / "runtime" / "cli.py"


def test_tp_install_help_exists() -> None:
    proc = subprocess.run(
        [sys.executable, str(CLI_PATH), "install", "--help"],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )
    assert proc.returncode == 0
    assert "tp install" in proc.stdout.lower() or "install" in proc.stdout.lower()


def test_tp_install_non_interactive_plan_and_abort(tmp_path: Path) -> None:
    # Expect: in non-interactive mode without --yes, it prints plan and aborts (confirmation not granted).
    proc = subprocess.run(
        [
            sys.executable,
            str(CLI_PATH),
            "--root-prefix",
            str(tmp_path),
            "install",
            "--lang",
            "en",
            "--non-interactive",
            "--www-domain",
            "www.example.com",
            "--edge-domain",
            "edge.example.com",
            "--dns-provider",
            "cloudflare",
        ],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
        env={
            **os.environ,
            # Satisfy provider env validation so we can reach the plan/confirmation gate.
            "CLOUDFLARE_API_TOKEN": "test-token",
        },
    )

    assert proc.returncode != 0
    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    assert "plan" in combined.lower()
    assert "/etc/trojan-pro/install-manifest.json" in combined
    assert "type" in combined.lower() or "yes" in combined
