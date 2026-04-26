import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CLI_PATH = REPO_ROOT / "scripts" / "install" / "runtime" / "cli.py"


def test_tp_status_prints_manifest_summary_as_json(tmp_path: Path) -> None:
    manifest_dir = tmp_path / "etc" / "trojan-pro"
    manifest_dir.mkdir(parents=True)
    (manifest_dir / "install-manifest.json").write_text(
        json.dumps(
            {
                "www_domain": "www.example.com",
                "edge_domain": "edge.example.com",
                "dns_provider": "cloudflare",
                "web_mode": "static",
                "trojan_version": "1.0.0",
                "caddy_version": "2.0.0",
            }
        ),
        encoding="utf-8",
    )

    proc = subprocess.run(
        [sys.executable, str(CLI_PATH), "--root-prefix", str(tmp_path), "status", "--json"],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )

    assert proc.returncode == 0
    payload = json.loads(proc.stdout)
    assert payload["www_domain"] == "www.example.com"
    assert payload["dns_provider"] == "cloudflare"


def test_tp_validate_reports_missing_required_files(tmp_path: Path) -> None:
    manifest_dir = tmp_path / "etc" / "trojan-pro"
    manifest_dir.mkdir(parents=True)
    (manifest_dir / "install-manifest.json").write_text("{}", encoding="utf-8")

    proc = subprocess.run(
        [sys.executable, str(CLI_PATH), "--root-prefix", str(tmp_path), "validate"],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )

    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    assert payload["status"] == "fail"
    assert any(path.endswith("config.json") for path in payload["missing"])
