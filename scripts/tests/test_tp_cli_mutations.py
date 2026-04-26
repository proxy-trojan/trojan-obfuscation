import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CLI_PATH = REPO_ROOT / "scripts" / "install" / "runtime" / "cli.py"
FIXTURES = REPO_ROOT / "scripts" / "tests" / "fixtures"


def test_tp_set_web_mode_upstream_updates_manifest(tmp_path: Path) -> None:
    manifest_dir = tmp_path / "etc" / "trojan-pro"
    manifest_dir.mkdir(parents=True)
    manifest_path = manifest_dir / "install-manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "www_domain": "www.example.com",
                "edge_domain": "edge.example.com",
                "dns_provider": "cloudflare",
                "web_mode": "static",
                "trojan_local_port": 8443,
            }
        ),
        encoding="utf-8",
    )

    proc = subprocess.run(
        [
            sys.executable,
            str(CLI_PATH),
            "--root-prefix",
            str(tmp_path),
            "set-web-mode",
            "upstream",
            "--upstream",
            "https://origin.example.com",
        ],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )

    assert proc.returncode == 0
    payload = json.loads(manifest_path.read_text())
    assert payload["web_mode"] == "upstream"
    assert payload["web_upstream"] == "https://origin.example.com"


def test_tp_rotate_password_writes_env(tmp_path: Path) -> None:
    manifest_dir = tmp_path / "etc" / "trojan-pro"
    manifest_dir.mkdir(parents=True)
    (manifest_dir / "install-manifest.json").write_text("{}", encoding="utf-8")

    proc = subprocess.run(
        [sys.executable, str(CLI_PATH), "--root-prefix", str(tmp_path), "rotate-password"],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )

    assert proc.returncode == 0
    env_text = (manifest_dir / "env").read_text(encoding="utf-8")
    assert "TROJAN_PASSWORD=" in env_text


def test_tp_reconfigure_dns_provider_fails_when_env_missing(tmp_path: Path) -> None:
    manifest_dir = tmp_path / "etc" / "trojan-pro"
    manifest_dir.mkdir(parents=True)
    manifest_path = manifest_dir / "install-manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "www_domain": "www.example.com",
                "edge_domain": "edge.example.com",
                "dns_provider": "cloudflare",
                "dns_provider_module": "dns.providers.cloudflare",
                "web_mode": "static",
                "trojan_local_port": 8443,
            }
        ),
        encoding="utf-8",
    )

    proc = subprocess.run(
        [sys.executable, str(CLI_PATH), "--root-prefix", str(tmp_path), "reconfigure-dns-provider", "gcloud"],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )

    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    assert payload["status"] == "fail"
    assert payload["missing"] == ["GCP_PROJECT", "GCP_SERVICE_ACCOUNT_JSON"]
    current = json.loads(manifest_path.read_text())
    assert current["dns_provider"] == "cloudflare"


def test_tp_export_client_bundle_writes_bundle_from_manifest(tmp_path: Path) -> None:
    manifest_dir = tmp_path / "etc" / "trojan-pro"
    manifest_dir.mkdir(parents=True)
    manifest_path = manifest_dir / "install-manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "www_domain": "www.example.com",
                "edge_domain": "edge.example.com",
                "dns_provider": "cloudflare",
                "dns_provider_module": "dns.providers.cloudflare",
                "web_mode": "static",
                "trojan_local_port": 8443,
                "bundle_server_port": 443,
                "bundle_profile_name": "Managed Edge",
            }
        ),
        encoding="utf-8",
    )

    output_path = tmp_path / "bundle.json"
    proc = subprocess.run(
        [
            sys.executable,
            str(CLI_PATH),
            "--root-prefix",
            str(tmp_path),
            "export-client-bundle",
            "--direct",
            str(FIXTURES / "clash_rules_direct.sample.txt"),
            "--proxy",
            str(FIXTURES / "clash_rules_proxy.sample.txt"),
            "--reject",
            str(FIXTURES / "clash_rules_reject.sample.txt"),
            "--output",
            str(output_path),
        ],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )

    assert proc.returncode == 0
    payload = json.loads(output_path.read_text(encoding="utf-8"))
    assert payload["profile"]["serverHost"] == "edge.example.com"
    assert payload["profile"]["name"] == "Managed Edge"
