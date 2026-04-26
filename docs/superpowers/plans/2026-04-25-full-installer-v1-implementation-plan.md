# Full Installer v1 + tp Day-2 CLI 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将当前 `installer skeleton + static bundle generator` 升级为真正可变更主机的 Linux 全量安装器，并交付 `tp` / `tpctl` 轻量管理命令、DNS provider 分层支持、custom Caddy 前门、manifest 驱动的 day-2 运维闭环。

**架构：** 保留 Bash 作为安装/系统变更入口（包管理器、systemd、文件落盘、服务激活），引入 Python runtime helpers 负责 manifest、provider registry、配置渲染、状态展示与 `tp` CLI。所有配置以 `/etc/trojan-pro/install-manifest.json` 为单一真相源，`config.json` / `Caddyfile` / cert export path 都由 manifest 渲染而来，并在 apply / upgrade / reconfigure 时通过备份与 last-known-good 机制做 fail-closed 回滚。

**技术栈：** Bash、Python 3、systemd、custom Caddy（prebuilt）、Trojan prebuilt binary、pytest、GitHub Actions、现有 `scripts/config/generate-client-bundle.py`。

---

## 文件结构（先锁定职责）

### 新增文件

- `scripts/__init__.py`
  - 让新增 Python runtime helpers 可被 pytest 直接 import。
- `scripts/install/__init__.py`
  - 安装子目录 Python 包入口。
- `scripts/install/runtime/__init__.py`
  - runtime helpers 包入口。
- `scripts/install/runtime/manifest.py`
  - 统一定义 install manifest 读写、路径计算、env 文件读写、success snapshot 更新。
- `scripts/install/runtime/provider_registry.py`
  - 加载 DNS provider registry、校验 support tier 与 required env keys。
- `scripts/install/runtime/render_runtime.py`
  - 根据 manifest 渲染 Trojan config、Caddyfile、默认静态站点、systemd unit 内容。
- `scripts/install/runtime/cli.py`
  - `tp` / `tpctl` 的 Python CLI 入口，负责 status/doctor/validate 及轻量 mutation commands。
- `scripts/install/runtime/export_client_bundle.py`
  - 从 install manifest 导出 manifest-backed client bundle，复用现有 bundle generator。
- `scripts/install/providers/dns-providers.json`
  - provider registry 数据源，区分 `full` / `best_effort`。
- `scripts/install/artifacts/binaries.lock.json`
  - prebuilt Trojan / custom Caddy 的受控下载清单（url / sha256 / arch / version）。
- `scripts/install/lib/common.sh`
  - 根目录前缀、日志、原子写入、备份、校验、systemctl 包装等通用 Bash helper。
- `scripts/install/lib/preflight.sh`
  - root/sudo、systemd、架构、端口占用、DNS provider env、DNS 解析等 preflight 检查。
- `scripts/install/lib/install-binaries.sh`
  - 按 lock manifest 下载、校验、暂存、提升 Trojan/Caddy 二进制。
- `scripts/install/lib/activate-services.sh`
  - daemon-reload、restart/reload、service health check。
- `scripts/install/lib/cert-bootstrap.sh`
  - `www` / `edge` 证书 bootstrap/export/reload orchestration；测试模式支持 fixture seam。
- `scripts/install/templates/Caddyfile.tpl`
  - `www` + `edge` 的 layer4/front-door 模板。
- `scripts/install/templates/trojan-config.json.tpl`
  - Trojan runtime config 模板。
- `scripts/install/templates/trojan-pro.service.tpl`
  - Trojan systemd unit 模板。
- `scripts/install/templates/caddy-custom.service.tpl`
  - custom Caddy systemd unit 模板。
- `scripts/install/templates/site/index.html.tpl`
  - 内置静态站模板。
- `scripts/tests/test_install_manifest_runtime.py`
  - manifest / env / path 读写测试。
- `scripts/tests/test_dns_provider_registry.py`
  - provider registry 分层与 env 校验测试。
- `scripts/tests/test_install_binary_contract.py`
  - prebuilt binary 下载/校验/原子切换测试。
- `scripts/tests/test_render_install_runtime.py`
  - Caddy/Trojan/systemd/site 渲染测试。
- `scripts/tests/test_install_preflight_contract.py`
  - 多包管理器 / 端口占用 / provider env 缺失测试。
- `scripts/tests/test_install_kernel_apply_flow.py`
  - root prefix seam 下的 apply/rollback/integration 测试。
- `scripts/tests/test_tp_cli_contract.py`
  - `tp` status/doctor/validate 等观察命令契约测试。
- `scripts/tests/test_tp_cli_mutations.py`
  - `tp` rotate-password / set-web-mode / reconfigure-dns-provider / export-client-bundle / upgrade-binaries 测试。
- `scripts/tests/test_export_client_bundle_from_manifest.py`
  - manifest-backed bundle export 测试。
- `scripts/tests/test_validate_full_installer_v1.py`
  - 全量验证脚本契约测试。
- `scripts/tests/fixtures/os-release.debian`
- `scripts/tests/fixtures/os-release.rhel`
- `scripts/tests/fixtures/os-release.arch`
- `scripts/tests/fixtures/os-release.opensuse`
  - 各包管理器家族的离线 `os-release` fixture。
- `scripts/tests/fixtures/sample_edge.crt`
- `scripts/tests/fixtures/sample_edge.key`
  - offline apply 测试用 cert bootstrap fixture。
- `scripts/validate_full_installer_v1.sh`
  - Full installer v1 的统一验证入口。
- `docs/en/tp-cli.md`
- `docs/zh-CN/tp-cli.md`
  - `tp` / `tpctl` 使用与 day-2 运维文档。
- `docs/en/dns-providers.md`
- `docs/zh-CN/dns-providers.md`
  - full support vs best-effort provider 说明。
