#!/usr/bin/env python3
from __future__ import annotations

import argparse
import ipaddress
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_LOCK_PATH = SCRIPT_DIR / "sources" / "clash-rules.lock"
SUPPORTED_RULE_TYPES = {
    "DOMAIN",
    "DOMAIN-SUFFIX",
    "DOMAIN-KEYWORD",
    "IP-CIDR",
}


@dataclass(frozen=True)
class ParsedRule:
    rule_type: str
    value: str


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _normalize_domain(value: str) -> str:
    normalized = value.strip().lower().rstrip(".")
    if not normalized:
        raise ValueError("domain value is empty")
    return normalized


def _normalize_domain_suffix(value: str) -> str:
    normalized = value.strip().lower().strip(".")
    if not normalized:
        raise ValueError("domain suffix value is empty")
    return normalized


def _normalize_keyword(value: str) -> str:
    normalized = value.strip().lower()
    if not normalized:
        raise ValueError("domain keyword value is empty")
    return normalized


def _normalize_ip_cidr(value: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError("ip cidr value is empty")
    return str(ipaddress.ip_network(normalized, strict=False))


def parse_rule_line(raw_line: str) -> ParsedRule | None:
    line = raw_line.split("#", 1)[0].strip()
    if not line or line in {"payload:", "payload"}:
        return None
    if line.startswith("-"):
        line = line[1:].strip()
    if not line:
        return None

    parts = [part.strip() for part in line.split(",")]
    if len(parts) < 2:
        raise ValueError(f"invalid rule line: {raw_line.strip()}")

    rule_type = parts[0].upper()
    if rule_type not in SUPPORTED_RULE_TYPES:
        raise ValueError(f"unsupported rule type: {rule_type}")

    raw_value = parts[1]
    if rule_type == "DOMAIN":
        value = _normalize_domain(raw_value)
    elif rule_type == "DOMAIN-SUFFIX":
        value = _normalize_domain_suffix(raw_value)
    elif rule_type == "DOMAIN-KEYWORD":
        value = _normalize_keyword(raw_value)
    else:
        value = _normalize_ip_cidr(raw_value)

    return ParsedRule(rule_type=rule_type, value=value)


def load_rule_file(path: str | Path) -> list[ParsedRule]:
    source_path = Path(path)
    rules: list[ParsedRule] = []

    for line_number, raw_line in enumerate(source_path.read_text(encoding="utf-8").splitlines(), start=1):
        try:
            parsed = parse_rule_line(raw_line)
        except ValueError as exc:
            raise ValueError(f"{source_path}:{line_number}: {exc}") from exc
        if parsed is not None:
            rules.append(parsed)

    return rules


def load_lock_metadata(path: str | Path = DEFAULT_LOCK_PATH) -> dict[str, object]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _match_payload(rule: ParsedRule) -> dict[str, str]:
    if rule.rule_type == "DOMAIN":
        return {"domainExact": rule.value}
    if rule.rule_type == "DOMAIN-SUFFIX":
        return {"domainSuffix": f".{rule.value}"}
    if rule.rule_type == "DOMAIN-KEYWORD":
        return {"domainKeyword": rule.value}
    if rule.rule_type == "IP-CIDR":
        return {"ipCidr": rule.value}
    raise ValueError(f"unsupported rule type: {rule.rule_type}")


def _rule_name(kind: str, rule: ParsedRule) -> str:
    return f"{kind} {rule.rule_type.lower()} {rule.value}"


def _build_routing_rules(category: str, rules: Iterable[ParsedRule], *, base_priority: int, policy_group_id: str) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for index, rule in enumerate(rules, start=1):
        result.append(
            {
                "id": f"rule-{category}-{index:04d}",
                "name": _rule_name(category, rule),
                "enabled": True,
                "priority": base_priority + index,
                "match": _match_payload(rule),
                "action": {
                    "kind": "policyGroup",
                    "policyGroupId": policy_group_id,
                },
            }
        )
    return result


def build_bundle(
    *,
    direct_rules: Iterable[ParsedRule],
    proxy_rules: Iterable[ParsedRule],
    reject_rules: Iterable[ParsedRule],
    source_meta: dict[str, object] | None = None,
    server_host: str = "example.com",
    server_port: int = 443,
    sni: str = "example.com",
    profile_name: str = "Generated Clash Rules Bundle",
) -> dict[str, object]:
    direct_rules = list(direct_rules)
    proxy_rules = list(proxy_rules)
    reject_rules = list(reject_rules)
    if not (direct_rules or proxy_rules or reject_rules):
        raise ValueError("effective rule set is empty")

    routing_rules = [
        *_build_routing_rules(
            "reject",
            reject_rules,
            base_priority=100,
            policy_group_id="reject-group",
        ),
        *_build_routing_rules(
            "direct",
            direct_rules,
            base_priority=200,
            policy_group_id="direct-group",
        ),
        *_build_routing_rules(
            "proxy",
            proxy_rules,
            base_priority=300,
            policy_group_id="proxy-group",
        ),
    ]

    routing_rules.sort(key=lambda item: (int(item["priority"]), str(item["id"])))
    generated_at = _utc_now_iso()

    return {
        "version": 2,
        "kind": "trojan-pro-client-profile",
        "metadata": {
            "generatedAt": generated_at,
            "source": "clash-rules",
            "lock": source_meta or {},
        },
        "profile": {
            "id": "generated-clash-rules-profile",
            "name": profile_name,
            "serverHost": server_host,
            "serverPort": server_port,
            "sni": sni,
            "localSocksPort": 1080,
            "verifyTls": True,
            "notes": "Generated from clash-rules snapshots; replace server fields before production use.",
            "updatedAt": generated_at,
            "routing": {
                "mode": "rule",
                "defaultAction": "proxy",
                "globalAction": "proxy",
                "policyGroups": [
                    {
                        "id": "direct-group",
                        "name": "Direct",
                        "action": "direct",
                    },
                    {
                        "id": "proxy-group",
                        "name": "Proxy",
                        "action": "proxy",
                    },
                    {
                        "id": "reject-group",
                        "name": "Reject",
                        "action": "block",
                    },
                ],
                "rules": routing_rules,
            },
        },
        "secrets": {
            "trojanPasswordIncluded": False,
            "sourceDeviceHadStoredPassword": False,
            "importBehavior": "reenter_or_restore_secure_storage",
        },
    }


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a trojan-pro client import bundle from clash-rules snapshots.",
    )
    parser.add_argument("--direct", required=True, help="Path to direct clash-rules text file")
    parser.add_argument("--proxy", required=True, help="Path to proxy clash-rules text file")
    parser.add_argument("--reject", required=True, help="Path to reject clash-rules text file")
    parser.add_argument("--output", required=True, help="Output JSON path under dist/client-import/")
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    direct_rules = load_rule_file(args.direct)
    proxy_rules = load_rule_file(args.proxy)
    reject_rules = load_rule_file(args.reject)
    bundle = build_bundle(
        direct_rules=direct_rules,
        proxy_rules=proxy_rules,
        reject_rules=reject_rules,
        source_meta=load_lock_metadata(),
    )

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(bundle, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(f"wrote_bundle={output_path}")
    print(f"rule_count={len(bundle['profile']['routing']['rules'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
