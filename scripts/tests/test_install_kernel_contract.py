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
    assert "--domain" in proc.stdout
    assert "--email" in proc.stdout
    assert "--password" in proc.stdout
    assert "--check-only" in proc.stdout
    assert "--help" in proc.stdout
    assert "Caddy ACME" in proc.stdout


def test_check_only_runs_phase_skeleton_without_system_changes() -> None:
    proc = _run(
        [
            "bash",
            str(SCRIPT_PATH),
            "--domain",
            "example.com",
            "--email",
            "ops@example.com",
            "--password",
            "test-password",
            "--check-only",
        ],
        cwd=SCRIPT_PATH.parent.parent,
        check=False,
    )

    assert proc.returncode == 0
    assert "mode=check-only" in proc.stdout
    assert "phase=detect-os" in proc.stdout
    assert "phase=install-deps" in proc.stdout
    assert "phase=install-core" in proc.stdout
    assert "phase=configure-caddy" in proc.stdout
    assert "phase=write-runtime-config" in proc.stdout
    assert "[check-only] would install dependencies" in proc.stdout
    assert "[check-only] would install trojan core" in proc.stdout
    assert "[check-only] would render Caddy ACME config" in proc.stdout
    assert "[check-only] would write runtime config" in proc.stdout
