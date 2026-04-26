#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from scripts.install.runtime.manifest import install_paths, read_manifest


def cmd_status(args: argparse.Namespace) -> int:
    manifest = read_manifest(Path(args.root_prefix))
    if args.json:
        print(json.dumps(manifest, indent=2, ensure_ascii=False))
    else:
        print(f"www={manifest['www_domain']}")
        print(f"edge={manifest['edge_domain']}")
        print(f"dns_provider={manifest['dns_provider']}")
        print(f"web_mode={manifest['web_mode']}")
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    paths = install_paths(Path(args.root_prefix))
    required = [paths['manifest'], paths['trojan_config'], paths['caddyfile']]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        print(json.dumps({"status": "fail", "missing": missing}, ensure_ascii=False))
        return 1
    print(json.dumps({"status": "ok"}, ensure_ascii=False))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="tp")
    parser.add_argument("--root-prefix", default="/", help=argparse.SUPPRESS)
    sub = parser.add_subparsers(dest="command", required=True)

    status = sub.add_parser("status")
    status.add_argument("--json", action="store_true")
    status.set_defaults(func=cmd_status)

    validate = sub.add_parser("validate")
    validate.set_defaults(func=cmd_validate)
    return parser


if __name__ == "__main__":
    ns = build_parser().parse_args()
    raise SystemExit(ns.func(ns))
