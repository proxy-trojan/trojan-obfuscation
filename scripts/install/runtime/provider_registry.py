from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


REGISTRY_PATH = Path(__file__).resolve().parents[1] / "providers" / "dns-providers.json"


@dataclass(frozen=True)
class ProviderSpec:
    id: str
    support_tier: str
    caddy_dns_module: str
    required_env_keys: list[str]
    optional_env_keys: list[str]


def load_provider_registry() -> dict[str, ProviderSpec]:
    payload = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    return {item["id"]: ProviderSpec(**item) for item in payload["providers"]}


def validate_provider_env(provider_id: str, env: dict[str, str]) -> list[str]:
    spec = load_provider_registry()[provider_id]
    return [key for key in spec.required_env_keys if not env.get(key)]
