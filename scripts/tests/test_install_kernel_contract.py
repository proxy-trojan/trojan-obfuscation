import subprocess
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parents[1] / "install" / "install-kernel.sh"


def _run(cmd: list[str], cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, check=False)
    if check and proc.returncode != 0:
        raise AssertionError(
            f"command failed: {' '.join(cmd)}\n"
            f"cwd={cwd}\n"
            f"exit={proc.returncode}\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}"
        )
    return proc


def test_help_describes_supported_flags() -> None:
    proc = _run(["bash", str(SCRIPT_PATH), "--help"], cwd=SCRIPT_PATH.parent.parent, check=False)

    assert proc.returncode == 0
    assert "Usage:" in proc.stdout
    assert "--www-domain" in proc.stdout
    assert "--edge-domain" in proc.stdout
    assert "--dns-provider" in proc.stdout
    assert "--check-only" in proc.stdout
    assert "--help" in proc.stdout
    assert "Caddy ACME" in proc.stdout


def test_check_only_runs_phase_skeleton_without_system_changes() -> None:
    proc = _run(
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
        cwd=SCRIPT_PATH.parent.parent,
        check=False,
    )

    assert proc.returncode != 0
    assert "mode=check-only" in proc.stdout
    assert "phase=preflight" in proc.stdout
    assert "missing_provider_env=CLOUDFLARE_API_TOKEN" in proc.stderr


def test_missing_value_reports_specific_flag_error() -> None:
    proc = _run(
        [
            "bash",
            str(SCRIPT_PATH),
            "--www-domain",
            "--edge-domain",
            "edge.example.com",
            "--dns-provider",
            "cloudflare",
            "--check-only",
        ],
        cwd=SCRIPT_PATH.parent.parent,
        check=False,
    )

    assert proc.returncode != 0
    assert "missing value for --www-domain" in proc.stderr


def test_missing_required_flags_reports_usage_error() -> None:
    proc = _run(
        [
            "bash",
            str(SCRIPT_PATH),
            "--www-domain",
            "www.example.com",
            "--edge-domain",
            "edge.example.com",
            "--check-only",
        ],
        cwd=SCRIPT_PATH.parent.parent,
        check=False,
    )

    assert proc.returncode != 0
    assert "--www-domain, --edge-domain, and --dns-provider are required" in proc.stderr
    assert "Usage:" in proc.stderr


def test_apply_mode_fails_closed_until_implemented() -> None:
    proc = _run(
        [
            "bash",
            str(SCRIPT_PATH),
            "--www-domain",
            "www.example.com",
            "--edge-domain",
            "edge.example.com",
            "--dns-provider",
            "cloudflare",
        ],
        cwd=SCRIPT_PATH.parent.parent,
        check=False,
    )

    assert proc.returncode != 0
    assert "mode=apply" in proc.stdout
    assert "apply mode is not implemented yet; use --check-only" in proc.stderr