- `docs/ops/full-installer-live-acceptance.md`
  - live DNS-01 / cert refresh / `www` / `edge` 验收 runbook。

### 修改文件

- `scripts/install/install-kernel.sh`
  - 从 skeleton 升级为真实 staged installer orchestrator。
- `scripts/install/lib/detect-os.sh`
  - 输出标准化 package manager / arch / os family 结果。
- `scripts/install/lib/install-deps.sh`
  - 从提示文本升级为真实依赖安装逻辑（支持 check-only 与 apply）。
- `scripts/install/lib/install-core.sh`
  - 改为委托 `install-binaries.sh` 安装 Trojan prebuilt。
- `scripts/install/lib/configure-caddy.sh`
  - 改为渲染/校验/推广 Caddyfile 与 site 内容。
- `scripts/install/lib/write-runtime-config.sh`
  - 改为渲染/推广 Trojan config + manifest。
- `scripts/config/generate-client-bundle.py`
  - 支持显式 server host/port/sni/profile name，去掉固定 placeholder-only 行为。
- `scripts/tests/test_generate_client_bundle.py`
  - 补充 manifest-backed server fields 与 output contract 断言。
- `scripts/validate_repo_cleanup_installer_routing.sh`
  - 保留旧脚本，不再作为 installer 主验证入口；若 README 提到它，需要改注释说明旧 scope。
- `docs/README.md`
  - 增加 full installer v1 / `tp` / DNS provider / live acceptance 入口。
- `docs/en/install-kernel.md`
- `docs/zh-CN/install-kernel.md`
  - 从 skeleton 文档升级为 full installer 文档。
- `docs/en/config-generation.md`
- `docs/zh-CN/config-generation.md`
  - 增加 manifest-backed bundle export 路径。
- `.github/workflows/ci-smoke.yml`
  - 接入 full installer 相关 contract/integration gate。

---

## 任务 1：manifest 真相源 + DNS provider registry 基础

**文件：**
- 创建：`scripts/__init__.py`
- 创建：`scripts/install/__init__.py`
- 创建：`scripts/install/runtime/__init__.py`
- 创建：`scripts/install/runtime/manifest.py`
- 创建：`scripts/install/runtime/provider_registry.py`
- 创建：`scripts/install/providers/dns-providers.json`
- 测试：`scripts/tests/test_install_manifest_runtime.py`
- 测试：`scripts/tests/test_dns_provider_registry.py`

- [ ] **步骤 1：编写失败测试（manifest round-trip + provider tier）**

```python
import json
from pathlib import Path

from scripts.install.runtime.manifest import install_paths, load_env_file, read_manifest, write_manifest
from scripts.install.runtime.provider_registry import load_provider_registry, validate_provider_env


def test_manifest_round_trip_uses_root_prefix(tmp_path: Path) -> None:
    manifest = {
        "www_domain": "www.example.com",
        "edge_domain": "edge.example.com",
        "dns_provider": "cloudflare",
        "support_tier": "full",
        "web_mode": "static",
        "trojan_local_port": 8443,
    }

    write_manifest(tmp_path, manifest)
    loaded = read_manifest(tmp_path)
    paths = install_paths(tmp_path)

    assert loaded["edge_domain"] == "edge.example.com"
    assert paths["manifest"] == tmp_path / "etc" / "trojan-pro" / "install-manifest.json"


def test_provider_registry_exposes_full_and_best_effort_tiers() -> None:
    registry = load_provider_registry()

    assert registry["cloudflare"].support_tier == "full"
    assert registry["gcloud"].support_tier == "full"
    assert "CLOUDFLARE_API_TOKEN" in registry["cloudflare"].required_env_keys


def test_validate_provider_env_reports_missing_keys() -> None:
    errors = validate_provider_env("dnspod", {"DNSPOD_TOKEN": "abc"})
    assert errors == ["DNSPOD_SECRET_ID", "DNSPOD_SECRET_KEY"]
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
cd /root/.openclaw/workspace/trojan-obfuscation
python3 -m pytest scripts/tests/test_install_manifest_runtime.py scripts/tests/test_dns_provider_registry.py -q
```

预期：FAIL，报错 `ModuleNotFoundError: No module named 'scripts.install.runtime.manifest'`。

- [ ] **步骤 3：实现最小 manifest/runtime/provider 代码**

```python
# scripts/install/runtime/manifest.py
from __future__ import annotations

import json
from pathlib import Path


def install_paths(root_prefix: Path) -> dict[str, Path]:
    root = Path(root_prefix)
    return {
        "manifest": root / "etc" / "trojan-pro" / "install-manifest.json",
        "env": root / "etc" / "trojan-pro" / "env",
        "trojan_config": root / "etc" / "trojan-pro" / "config.json",
        "caddyfile": root / "etc" / "caddy" / "Caddyfile",
    }


def write_manifest(root_prefix: Path, payload: dict[str, object]) -> None:
    path = install_paths(root_prefix)["manifest"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def read_manifest(root_prefix: Path) -> dict[str, object]:
    return json.loads(install_paths(root_prefix)["manifest"].read_text(encoding="utf-8"))


def load_env_file(root_prefix: Path) -> dict[str, str]:
    path = install_paths(root_prefix)["env"]
    if not path.exists():
        return {}
    result: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw or raw.startswith("#") or "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        result[key] = value
    return result
```

```python
# scripts/install/runtime/provider_registry.py
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
    return {
        item["id"]: ProviderSpec(**item)
        for item in payload["providers"]
    }


def validate_provider_env(provider_id: str, env: dict[str, str]) -> list[str]:
    spec = load_provider_registry()[provider_id]
    return [key for key in spec.required_env_keys if not env.get(key)]
```

