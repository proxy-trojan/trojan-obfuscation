import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


def test_export_bundle_uses_manifest_server_fields(tmp_path: Path) -> None:
    manifest_dir = tmp_path / "etc" / "trojan-pro"
    manifest_dir.mkdir(parents=True)
    (manifest_dir / "install-manifest.json").write_text(
        json.dumps(
            {
                "edge_domain": "edge.example.com",
                "bundle_server_port": 443,
                "bundle_profile_name": "Managed Edge",
            }
        ),
        encoding="utf-8",
    )

    out = tmp_path / "bundle.json"
    proc = subprocess.run(
        [
            sys.executable,
            "scripts/install/runtime/export_client_bundle.py",
            "--root-prefix",
            str(tmp_path),
            "--direct",
            "scripts/tests/fixtures/clash_rules_direct.sample.txt",
            "--proxy",
            "scripts/tests/fixtures/clash_rules_proxy.sample.txt",
            "--reject",
            "scripts/tests/fixtures/clash_rules_reject.sample.txt",
            "--output",
            str(out),
        ],
        text=True,
        capture_output=True,
        check=False,
        cwd=REPO_ROOT,
    )

    assert proc.returncode == 0
    payload = json.loads(out.read_text())
    assert payload["profile"]["serverHost"] == "edge.example.com"
    assert payload["profile"]["sni"] == "edge.example.com"
    assert payload["profile"]["name"] == "Managed Edge"
