#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import secrets
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from scripts.install.runtime.manifest import install_paths, read_manifest, write_env_file, write_manifest, load_env_file
from scripts.install.runtime.provider_registry import load_provider_registry, validate_provider_env


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


def cmd_set_web_mode(args: argparse.Namespace) -> int:
    root = Path(args.root_prefix)
    manifest = read_manifest(root)
    manifest["web_mode"] = args.mode
    if args.mode == "upstream":
        manifest["web_upstream"] = args.upstream
    else:
        manifest.pop("web_upstream", None)
    write_manifest(root, manifest)
    return 0


def cmd_rotate_password(args: argparse.Namespace) -> int:
    root = Path(args.root_prefix)
    env = load_env_file(root)
    env["TROJAN_PASSWORD"] = secrets.token_urlsafe(24)
    write_env_file(root, env)
    return 0


def cmd_reconfigure_dns_provider(args: argparse.Namespace) -> int:
    root = Path(args.root_prefix)
    manifest = read_manifest(root)
    env = load_env_file(root)
    missing = validate_provider_env(args.provider, env)
    if missing:
        print(json.dumps({"status": "fail", "missing": missing}, ensure_ascii=False))
        return 1
    registry = load_provider_registry()
    manifest["dns_provider"] = args.provider
    manifest["dns_provider_module"] = registry[args.provider].caddy_dns_module
    manifest["support_tier"] = registry[args.provider].support_tier
    write_manifest(root, manifest)
    return 0


def cmd_export_client_bundle(args: argparse.Namespace) -> int:
    proc = subprocess.run(
        [
            sys.executable,
            str(REPO_ROOT / "scripts" / "install" / "runtime" / "export_client_bundle.py"),
            "--root-prefix",
            str(args.root_prefix),
            "--direct",
            args.direct,
            "--proxy",
            args.proxy,
            "--reject",
            args.reject,
            "--output",
            args.output,
        ],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )
    if proc.stdout:
        print(proc.stdout, end="")
    if proc.stderr:
        print(proc.stderr, end="", file=sys.stderr)
    return proc.returncode


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="tp")
    parser.add_argument("--root-prefix", default="/", help=argparse.SUPPRESS)
    sub = parser.add_subparsers(dest="command", required=True)

    status = sub.add_parser("status")
    status.add_argument("--json", action="store_true")
    status.set_defaults(func=cmd_status)

    validate = sub.add_parser("validate")
    validate.set_defaults(func=cmd_validate)

    set_web_mode = sub.add_parser("set-web-mode")
    set_web_mode.add_argument("mode", choices=["static", "upstream"])
    set_web_mode.add_argument("--upstream")
    set_web_mode.set_defaults(func=cmd_set_web_mode)

    rotate_password = sub.add_parser("rotate-password")
    rotate_password.set_defaults(func=cmd_rotate_password)

    reconfigure_dns = sub.add_parser("reconfigure-dns-provider")
    reconfigure_dns.add_argument("provider")
    reconfigure_dns.set_defaults(func=cmd_reconfigure_dns_provider)

    export_bundle = sub.add_parser("export-client-bundle")
    export_bundle.add_argument("--direct", required=True)
    export_bundle.add_argument("--proxy", required=True)
    export_bundle.add_argument("--reject", required=True)
    export_bundle.add_argument("--output", required=True)
    export_bundle.set_defaults(func=cmd_export_client_bundle)
    return parser


if __name__ == "__main__":
    ns = build_parser().parse_args()
    raise SystemExit(ns.func(ns))
