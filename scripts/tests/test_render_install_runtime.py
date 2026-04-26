import json

from scripts.install.runtime.render_runtime import render_caddyfile, render_trojan_config


def test_render_caddyfile_splits_www_and_edge() -> None:
    manifest = {
        "www_domain": "www.example.com",
        "edge_domain": "edge.example.com",
        "trojan_local_addr": "127.0.0.1",
        "trojan_local_port": 8443,
        "dns_provider_module": "dns.providers.cloudflare",
        "web_mode": "static",
    }

    rendered = render_caddyfile(manifest)
    assert "www.example.com" in rendered
    assert "edge.example.com" in rendered
    assert "127.0.0.1:8443" in rendered


def test_render_trojan_config_uses_exported_edge_cert_paths() -> None:
    manifest = {
        "edge_domain": "edge.example.com",
        "trojan_local_addr": "127.0.0.1",
        "trojan_local_port": 8443,
        "trojan_password_env_key": "TROJAN_PASSWORD",
    }

    payload = json.loads(render_trojan_config(manifest))
    assert payload["ssl"]["cert"] == "/etc/trojan-pro/certs/current/edge.crt"
    assert payload["ssl"]["key"] == "/etc/trojan-pro/certs/current/edge.key"
    assert payload["ssl"]["sni"] == "edge.example.com"
