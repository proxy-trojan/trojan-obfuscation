from scripts.install.runtime.provider_registry import (
    load_provider_registry,
    validate_provider_env,
)


def test_provider_registry_exposes_full_support_tiers() -> None:
    registry = load_provider_registry()

    assert registry["cloudflare"].support_tier == "full"
    assert registry["gcloud"].support_tier == "full"
    assert "CLOUDFLARE_API_TOKEN" in registry["cloudflare"].required_env_keys


def test_validate_provider_env_reports_missing_keys() -> None:
    errors = validate_provider_env("dnspod", {"DNSPOD_TOKEN": "abc"})

    assert errors == ["DNSPOD_SECRET_ID", "DNSPOD_SECRET_KEY"]
