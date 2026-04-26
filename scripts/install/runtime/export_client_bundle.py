from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

BUNDLE_SCRIPT_PATH = REPO_ROOT / "scripts" / "config" / "generate-client-bundle.py"
SPEC = importlib.util.spec_from_file_location("generate_client_bundle", BUNDLE_SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

build_bundle = MODULE.build_bundle
load_lock_metadata = MODULE.load_lock_metadata
load_rule_file = MODULE.load_rule_file

from scripts.install.runtime.manifest import read_manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root-prefix", required=True)
    parser.add_argument("--direct", required=True)
    parser.add_argument("--proxy", required=True)
    parser.add_argument("--reject", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    manifest = read_manifest(Path(args.root_prefix))
    bundle = build_bundle(
        direct_rules=load_rule_file(args.direct),
        proxy_rules=load_rule_file(args.proxy),
        reject_rules=load_rule_file(args.reject),
        source_meta=load_lock_metadata(),
        server_host=str(manifest["edge_domain"]),
        server_port=int(manifest.get("bundle_server_port", 443)),
        sni=str(manifest["edge_domain"]),
        profile_name=str(manifest.get("bundle_profile_name", "Managed Edge")),
    )

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(bundle, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote_bundle={output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
