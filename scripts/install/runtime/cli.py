#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import secrets
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

def _resolve_repo_root() -> Path:
    # Allow explicit override for debugging.
    override = os.environ.get("TP_REPO_ROOT")
    if override:
        return Path(override).expanduser().resolve()

    # PyInstaller sets sys.frozen and (normally) sys._MEIPASS.
    if getattr(sys, "frozen", False):
        mei = getattr(sys, "_MEIPASS", None)
        if mei:
            return Path(mei).resolve()
        # Fallback when _MEIPASS is not available for some reason:
        # treat the executable directory as the root.
        return Path(sys.executable).resolve().parent

    p = Path(__file__).resolve()
    if len(p.parents) >= 4:
        # .../scripts/install/runtime/cli.py -> repo root
        return p.parents[3]

    # Best-effort fallback.
    return Path.cwd().resolve()


REPO_ROOT = _resolve_repo_root()
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from scripts.install.runtime.manifest import install_paths, read_manifest, write_env_file, write_manifest, load_env_file
from scripts.install.runtime.provider_registry import load_provider_registry, validate_provider_env


@dataclass(frozen=True)
class I18n:
    language_name: str
    prompt_www_domain: str
    prompt_edge_domain: str
    prompt_dns_provider: str
    prompt_yes_to_continue: str
    abort_message: str
    plan_header: str
    plan_paths_header: str
    plan_services_header: str
    plan_rollback_header: str
    plan_kernel_header: str
    plan_post_install_header: str


I18N: dict[str, I18n] = {
    "en": I18n(
        language_name="English",
        prompt_www_domain="www domain",
        prompt_edge_domain="edge domain",
        prompt_dns_provider="dns provider",
        prompt_yes_to_continue="Type YES to continue, anything else to abort:",
        abort_message="aborted",
        plan_header="Plan",
        plan_paths_header="Paths to be written/updated",
        plan_services_header="Services that may be restarted",
        plan_rollback_header="Rollback notes",
        plan_kernel_header="Kernel commands",
        plan_post_install_header="Post-install verification",
    ),
    "zh-CN": I18n(
        language_name="中文",
        prompt_www_domain="www 域名",
        prompt_edge_domain="edge 域名",
        prompt_dns_provider="DNS provider",
        prompt_yes_to_continue="输入 YES 继续，其他任意输入将中止：",
        abort_message="已中止",
        plan_header="执行计划",
        plan_paths_header="将写入/更新的路径",
        plan_services_header="可能会重启的服务",
        plan_rollback_header="回滚说明",
        plan_kernel_header="Kernel 命令",
        plan_post_install_header="安装后验证",
    ),
}


def choose_lang(raw: str | None) -> str:
    if raw in I18N:
        return raw
    return "en"


def _prompt_line(prompt: str) -> str:
    print(prompt, flush=True)
    value = input("> ").strip()
    return value


def prompt_choose_lang() -> str:
    print("Select language / 选择语言:")
    print("1) 中文")
    print("2) English")
    choice = input("> ").strip()
    if choice == "1":
        return "zh-CN"
    if choice == "2":
        return "en"
    # Default to English on invalid input.
    return "en"


def prompt_input(label: str) -> str:
    return _prompt_line(f"{label}:")


def _print_plan(*, lang: str, root_prefix: Path, www_domain: str, edge_domain: str, dns_provider: str) -> None:
    t = I18N[lang]

    # Path plan uses default root prefix semantics.
    paths = install_paths(root_prefix)
    plan_paths = [
        str(paths["manifest"]),
        str(paths["trojan_config"]),
        str(paths["caddyfile"]),
        str(paths["env"]),
        "/usr/local/bin/tp",
        "/usr/local/bin/tpctl",
    ]

    print(f"== {t.plan_header} ==")
    print(f"{t.plan_paths_header}:")
    for p in plan_paths:
        print(f"- {p}")
    print()

    print(f"{t.plan_services_header}:")
    for svc in ["caddy-custom.service", "trojan-pro.service"]:
        print(f"- {svc}")
    print()

    print(f"{t.plan_rollback_header}:")
    print("- last-known-good backups are created for manifest / config / Caddyfile before apply")
    print("- on validate failure, backups are restored and installer exits non-zero")
    print()

    print(f"{t.plan_kernel_header}:")
    base = [
        "bash scripts/install/install-kernel.sh",
        f"  --www-domain {www_domain}",
        f"  --edge-domain {edge_domain}",
        f"  --dns-provider {dns_provider}",
    ]
    print("# preflight (check-only)")
    print("\\\n".join(base + ["  --check-only"]))
    print()
    print("# apply")
    print("\\\n".join(["sudo "+base[0]] + base[1:] + ["  --apply"]))
    print()

    print(f"{t.plan_post_install_header}:")
    print("- tp status --json")
    print("- tp validate")


