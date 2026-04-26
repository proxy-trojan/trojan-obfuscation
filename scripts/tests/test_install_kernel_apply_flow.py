import hashlib
import json
import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "scripts" / "install" / "install-kernel.sh"
FIXTURES = REPO_ROOT / "scripts" / "tests" / "fixtures"


def test_apply_writes_manifest_configs_and_certs_under_root_prefix(tmp_path: Path) -> None:
    root = tmp_path / "root"
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    for name in ["systemctl", "caddy-custom", "trojan"]:
        path = fake_bin / name
        path.write_text("#!/bin/sh\necho fake-$0 $@\nexit 0\n", encoding="utf-8")
        path.chmod(0o755)

    source_dir = tmp_path / "sources"
    source_dir.mkdir()
    trojan_src = source_dir / "trojan-linux-amd64"
    trojan_src.write_text("#!/bin/sh\necho trojan\n", encoding="utf-8")
    trojan_src.chmod(0o755)
    caddy_src = source_dir / "caddy-custom-linux-amd64"
    caddy_src.write_text("#!/bin/sh\necho caddy\n", encoding="utf-8")
    caddy_src.chmod(0o755)

    env = os.environ | {
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
        "INSTALL_ROOT_PREFIX": str(root),
        "INSTALL_CERT_BOOTSTRAP_MODE": "fixtures",
        "INSTALL_CERT_FIXTURE_DIR": str(FIXTURES.resolve()),
        "INSTALL_BINARIES_LOCK": str(REPO_ROOT / "scripts" / "install" / "artifacts" / "binaries.lock.json"),
        "INSTALL_TARGET_KEY": "linux-amd64",
        "CLOUDFLARE_API_TOKEN": "token",
        "TEST_TROJAN_BIN_URL": trojan_src.as_uri(),
        "TEST_TROJAN_BIN_SHA256": hashlib.sha256(trojan_src.read_bytes()).hexdigest(),
        "TEST_CADDY_BIN_URL": caddy_src.as_uri(),
        "TEST_CADDY_BIN_SHA256": hashlib.sha256(caddy_src.read_bytes()).hexdigest(),
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
            "--apply",
        ],
        text=True,
        capture_output=True,
        env=env,
        cwd=REPO_ROOT,
        check=False,
    )

    assert proc.returncode == 0
    manifest = json.loads((root / "etc" / "trojan-pro" / "install-manifest.json").read_text())
    assert manifest["www_domain"] == "www.example.com"
    assert (root / "etc" / "trojan-pro" / "config.json").exists()
    assert (root / "etc" / "caddy" / "Caddyfile").exists()
    assert (root / "etc" / "trojan-pro" / "certs" / "current" / "edge.crt").exists()
    assert "phase=validate" in proc.stdout


def test_apply_restores_last_known_good_when_validate_fails(tmp_path: Path) -> None:
    root = tmp_path / "root"
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    for name in ["systemctl", "caddy-custom", "trojan"]:
        path = fake_bin / name
        path.write_text("#!/bin/sh\necho fake-$0 $@\nexit 0\n", encoding="utf-8")
        path.chmod(0o755)

    source_dir = tmp_path / "sources"
    source_dir.mkdir()
    trojan_src = source_dir / "trojan-linux-amd64"
    trojan_src.write_text("#!/bin/sh\necho trojan\n", encoding="utf-8")
    trojan_src.chmod(0o755)
    caddy_src = source_dir / "caddy-custom-linux-amd64"
    caddy_src.write_text("#!/bin/sh\necho caddy\n", encoding="utf-8")
    caddy_src.chmod(0o755)

    old_manifest = root / "etc" / "trojan-pro" / "install-manifest.json"
    old_manifest.parent.mkdir(parents=True, exist_ok=True)
    old_manifest.write_text(json.dumps({"www_domain": "old.example.com"}), encoding="utf-8")
    old_caddy = root / "etc" / "caddy" / "Caddyfile"
    old_caddy.parent.mkdir(parents=True, exist_ok=True)
    old_caddy.write_text("old-good", encoding="utf-8")

    env = os.environ | {
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
        "INSTALL_ROOT_PREFIX": str(root),
        "INSTALL_CERT_BOOTSTRAP_MODE": "fixtures",
        "INSTALL_CERT_FIXTURE_DIR": str(FIXTURES.resolve()),
        "INSTALL_BINARIES_LOCK": str(REPO_ROOT / "scripts" / "install" / "artifacts" / "binaries.lock.json"),
        "INSTALL_TARGET_KEY": "linux-amd64",
        "CLOUDFLARE_API_TOKEN": "token",
        "TEST_TROJAN_BIN_URL": trojan_src.as_uri(),
        "TEST_TROJAN_BIN_SHA256": hashlib.sha256(trojan_src.read_bytes()).hexdigest(),
        "TEST_CADDY_BIN_URL": caddy_src.as_uri(),
        "TEST_CADDY_BIN_SHA256": hashlib.sha256(caddy_src.read_bytes()).hexdigest(),
        "INSTALL_FORCE_VALIDATE_FAIL": "1",
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
            "--apply",
        ],
        text=True,
        capture_output=True,
        env=env,
        cwd=REPO_ROOT,
        check=False,
    )

    assert proc.returncode != 0
    assert old_caddy.read_text(encoding="utf-8") == "old-good"