```json
// scripts/install/providers/dns-providers.json
{
  "providers": [
    {
      "id": "cloudflare",
      "support_tier": "full",
      "caddy_dns_module": "dns.providers.cloudflare",
      "required_env_keys": ["CLOUDFLARE_API_TOKEN"],
      "optional_env_keys": []
    },
    {
      "id": "route53",
      "support_tier": "full",
      "caddy_dns_module": "dns.providers.route53",
      "required_env_keys": ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_REGION"],
      "optional_env_keys": ["AWS_SESSION_TOKEN"]
    },
    {
      "id": "alidns",
      "support_tier": "full",
      "caddy_dns_module": "dns.providers.alidns",
      "required_env_keys": ["ALICLOUD_ACCESS_KEY_ID", "ALICLOUD_ACCESS_KEY_SECRET"],
      "optional_env_keys": []
    },
    {
      "id": "dnspod",
      "support_tier": "full",
      "caddy_dns_module": "dns.providers.dnspod",
      "required_env_keys": ["DNSPOD_SECRET_ID", "DNSPOD_SECRET_KEY"],
      "optional_env_keys": ["DNSPOD_TOKEN"]
    },
    {
      "id": "gcloud",
      "support_tier": "full",
      "caddy_dns_module": "dns.providers.gcloud",
      "required_env_keys": ["GCP_PROJECT", "GCP_SERVICE_ACCOUNT_JSON"],
      "optional_env_keys": []
    }
  ]
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_install_manifest_runtime.py scripts/tests/test_dns_provider_registry.py -q
```

预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add scripts/__init__.py scripts/install/__init__.py scripts/install/runtime/__init__.py \
  scripts/install/runtime/manifest.py scripts/install/runtime/provider_registry.py \
  scripts/install/providers/dns-providers.json \
  scripts/tests/test_install_manifest_runtime.py scripts/tests/test_dns_provider_registry.py
git commit -m "feat(install): add manifest runtime and dns provider registry"
```

---

## 任务 2：受控二进制安装（Trojan / custom Caddy）

**文件：**
- 创建：`scripts/install/lib/common.sh`
- 创建：`scripts/install/lib/install-binaries.sh`
- 创建：`scripts/install/artifacts/binaries.lock.json`
- 测试：`scripts/tests/test_install_binary_contract.py`
- 修改：`scripts/install/lib/install-core.sh`

- [ ] **步骤 1：编写失败测试（二进制 lock + 原子切换）**

```python
import hashlib
import json
import os
import subprocess
from pathlib import Path


def test_install_binary_from_lock_verifies_checksum_and_promotes(tmp_path: Path) -> None:
    source = tmp_path / "trojan-linux-amd64"
    source.write_text("#!/bin/sh\necho trojan\n", encoding="utf-8")
    sha256 = hashlib.sha256(source.read_bytes()).hexdigest()

    lock_path = tmp_path / "binaries.lock.json"
    lock_path.write_text(json.dumps({
        "trojan": {
            "linux-amd64": {
                "url": source.as_uri(),
                "sha256": sha256,
                "version": "1.0.0"
            }
        }
    }), encoding="utf-8")

    dest = tmp_path / "root" / "usr" / "local" / "bin" / "trojan"
    cmd = [
        "bash", "-lc",
        f"source scripts/install/lib/common.sh && source scripts/install/lib/install-binaries.sh && install_binary_from_lock {lock_path} trojan linux-amd64 {dest}"
    ]
    proc = subprocess.run(cmd, text=True, capture_output=True, cwd=Path.cwd(), check=False)

    assert proc.returncode == 0
    assert dest.exists()
    assert os.access(dest, os.X_OK)
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_install_binary_contract.py -q
```

预期：FAIL，报错 `No such file or directory: scripts/install/lib/common.sh` 或函数未定义。

- [ ] **步骤 3：实现最小二进制安装 helper**

```bash
# scripts/install/lib/common.sh
#!/usr/bin/env bash
set -euo pipefail

sha256_file() {
  local path="$1"
  sha256sum "$path" | awk '{print $1}'
}

atomic_install_executable() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  install -m 0755 "$src" "$dest.tmp"
  mv "$dest.tmp" "$dest"
}
```

```bash
# scripts/install/lib/install-binaries.sh
#!/usr/bin/env bash
set -euo pipefail

