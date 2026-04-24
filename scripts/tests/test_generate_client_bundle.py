import importlib.util
import json
import pathlib
import subprocess
import sys

SCRIPT_PATH = pathlib.Path(__file__).resolve().parents[1] / "config" / "generate-client-bundle.py"
FIXTURES = pathlib.Path(__file__).resolve().parent / "fixtures"

SPEC = importlib.util.spec_from_file_location("generate_client_bundle", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

load_rule_file = MODULE.load_rule_file
build_bundle = MODULE.build_bundle


def test_build_bundle_emits_importable_profile_schema_and_priority_order() -> None:
    direct_rules = load_rule_file(FIXTURES / "clash_rules_direct.sample.txt")
    proxy_rules = load_rule_file(FIXTURES / "clash_rules_proxy.sample.txt")
    reject_rules = load_rule_file(FIXTURES / "clash_rules_reject.sample.txt")

    bundle = build_bundle(
        direct_rules=direct_rules,
        proxy_rules=proxy_rules,
        reject_rules=reject_rules,
        source_meta={"schemaVersion": 1},
    )

    assert bundle["kind"] == "trojan-pro-client-profile"
    assert bundle["version"] == 2

    routing = bundle["profile"]["routing"]
    groups = {group["id"]: group for group in routing["policyGroups"]}
    assert groups["direct-group"]["action"] == "direct"
    assert groups["proxy-group"]["action"] == "proxy"
    assert groups["reject-group"]["action"] == "block"

    rules = routing["rules"]
    assert len(rules) == 7
    assert [rule["priority"] for rule in rules] == sorted(rule["priority"] for rule in rules)

    reject_priorities = [
        rule["priority"]
        for rule in rules
        if rule["action"]["policyGroupId"] == "reject-group"
    ]
    direct_priorities = [
        rule["priority"]
        for rule in rules
        if rule["action"]["policyGroupId"] == "direct-group"
    ]
    proxy_priorities = [
        rule["priority"]
        for rule in rules
        if rule["action"]["policyGroupId"] == "proxy-group"
    ]

    assert max(reject_priorities) < min(direct_priorities) < min(proxy_priorities)
    assert any(rule["match"].get("domainExact") == "localhost" for rule in rules)
    assert any(rule["match"].get("domainSuffix") == ".cn" for rule in rules)
    assert any(rule["match"].get("domainKeyword") == "openai" for rule in rules)
    assert any(rule["match"].get("ipCidr") == "10.0.0.0/8" for rule in rules)
    assert bundle["metadata"]["lock"]["schemaVersion"] == 1


def test_cli_writes_bundle_json_to_requested_output(tmp_path: pathlib.Path) -> None:
    output_path = tmp_path / "dist" / "client-import" / "trojan-pro-client-profile-sample.json"

    proc = subprocess.run(
        [
            sys.executable,
            str(SCRIPT_PATH),
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
        check=False,
    )

    assert proc.returncode == 0
    assert output_path.exists()
    payload = json.loads(output_path.read_text())
    assert payload["kind"] == "trojan-pro-client-profile"
    assert payload["profile"]["routing"]["rules"]
    assert "wrote_bundle=" in proc.stdout
