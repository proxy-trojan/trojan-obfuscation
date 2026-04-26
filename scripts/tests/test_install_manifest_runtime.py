from pathlib import Path

from scripts.install.runtime.manifest import (
    install_paths,
    load_env_file,
    read_manifest,
    write_manifest,
)


def test_manifest_round_trip_uses_root_prefix(tmp_path: Path) -> None:
    manifest = {
        "www_domain": "www.example.com",
        "edge_domain": "edge.example.com",
        "dns_provider": "cloudflare",
        "support_tier": "full",
        "web_mode": "static",
        "trojan_local_port": 8443,
    }

    write_manifest(tmp_path, manifest)
    loaded = read_manifest(tmp_path)
    paths = install_paths(tmp_path)

    assert loaded["edge_domain"] == "edge.example.com"
    assert paths["manifest"] == tmp_path / "etc" / "trojan-pro" / "install-manifest.json"


def test_load_env_file_reads_key_values_and_skips_comments(tmp_path: Path) -> None:
    env_path = tmp_path / "etc" / "trojan-pro" / "env"
    env_path.parent.mkdir(parents=True, exist_ok=True)
    env_path.write_text(
        "# comment\nCLOUDFLARE_API_TOKEN=test-token\n\nAWS_REGION=ap-east-1\n",
        encoding="utf-8",
    )

    assert load_env_file(tmp_path) == {
        "CLOUDFLARE_API_TOKEN": "test-token",
        "AWS_REGION": "ap-east-1",
    }