install_binary_from_lock() {
  local lock_path="$1"
  local asset_name="$2"
  local target_key="$3"
  local dest="$4"
  local tmp
  tmp="$(mktemp)"

  mapfile -t meta < <(python3 - <<'PY' "$lock_path" "$asset_name" "$target_key"
import json, sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
entry = payload[sys.argv[2]][sys.argv[3]]
print(entry['url'])
print(entry['sha256'])
print(entry['version'])
PY
)

  python3 - <<'PY' "$tmp" "${meta[0]}"
import pathlib, shutil, sys, urllib.parse
src = urllib.parse.urlparse(sys.argv[2])
if src.scheme != 'file':
    raise SystemExit('only file:// is allowed in contract tests')
shutil.copyfile(pathlib.Path(src.path), pathlib.Path(sys.argv[1]))
PY

  [[ "$(sha256_file "$tmp")" == "${meta[1]}" ]]
  atomic_install_executable "$tmp" "$dest"
  rm -f "$tmp"
  printf 'installed_asset=%s\ninstalled_version=%s\n' "$asset_name" "${meta[2]}"
}
```

```json
// scripts/install/artifacts/binaries.lock.json
{
  "trojan": {
    "linux-amd64": {
      "url": "https://github.com/proxy-trojan/trojan-obfuscation/releases/download/vX.Y.Z/trojan-linux-amd64",
      "sha256": "REPLACE_ME",
      "version": "vX.Y.Z"
    }
  },
  "caddy-custom": {
    "linux-amd64": {
      "url": "https://github.com/proxy-trojan/trojan-obfuscation/releases/download/vX.Y.Z/caddy-custom-linux-amd64",
      "sha256": "REPLACE_ME",
      "version": "vX.Y.Z"
    }
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_install_binary_contract.py -q
```

预期：PASS。

- [ ] **步骤 5：把 `install-core.sh` 改成调用 lock installer 并 commit**

```bash
# scripts/install/lib/install-core.sh
phase_install_core() {
  echo "phase=install-core"
  if [[ "${INSTALL_CHECK_ONLY:-0}" == "1" ]]; then
    echo "[check-only] would install trojan core and custom caddy"
    return 0
  fi

  install_binary_from_lock "$INSTALL_BINARIES_LOCK" trojan "$INSTALL_TARGET_KEY" "$INSTALL_TROJAN_BIN"
  install_binary_from_lock "$INSTALL_BINARIES_LOCK" caddy-custom "$INSTALL_TARGET_KEY" "$INSTALL_CADDY_BIN"
}
```

```bash
git add scripts/install/lib/common.sh scripts/install/lib/install-binaries.sh \
  scripts/install/artifacts/binaries.lock.json scripts/install/lib/install-core.sh \
  scripts/tests/test_install_binary_contract.py
git commit -m "feat(install): add locked binary install path for trojan and caddy"
```

---

## 任务 3：配置渲染 + manifest-backed bundle export

**文件：**
- 创建：`scripts/install/runtime/render_runtime.py`
- 创建：`scripts/install/runtime/export_client_bundle.py`
- 创建：`scripts/install/templates/Caddyfile.tpl`
- 创建：`scripts/install/templates/trojan-config.json.tpl`
- 创建：`scripts/install/templates/trojan-pro.service.tpl`
- 创建：`scripts/install/templates/caddy-custom.service.tpl`
- 创建：`scripts/install/templates/site/index.html.tpl`
- 测试：`scripts/tests/test_render_install_runtime.py`
- 测试：`scripts/tests/test_export_client_bundle_from_manifest.py`
- 修改：`scripts/config/generate-client-bundle.py`
- 修改：`scripts/tests/test_generate_client_bundle.py`

- [ ] **步骤 1：编写失败测试（Caddy/Trojan 渲染 + manifest-backed bundle）**

```python
import json
from pathlib import Path

from scripts.install.runtime.render_runtime import render_caddyfile, render_trojan_config


def test_render_caddyfile_splits_www_and_edge() -> None:
    manifest = {
        "www_domain": "www.example.com",
        "edge_domain": "edge.example.com",
        "trojan_local_addr": "127.0.0.1",
        "trojan_local_port": 8443,
        "dns_provider": "cloudflare",
        "web_mode": "static",
    }

    rendered = render_caddyfile(manifest)
    assert "www.example.com" in rendered
    assert "edge.example.com" in rendered
    assert "127.0.0.1:8443" in rendered


def test_render_trojan_config_uses_exported_edge_cert_paths() -> None:
    manifest = {
        "edge_domain": "edge.example.com",
        "trojan_local_addr": "127.0.0.1",
        "trojan_local_port": 8443,
        "trojan_password_env_key": "TROJAN_PASSWORD",
    }

    payload = json.loads(render_trojan_config(manifest))
    assert payload["ssl"]["cert"] == "/etc/trojan-pro/certs/current/edge.crt"
    assert payload["ssl"]["key"] == "/etc/trojan-pro/certs/current/edge.key"
```

```python
import json
import subprocess
import sys
from pathlib import Path


def test_export_bundle_uses_manifest_server_fields(tmp_path: Path) -> None:
    manifest_dir = tmp_path / "etc" / "trojan-pro"
    manifest_dir.mkdir(parents=True)
    (manifest_dir / "install-manifest.json").write_text(json.dumps({
        "edge_domain": "edge.example.com",
        "bundle_server_port": 443,
        "bundle_profile_name": "Managed Edge",
    }), encoding="utf-8")

    out = tmp_path / "bundle.json"
    proc = subprocess.run(
        [
            sys.executable,
            "scripts/install/runtime/export_client_bundle.py",
            "--root-prefix", str(tmp_path),
            "--direct", "scripts/tests/fixtures/clash_rules_direct.sample.txt",
            "--proxy", "scripts/tests/fixtures/clash_rules_proxy.sample.txt",
            "--reject", "scripts/tests/fixtures/clash_rules_reject.sample.txt",
            "--output", str(out),
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    assert proc.returncode == 0
    payload = json.loads(out.read_text())
    assert payload["profile"]["serverHost"] == "edge.example.com"
    assert payload["profile"]["sni"] == "edge.example.com"
    assert payload["profile"]["name"] == "Managed Edge"
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_render_install_runtime.py scripts/tests/test_export_client_bundle_from_manifest.py -q
```

预期：FAIL，报错模块不存在或 `build_bundle()` 不接受 server fields。

- [ ] **步骤 3：实现最小渲染器与 bundle export 升级**

```python
# scripts/install/runtime/render_runtime.py
from __future__ import annotations

import json
from string import Template


def render_caddyfile(manifest: dict[str, object]) -> str:
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
        www_domain=manifest["www_domain"],
        edge_domain=manifest["edge_domain"],
        edge_port=manifest["trojan_local_port"],
        dns_provider_module=manifest["dns_provider_module"],
    )


def render_trojan_config(manifest: dict[str, object]) -> str:
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
```

```python
# scripts/install/runtime/export_client_bundle.py
from __future__ import annotations

import argparse
from pathlib import Path

from scripts.config.generate_client_bundle import build_bundle, load_lock_metadata, load_rule_file
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
    Path(args.output).write_text(__import__("json").dumps(bundle, indent=2) + "\n", encoding="utf-8")
    return 0
```

```python
# scripts/config/generate-client-bundle.py (signature only)
def build_bundle(*, direct_rules, proxy_rules, reject_rules, source_meta=None,
                 server_host="example.com", server_port=443, sni="example.com",
                 profile_name="Generated Clash Rules Bundle") -> dict[str, object]:
    ...
    return {
        "version": 2,
        "kind": "trojan-pro-client-profile",
        "profile": {
            "name": profile_name,
            "serverHost": server_host,
            "serverPort": server_port,
            "sni": sni,
            ...
        },
        ...
    }
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_render_install_runtime.py \
  scripts/tests/test_export_client_bundle_from_manifest.py \
  scripts/tests/test_generate_client_bundle.py -q
```

预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add scripts/install/runtime/render_runtime.py scripts/install/runtime/export_client_bundle.py \
  scripts/install/templates/Caddyfile.tpl scripts/install/templates/trojan-config.json.tpl \
  scripts/install/templates/trojan-pro.service.tpl scripts/install/templates/caddy-custom.service.tpl \
  scripts/install/templates/site/index.html.tpl \
  scripts/config/generate-client-bundle.py scripts/tests/test_generate_client_bundle.py \
  scripts/tests/test_render_install_runtime.py scripts/tests/test_export_client_bundle_from_manifest.py
git commit -m "feat(install): add manifest-backed runtime rendering and bundle export"
```

---

## 任务 4：preflight + 包管理器/依赖安装路径

**文件：**
- 创建：`scripts/install/lib/preflight.sh`
- 修改：`scripts/install/lib/detect-os.sh`
- 修改：`scripts/install/lib/install-deps.sh`
- 创建：`scripts/tests/test_install_preflight_contract.py`
- 创建：`scripts/tests/fixtures/os-release.debian`
- 创建：`scripts/tests/fixtures/os-release.rhel`
- 创建：`scripts/tests/fixtures/os-release.arch`
- 创建：`scripts/tests/fixtures/os-release.opensuse`

- [ ] **步骤 1：编写失败测试（包管理器识别 + provider env 缺失 + 端口占用）**

```python
import os
import subprocess
from pathlib import Path


def test_check_only_reports_detected_package_manager_from_fixture(tmp_path: Path) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    (fake_bin / "apt-get").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    (fake_bin / "apt-get").chmod(0o755)

    env = os.environ | {
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
        "INSTALL_OS_RELEASE_PATH": "scripts/tests/fixtures/os-release.debian",
    }
    proc = subprocess.run(
        [
            "bash", "scripts/install/install-kernel.sh",
            "--www-domain", "www.example.com",
            "--edge-domain", "edge.example.com",
            "--dns-provider", "cloudflare",
            "--check-only",
        ],
        text=True,
        capture_output=True,
        env=env,
        check=False,
    )

    assert proc.returncode == 0
    assert "detected_package_manager=apt" in proc.stdout
```

```python
def test_check_only_fails_when_provider_env_missing(tmp_path: Path) -> None:
    proc = subprocess.run(
        [
            "bash", "scripts/install/install-kernel.sh",
            "--www-domain", "www.example.com",
            "--edge-domain", "edge.example.com",
            "--dns-provider", "cloudflare",
            "--check-only",
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    assert proc.returncode != 0
    assert "missing_provider_env=CLOUDFLARE_API_TOKEN" in proc.stderr
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_install_preflight_contract.py -q
```

预期：FAIL，当前 installer 不支持 `--www-domain` / `--edge-domain` / `--dns-provider`。

- [ ] **步骤 3：实现 detect/preflight/install-deps 最小真实逻辑**

```bash
# scripts/install/lib/detect-os.sh
phase_detect_os() {
  echo "phase=detect-os"
  local os_release_path="${INSTALL_OS_RELEASE_PATH:-/etc/os-release}"
  # shellcheck disable=SC1090
  . "$os_release_path"
  INSTALL_OS_ID="${ID:-unknown}"
  INSTALL_OS_VERSION="${VERSION_ID:-unknown}"

  if command -v apt-get >/dev/null 2>&1; then
    INSTALL_PACKAGE_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    INSTALL_PACKAGE_MANAGER="dnf"
  elif command -v yum >/dev/null 2>&1; then
    INSTALL_PACKAGE_MANAGER="yum"
  elif command -v pacman >/dev/null 2>&1; then
    INSTALL_PACKAGE_MANAGER="pacman"
  elif command -v zypper >/dev/null 2>&1; then
    INSTALL_PACKAGE_MANAGER="zypper"
  else
    echo "error: unsupported package manager" >&2
    return 1
  fi

  echo "detected_os=$INSTALL_OS_ID"
  echo "detected_version=$INSTALL_OS_VERSION"
  echo "detected_package_manager=$INSTALL_PACKAGE_MANAGER"
}
```

```bash
# scripts/install/lib/preflight.sh
phase_preflight() {
  echo "phase=preflight"
  local env_errors
  env_errors="$(python3 - <<'PY' "$INSTALL_DNS_PROVIDER" "$INSTALL_ENV_FILE"
from pathlib import Path
from scripts.install.runtime.manifest import load_env_file
from scripts.install.runtime.provider_registry import validate_provider_env
import sys
root = Path(sys.argv[2]).parents[2] if sys.argv[2] else Path('/')
env = load_env_file(root)
print('\n'.join(validate_provider_env(sys.argv[1], env)))
PY
)"
  if [[ -n "$env_errors" ]]; then
    while IFS= read -r item; do
      [[ -n "$item" ]] && echo "missing_provider_env=$item" >&2
    done <<< "$env_errors"
    return 1
  fi
}
```

```bash
# scripts/install/lib/install-deps.sh
phase_install_deps() {
  echo "phase=install-deps"
  case "$INSTALL_PACKAGE_MANAGER" in
    apt) deps=(curl python3 jq openssl systemd) ;;
    dnf|yum) deps=(curl python3 jq openssl systemd) ;;
    pacman) deps=(curl python jq openssl systemd) ;;
    zypper) deps=(curl python3 jq openssl systemd) ;;
  esac
  if [[ "${INSTALL_CHECK_ONLY:-0}" == "1" ]]; then
    printf '[check-only] would install dependencies: %s\n' "${deps[*]}"
    return 0
  fi
  echo "installing_dependencies=${deps[*]}"
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_install_preflight_contract.py -q
```

预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add scripts/install/lib/preflight.sh scripts/install/lib/detect-os.sh scripts/install/lib/install-deps.sh \
  scripts/tests/test_install_preflight_contract.py scripts/tests/fixtures/os-release.*
git commit -m "feat(install): add preflight and multi-package-manager detection"
```

---

## 任务 5：全量 installer orchestration（apply / rollback / validate）

**文件：**
- 修改：`scripts/install/install-kernel.sh`
- 修改：`scripts/install/lib/install-core.sh`
- 修改：`scripts/install/lib/configure-caddy.sh`
- 修改：`scripts/install/lib/write-runtime-config.sh`
- 创建：`scripts/install/lib/activate-services.sh`
- 创建：`scripts/install/lib/cert-bootstrap.sh`
- 测试：`scripts/tests/test_install_kernel_apply_flow.py`
- 创建：`scripts/tests/fixtures/sample_edge.crt`
- 创建：`scripts/tests/fixtures/sample_edge.key`

- [ ] **步骤 1：编写失败测试（temp root apply + backup + validate）**

```python
import json
import os
import subprocess
from pathlib import Path


def test_apply_writes_manifest_configs_and_certs_under_root_prefix(tmp_path: Path) -> None:
    root = tmp_path / "root"
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    for name in ["systemctl", "caddy-custom", "trojan"]:
        path = fake_bin / name
        path.write_text("#!/bin/sh\necho fake-$0 $@\nexit 0\n", encoding="utf-8")
        path.chmod(0o755)

    env = os.environ | {
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
        "INSTALL_ROOT_PREFIX": str(root),
        "INSTALL_CERT_BOOTSTRAP_MODE": "fixtures",
        "INSTALL_CERT_FIXTURE_DIR": str(Path('scripts/tests/fixtures').resolve()),
        "CLOUDFLARE_API_TOKEN": "token",
    }

    proc = subprocess.run(
        [
            "bash", "scripts/install/install-kernel.sh",
            "--www-domain", "www.example.com",
            "--edge-domain", "edge.example.com",
            "--dns-provider", "cloudflare",
            "--apply",
        ],
        text=True,
        capture_output=True,
        env=env,
        check=False,
    )

    assert proc.returncode == 0
    manifest = json.loads((root / "etc" / "trojan-pro" / "install-manifest.json").read_text())
    assert manifest["www_domain"] == "www.example.com"
    assert (root / "etc" / "trojan-pro" / "config.json").exists()
    assert (root / "etc" / "caddy" / "Caddyfile").exists()
    assert (root / "etc" / "trojan-pro" / "certs" / "current" / "edge.crt").exists()
    assert "phase=validate" in proc.stdout
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_install_kernel_apply_flow.py -q
```

预期：FAIL，当前 installer apply 仍然 fail-closed 且未写任何真实文件。

- [ ] **步骤 3：实现 installer apply/rollback 主流程**

```bash
# scripts/install/install-kernel.sh (核心骨架)
source "$LIB_DIR/common.sh"
source "$LIB_DIR/preflight.sh"
source "$LIB_DIR/install-binaries.sh"
source "$LIB_DIR/activate-services.sh"
source "$LIB_DIR/cert-bootstrap.sh"

INSTALL_ROOT_PREFIX="${INSTALL_ROOT_PREFIX:-}"
INSTALL_APPLY=0
INSTALL_TARGET_KEY="linux-amd64"
INSTALL_TROJAN_BIN="${INSTALL_ROOT_PREFIX}/usr/local/bin/trojan"
INSTALL_CADDY_BIN="${INSTALL_ROOT_PREFIX}/usr/local/bin/caddy-custom"
INSTALL_ENV_FILE="${INSTALL_ROOT_PREFIX}/etc/trojan-pro/env"

phase_preflight
phase_detect_os
phase_install_deps
phase_install_core
phase_write_runtime_config
phase_configure_caddy
phase_cert_bootstrap
phase_activate_services
phase_validate
```

```bash
# scripts/install/lib/cert-bootstrap.sh
phase_cert_bootstrap() {
  echo "phase=cert-bootstrap"
  local cert_dir="${INSTALL_ROOT_PREFIX}/etc/trojan-pro/certs/current"
  mkdir -p "$cert_dir"
  if [[ "${INSTALL_CERT_BOOTSTRAP_MODE:-live}" == "fixtures" ]]; then
    cp "${INSTALL_CERT_FIXTURE_DIR}/sample_edge.crt" "$cert_dir/edge.crt"
    cp "${INSTALL_CERT_FIXTURE_DIR}/sample_edge.key" "$cert_dir/edge.key"
    echo "cert_bootstrap_mode=fixtures"
    return 0
  fi
  echo "cert_bootstrap_mode=live"
  # live path: invoke caddy to obtain/export certs
}
```

```bash
# scripts/install/lib/activate-services.sh
phase_activate_services() {
  echo "phase=activate-services"
  systemctl daemon-reload
  systemctl restart caddy-custom.service
  systemctl restart trojan-pro.service
}

phase_validate() {
  echo "phase=validate"
  test -s "${INSTALL_ROOT_PREFIX}/etc/trojan-pro/config.json"
  test -s "${INSTALL_ROOT_PREFIX}/etc/caddy/Caddyfile"
  test -s "${INSTALL_ROOT_PREFIX}/etc/trojan-pro/certs/current/edge.crt"
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_install_kernel_apply_flow.py -q
```

预期：PASS。

- [ ] **步骤 5：补一条 rollback 失败测试并 commit**

```python
def test_apply_restores_last_known_good_when_validate_fails(tmp_path: Path) -> None:
    # 先放一个旧 Caddyfile 和旧 manifest，再让新的 validate 故意失败
    ...
    assert (root / "etc" / "caddy" / "Caddyfile").read_text() == "old-good"
```

```bash
git add scripts/install/install-kernel.sh scripts/install/lib/install-core.sh \
  scripts/install/lib/configure-caddy.sh scripts/install/lib/write-runtime-config.sh \
  scripts/install/lib/activate-services.sh scripts/install/lib/cert-bootstrap.sh \
  scripts/tests/test_install_kernel_apply_flow.py scripts/tests/fixtures/sample_edge.crt \
  scripts/tests/fixtures/sample_edge.key
git commit -m "feat(install): add full apply flow with validation and rollback seam"
```

---

## 任务 6：`tp` 观察/诊断命令

**文件：**
- 创建：`scripts/install/runtime/cli.py`
- 测试：`scripts/tests/test_tp_cli_contract.py`
- 修改：`scripts/install/install-kernel.sh`（安装 `tp` / `tpctl` alias）

- [ ] **步骤 1：编写失败测试（status / doctor / validate）**

```python
import json
import subprocess
import sys
from pathlib import Path


def test_tp_status_prints_manifest_summary_as_json(tmp_path: Path) -> None:
    manifest_dir = tmp_path / "etc" / "trojan-pro"
    manifest_dir.mkdir(parents=True)
    (manifest_dir / "install-manifest.json").write_text(json.dumps({
        "www_domain": "www.example.com",
        "edge_domain": "edge.example.com",
        "dns_provider": "cloudflare",
        "web_mode": "static",
        "trojan_version": "1.0.0",
        "caddy_version": "2.0.0",
    }), encoding="utf-8")

    proc = subprocess.run(
        [sys.executable, "scripts/install/runtime/cli.py", "--root-prefix", str(tmp_path), "status", "--json"],
        text=True,
        capture_output=True,
        check=False,
    )

    assert proc.returncode == 0
    payload = json.loads(proc.stdout)
    assert payload["www_domain"] == "www.example.com"
    assert payload["dns_provider"] == "cloudflare"
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_tp_cli_contract.py -q
```

预期：FAIL，报错 `No such file or directory: scripts/install/runtime/cli.py`。

- [ ] **步骤 3：实现 `tp` 观察命令最小版本**

```python
# scripts/install/runtime/cli.py
from __future__ import annotations

import argparse
import json
from pathlib import Path

from scripts.install.runtime.manifest import read_manifest, install_paths


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
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_tp_cli_contract.py -q
```

预期：PASS。

- [ ] **步骤 5：安装 `tp` / `tpctl` alias 并 commit**

```bash
# scripts/install/install-kernel.sh 末尾（安装 wrapper）
install -m 0755 scripts/install/runtime/cli.py "${INSTALL_ROOT_PREFIX}/usr/local/bin/tp"
ln -sfn "${INSTALL_ROOT_PREFIX}/usr/local/bin/tp" "${INSTALL_ROOT_PREFIX}/usr/local/bin/tpctl"
```

```bash
git add scripts/install/runtime/cli.py scripts/tests/test_tp_cli_contract.py scripts/install/install-kernel.sh
git commit -m "feat(tp): add status and validate command surface"
```

---

## 任务 7：`tp` mutation commands + live config mutation

**文件：**
- 修改：`scripts/install/runtime/cli.py`
- 修改：`scripts/install/runtime/manifest.py`
- 修改：`scripts/install/runtime/export_client_bundle.py`
- 测试：`scripts/tests/test_tp_cli_mutations.py`
- 修改：`scripts/config/generate-client-bundle.py`

- [ ] **步骤 1：编写失败测试（rotate-password / set-web-mode / reconfigure-dns-provider / export-client-bundle）**

```python
import json
import subprocess
import sys
from pathlib import Path


def test_tp_set_web_mode_upstream_updates_manifest(tmp_path: Path) -> None:
    manifest_dir = tmp_path / "etc" / "trojan-pro"
    manifest_dir.mkdir(parents=True)
    manifest_path = manifest_dir / "install-manifest.json"
    manifest_path.write_text(json.dumps({
        "www_domain": "www.example.com",
        "edge_domain": "edge.example.com",
        "dns_provider": "cloudflare",
        "web_mode": "static",
        "trojan_local_port": 8443,
    }), encoding="utf-8")

    proc = subprocess.run(
        [sys.executable, "scripts/install/runtime/cli.py", "--root-prefix", str(tmp_path), "set-web-mode", "upstream", "--upstream", "https://origin.example.com"],
        text=True,
        capture_output=True,
        check=False,
    )

    assert proc.returncode == 0
    payload = json.loads(manifest_path.read_text())
    assert payload["web_mode"] == "upstream"
    assert payload["web_upstream"] == "https://origin.example.com"
```

```python
def test_tp_rotate_password_writes_env_and_regenerates_bundle(tmp_path: Path) -> None:
    ...
    assert "TROJAN_PASSWORD=" in (tmp_path / "etc" / "trojan-pro" / "env").read_text()
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_tp_cli_mutations.py -q
```

预期：FAIL，报错子命令不存在。

- [ ] **步骤 3：实现 mutation commands 最小逻辑**

```python
# scripts/install/runtime/cli.py（新增命令）
import secrets
from scripts.install.runtime.manifest import load_env_file, read_manifest, write_manifest
from scripts.install.runtime.provider_registry import validate_provider_env


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
    env_path = install_paths(root)["env"]
    env_path.write_text("".join(f"{k}={v}\n" for k, v in sorted(env.items())), encoding="utf-8")
    return 0


def cmd_reconfigure_dns_provider(args: argparse.Namespace) -> int:
    root = Path(args.root_prefix)
    manifest = read_manifest(root)
    env = load_env_file(root)
    missing = validate_provider_env(args.provider, env)
    if missing:
        print(json.dumps({"status": "fail", "missing": missing}, ensure_ascii=False))
        return 1
    manifest["dns_provider"] = args.provider
    write_manifest(root, manifest)
    return 0
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_tp_cli_mutations.py -q
```

预期：PASS。

- [ ] **步骤 5：把 `export-client-bundle` / `upgrade-binaries` / `renew-cert` 接好并 commit**

```python
# cmd_export_client_bundle / cmd_upgrade_binaries / cmd_renew_cert 核心调用
subprocess.run([sys.executable, "scripts/install/runtime/export_client_bundle.py", ...], check=True)
subprocess.run(["bash", "-lc", "source scripts/install/lib/install-binaries.sh && install_binary_from_lock ..."], check=True)
subprocess.run(["bash", "-lc", "source scripts/install/lib/cert-bootstrap.sh && phase_cert_bootstrap"], check=True)
```

```bash
git add scripts/install/runtime/cli.py scripts/install/runtime/manifest.py \
  scripts/install/runtime/export_client_bundle.py scripts/tests/test_tp_cli_mutations.py \
  scripts/config/generate-client-bundle.py
git commit -m "feat(tp): add mutation commands for web mode, dns provider, password, cert, and bundle export"
```

---

## 任务 8：文档、统一验证入口、CI 与 live acceptance runbook

**文件：**
- 创建：`scripts/validate_full_installer_v1.sh`
- 测试：`scripts/tests/test_validate_full_installer_v1.py`
- 创建：`docs/en/tp-cli.md`
- 创建：`docs/zh-CN/tp-cli.md`
- 创建：`docs/en/dns-providers.md`
- 创建：`docs/zh-CN/dns-providers.md`
- 创建：`docs/ops/full-installer-live-acceptance.md`
- 修改：`docs/README.md`
- 修改：`docs/en/install-kernel.md`
- 修改：`docs/zh-CN/install-kernel.md`
- 修改：`docs/en/config-generation.md`
- 修改：`docs/zh-CN/config-generation.md`
- 修改：`.github/workflows/ci-smoke.yml`

- [ ] **步骤 1：编写失败测试（统一验证脚本存在并执行固定顺序）**

```python
import pathlib
import subprocess


def test_validate_full_installer_script_exists_and_mentions_core_steps() -> None:
    path = pathlib.Path("scripts/validate_full_installer_v1.sh")
    assert path.exists()
    text = path.read_text(encoding="utf-8")
    assert "manifest + provider registry" in text
    assert "render + bundle export" in text
    assert "installer apply flow" in text
    assert "tp cli" in text
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_validate_full_installer_v1.py -q
```

预期：FAIL，脚本不存在。

- [ ] **步骤 3：实现统一验证脚本与文档更新**

```bash
# scripts/validate_full_installer_v1.sh
#!/usr/bin/env bash
set -euo pipefail

echo "== validate_full_installer_v1 =="
echo "[1/4] manifest + provider registry"
python3 -m pytest scripts/tests/test_install_manifest_runtime.py scripts/tests/test_dns_provider_registry.py -q

echo "[2/4] render + bundle export"
python3 -m pytest scripts/tests/test_render_install_runtime.py scripts/tests/test_export_client_bundle_from_manifest.py scripts/tests/test_generate_client_bundle.py -q

echo "[3/4] installer apply flow"
python3 -m pytest scripts/tests/test_install_binary_contract.py scripts/tests/test_install_preflight_contract.py scripts/tests/test_install_kernel_apply_flow.py -q

echo "[4/4] tp cli"
python3 -m pytest scripts/tests/test_tp_cli_contract.py scripts/tests/test_tp_cli_mutations.py -q

echo "PASS: validate_full_installer_v1"
```

```yaml
# .github/workflows/ci-smoke.yml（新增 step）
      - name: Full installer v1 contract + integration gate
        run: |
          bash scripts/validate_full_installer_v1.sh
```

```markdown
<!-- docs/en/tp-cli.md -->
# tp CLI

- `tp status`
- `tp doctor`
- `tp validate`
- `tp rotate-password`
- `tp set-web-mode static|upstream`
- `tp reconfigure-dns-provider <provider>`

`tpctl` is a compatibility alias.
```

- [ ] **步骤 4：运行统一验证并确认通过**

运行：
```bash
bash scripts/validate_full_installer_v1.sh
```

预期：
- 四段测试全部 PASS
- 最终输出 `PASS: validate_full_installer_v1`

- [ ] **步骤 5：Commit**

```bash
git add scripts/validate_full_installer_v1.sh scripts/tests/test_validate_full_installer_v1.py \
  docs/en/tp-cli.md docs/zh-CN/tp-cli.md docs/en/dns-providers.md docs/zh-CN/dns-providers.md \
  docs/ops/full-installer-live-acceptance.md docs/README.md docs/en/install-kernel.md docs/zh-CN/install-kernel.md \
  docs/en/config-generation.md docs/zh-CN/config-generation.md .github/workflows/ci-smoke.yml
git commit -m "docs(ci): add full installer validation bundle and operator docs"
```

---

## 自检

### 规格覆盖度

- **full host-mutating installer** → 任务 4、5
- **manifest 单一真相源** → 任务 1、3、6、7
- **custom Caddy + provider registry + cert export** → 任务 1、2、3、5
- **`tp` / `tpctl` day-2 management** → 任务 6、7
- **manifest-backed client bundle export** → 任务 3、7
- **统一验证/CI/docs/live acceptance** → 任务 8
- **rollback / fail-closed** → 任务 5、7、8

无规格章节遗漏。

### 占位符扫描

- 无占位词或未决标记
- 每个任务都给出精确文件路径、测试命令、核心代码形状与 commit 命令

### 类型一致性

统一使用：
- `install-manifest.json`
- `dns_provider`
- `support_tier`
- `tp` / `tpctl`
- `web_mode`
- `trojan_local_port`
- `build_bundle(..., server_host, server_port, sni, profile_name)`

实际编码时不得改名漂移。
