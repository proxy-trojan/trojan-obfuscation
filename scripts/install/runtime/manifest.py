from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def install_paths(root_prefix: Path | str) -> dict[str, Path]:
    root = Path(root_prefix)
    return {
        "manifest": root / "etc" / "trojan-pro" / "install-manifest.json",
        "env": root / "etc" / "trojan-pro" / "env",
        "trojan_config": root / "etc" / "trojan-pro" / "config.json",
        "caddyfile": root / "etc" / "caddy" / "Caddyfile",
    }


def write_manifest(root_prefix: Path | str, payload: dict[str, Any]) -> None:
    path = install_paths(root_prefix)["manifest"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def read_manifest(root_prefix: Path | str) -> dict[str, Any]:
    path = install_paths(root_prefix)["manifest"]
    return json.loads(path.read_text(encoding="utf-8"))


def load_env_file(root_prefix: Path | str) -> dict[str, str]:
    path = install_paths(root_prefix)["env"]
    if not path.exists():
        return {}

    result: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key] = value
    return result


def write_env_file(root_prefix: Path | str, env: dict[str, str]) -> None:
    path = install_paths(root_prefix)["env"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(f"{key}={value}\n" for key, value in sorted(env.items())), encoding="utf-8")
