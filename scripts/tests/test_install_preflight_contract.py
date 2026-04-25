import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "scripts" / "install" / "install-kernel.sh"
FIXTURES = REPO_ROOT / "scripts" / "tests" / "fixtures"


def test_check_only_reports_detected_package_manager_from_fixture(tmp_path: Path) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    (fake_bin / "apt-get").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    (fake_bin / "apt-get").chmod(0o755)

    env = os.environ | {
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
        "INSTALL_OS_RELEASE_PATH": str(FIXTURES / "os-release.debian"),
        "CLOUDFLARE_API_TOKEN": "token",
    }
    proc = subprocess.run(
        [
            "bash",
            str(SCRIPT_PATH),
            "--www-domain",
            "www.example.com",
            "--edge-domain",
            "edge.example.com",
            "--dns-provider",
            "cloudflare",
            "--check-only",
        ],
        text=True,
        capture_output=True,
        env=env,
        cwd=REPO_ROOT,
        check=False,
    )

    assert proc.returncode == 0
    assert "phase=preflight" in proc.stdout
    assert "detected_package_manager=apt" in proc.stdout


def test_check_only_fails_when_provider_env_missing() -> None:
    proc = subprocess.run(
        [
            "bash",
            str(SCRIPT_PATH),
            "--www-domain",
            "www.example.com",
            "--edge-domain",
            "edge.example.com",
            "--dns-provider",
            "cloudflare",
            "--check-only",
        ],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )

    assert proc.returncode != 0
    assert "missing_provider_env=CLOUDFLARE_API_TOKEN" in proc.stderr
