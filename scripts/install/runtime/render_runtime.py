from __future__ import annotations

import json
from string import Template
from typing import Any


def render_caddyfile(manifest: dict[str, Any]) -> str:
    return Template(
        """:80 {
    redir https://$www_domain{uri}
}

$www_domain {
    tls {
        dns $dns_provider_module
    }
    root * /var/lib/trojan-pro/site
    file_server
}

{
    layer4 {
        :443 {
            @edge tls sni $edge_domain
            route @edge {
                proxy 127.0.0.1:$edge_port
            }
        }
    }
}
"""
    ).substitute(
        www_domain=str(manifest["www_domain"]),
        edge_domain=str(manifest["edge_domain"]),
        edge_port=int(manifest["trojan_local_port"]),
        dns_provider_module=str(manifest["dns_provider_module"]),
    )


def render_trojan_config(manifest: dict[str, Any]) -> str:
    payload = {
        "run_type": "server",
        "local_addr": manifest.get("trojan_local_addr", "127.0.0.1"),
        "local_port": manifest["trojan_local_port"],
        "remote_addr": "127.0.0.1",
        "remote_port": 80,
        "password_env": manifest.get("trojan_password_env_key", "TROJAN_PASSWORD"),
        "ssl": {
            "cert": "/etc/trojan-pro/certs/current/edge.crt",
            "key": "/etc/trojan-pro/certs/current/edge.key",
            "sni": manifest["edge_domain"],
        },
    }
    return json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