def _run_kernel(*, root_prefix: Path, www_domain: str, edge_domain: str, dns_provider: str, mode: str) -> int:
    cmd = [
        "bash",
        str(REPO_ROOT / "scripts" / "install" / "install-kernel.sh"),
        "--www-domain",
        www_domain,
        "--edge-domain",
        edge_domain,
        "--dns-provider",
        dns_provider,
        mode,
    ]

    proc = subprocess.run(cmd, text=True, cwd=REPO_ROOT, check=False)
    return proc.returncode


def cmd_install(args: argparse.Namespace) -> int:
    if args.lang:
        lang = choose_lang(args.lang)
    elif args.non_interactive:
        lang = "en"
    else:
        lang = prompt_choose_lang()

    t = I18N[lang]
    root = Path(args.root_prefix)

    if args.non_interactive:
        if not args.www_domain or not args.edge_domain or not args.dns_provider:
            print("error: --www-domain, --edge-domain, and --dns-provider are required in --non-interactive mode", file=sys.stderr)
            return 2
        www_domain = args.www_domain
        edge_domain = args.edge_domain
        dns_provider = args.dns_provider
    else:
        www_domain = prompt_input(t.prompt_www_domain)
        edge_domain = prompt_input(t.prompt_edge_domain)
        dns_provider = prompt_input(t.prompt_dns_provider)

    if not www_domain or not edge_domain or not dns_provider:
        print("error: missing required inputs", file=sys.stderr)
        return 2

    registry = load_provider_registry()
    if dns_provider not in registry:
        print(f"error: unknown dns provider: {dns_provider}", file=sys.stderr)
        print("supported_providers=" + ",".join(sorted(registry.keys())), file=sys.stderr)
        return 2

    # Preflight credential check (fail closed) using the same source order as kernel.
    env = load_env_file(root)
    for key, value in os.environ.items():
        if value:
            env.setdefault(key, value)
    missing = validate_provider_env(dns_provider, env)
    if missing:
        for item in missing:
            print(f"missing_provider_env={item}", file=sys.stderr)
        return 1

    _print_plan(lang=lang, root_prefix=root, www_domain=www_domain, edge_domain=edge_domain, dns_provider=dns_provider)

    if not args.yes:
        if args.non_interactive:
            # In non-interactive mode, we do not read from stdin.
            print(t.prompt_yes_to_continue)
            return 2
        confirm = input(t.prompt_yes_to_continue + " ").strip()
        if confirm != "YES":
            print(t.abort_message, file=sys.stderr)
            return 2

    # Execute check-only then apply.
    rc = _run_kernel(root_prefix=root, www_domain=www_domain, edge_domain=edge_domain, dns_provider=dns_provider, mode="--check-only")
    if rc != 0:
        return rc
    rc = _run_kernel(root_prefix=root, www_domain=www_domain, edge_domain=edge_domain, dns_provider=dns_provider, mode="--apply")
    return rc


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

    install = sub.add_parser("install")
    install.add_argument("--lang", choices=sorted(I18N.keys()))
    install.add_argument("--non-interactive", action="store_true")
    install.add_argument("--www-domain")
    install.add_argument("--edge-domain")
    install.add_argument("--dns-provider")
    install.add_argument("--yes", action="store_true")
    install.set_defaults(func=cmd_install)

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
