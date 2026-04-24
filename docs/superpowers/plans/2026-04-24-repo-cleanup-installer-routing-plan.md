# Repo Cleanup + Installer + Routing Bundle 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 完成仓库分支清理（仅保留 main）、交付通用 Linux 一键安装内核脚本（Caddy ACME 自动签发）、生成可导入客户端的静态分流配置，并补齐中英双文档。

**架构：** 采用“脚本分层 + 文档双语 + 规则离线快照”方案：仓库清理使用独立脚本并默认 dry-run；安装脚本以主入口 + lib 子模块组织，自动检测包管理器并写入 systemd/Caddy 配置；规则整合由 Python 生成器拉取 Loyalsoldier 规则并映射为客户端静态 RoutingProfile bundle。最终通过脚本自测与客户端导入契约测试闭环。

**技术栈：** Bash（repo/install 脚本）、Python 3（规则转换与生成）、Git/GitHub CLI、Caddy ACME、Markdown（中英文档）

---

## 文件结构（先锁定职责）

### 创建文件
- `scripts/repo/cleanup-branches.sh`
  - 职责：列举本地/远端分支，默认 dry-run，`--apply` 执行删除。
- `scripts/install/install-kernel.sh`
  - 职责：安装入口，串联检测、依赖安装、core 部署、Caddy 配置、服务启动与健康检查。
- `scripts/install/lib/detect-os.sh`
  - 职责：检测发行版与包管理器。
- `scripts/install/lib/install-deps.sh`
  - 职责：按包管理器安装依赖（curl/jq/caddy/systemd 相关）。
- `scripts/install/lib/install-core.sh`
  - 职责：下载并安装 trojan core，可幂等升级。
- `scripts/install/lib/configure-caddy.sh`
  - 职责：写 Caddyfile（ACME 自动签发/续期）并校验。
- `scripts/install/lib/write-runtime-config.sh`
  - 职责：写 trojan runtime config（由安装参数渲染）。
- `scripts/config/generate-client-bundle.py`
  - 职责：抓取 clash-rules、映射 RoutingRule、输出可导入 profile JSON。
- `scripts/config/sources/clash-rules.lock`
  - 职责：记录规则源版本（commit/date/url）。
- `scripts/tests/test_generate_client_bundle.py`
  - 职责：验证规则映射、输出 schema、优先级顺序。
- `scripts/tests/fixtures/clash_rules_direct.sample.txt`
- `scripts/tests/fixtures/clash_rules_proxy.sample.txt`
- `scripts/tests/fixtures/clash_rules_reject.sample.txt`
  - 职责：离线测试样本，避免测试依赖网络。
- `docs/ops/branch-cleanup.md`
  - 职责：分支清理使用与风险说明（中英双文同页分节）。
- `docs/zh-CN/quickstart.md`
- `docs/en/quickstart.md`
  - 职责：中英快速上手入口。
- `docs/zh-CN/install-kernel.md`
- `docs/en/install-kernel.md`
  - 职责：安装脚本、证书、服务检查。
- `docs/zh-CN/config-generation.md`
- `docs/en/config-generation.md`
  - 职责：规则生成、导入客户端、更新流程。

### 修改文件
- `.gitignore`
  - 职责：忽略 `dist/client-import/` 构建产物（保留必要 fixture）。
- `docs/README.md`
  - 职责：增加中英文档入口与脚本索引。
- `scripts/tests/test_client_packaged_smoke.py`（如需）
  - 职责：补充 bundle 产物存在性/结构断言（仅在当前测试风格允许时）。

### 产物目录（运行时生成，不纳入版本库）
- `dist/client-import/`
  - 输出：`trojan-pro-client-profile-<YYYYMMDD>.json`

---

## 任务 1：仓库清理脚本（仅保留 main）

**文件：**
- 创建：`scripts/repo/cleanup-branches.sh`
- 测试：通过 dry-run + apply（受控）验证
- 文档：`docs/ops/branch-cleanup.md`

- [ ] **步骤 1：编写失败测试（脚本契约测试）**

在 `scripts/tests/test_cleanup_branches_contract.py` 新建契约测试，最小断言脚本参数行为与输出关键字。

```python
import pathlib
import subprocess

SCRIPT = pathlib.Path("scripts/repo/cleanup-branches.sh")

def test_cleanup_script_exists_and_help():
    assert SCRIPT.exists()
    proc = subprocess.run(["bash", str(SCRIPT), "--help"], capture_output=True, text=True)
    assert proc.returncode == 0
    assert "--dry-run" in proc.stdout
    assert "--apply" in proc.stdout
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
cd /root/.openclaw/workspace/trojan-obfuscation/.worktrees/repo-cleanup-installer-routing
python3 -m pytest scripts/tests/test_cleanup_branches_contract.py -q
```
预期：FAIL，报错脚本不存在。

- [ ] **步骤 3：实现最小 cleanup 脚本（默认 dry-run）**

```bash
#!/usr/bin/env bash
set -euo pipefail
# parse args: --dry-run(default) --apply --help
# list local branches except main
# list remote branches except origin/main origin/HEAD
# print delete candidates
# if apply: delete local and remote candidates
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_cleanup_branches_contract.py -q
```
预期：PASS。

- [ ] **步骤 5：手工验证 dry-run/apply 防护**

运行：
```bash
bash scripts/repo/cleanup-branches.sh --dry-run
```
预期：输出候删清单且不执行删除。

- [ ] **步骤 6：Commit**

```bash
git add scripts/repo/cleanup-branches.sh scripts/tests/test_cleanup_branches_contract.py
git commit -m "feat(repo): add safe branch cleanup script with dry-run contract test"
```

---

## 任务 2：通用 Linux 安装脚本分层骨架（Caddy ACME）

**文件：**
- 创建：`scripts/install/install-kernel.sh`
- 创建：`scripts/install/lib/*.sh`
- 测试：脚本 lint + `--check-only` 路径验证

- [ ] **步骤 1：编写失败测试（入口参数与 lib 依赖）**

在 `scripts/tests/test_install_kernel_contract.py` 增加：

```python
import pathlib
import subprocess

SCRIPT = pathlib.Path("scripts/install/install-kernel.sh")

def test_install_script_help_contract():
    assert SCRIPT.exists()
    proc = subprocess.run(["bash", str(SCRIPT), "--help"], capture_output=True, text=True)
    assert proc.returncode == 0
    assert "--domain" in proc.stdout
    assert "--email" in proc.stdout
    assert "--check-only" in proc.stdout
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_install_kernel_contract.py -q
```
预期：FAIL，脚本不存在。

- [ ] **步骤 3：实现 install 主入口 + lib 骨架**

关键代码骨架：

```bash
# scripts/install/install-kernel.sh
source "$(dirname "$0")/lib/detect-os.sh"
source "$(dirname "$0")/lib/install-deps.sh"
source "$(dirname "$0")/lib/install-core.sh"
source "$(dirname "$0")/lib/configure-caddy.sh"
source "$(dirname "$0")/lib/write-runtime-config.sh"

# parse --domain --email --password --check-only
# check_only => detect + dependency check, no mutation
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_install_kernel_contract.py -q
```
预期：PASS。

- [ ] **步骤 5：执行 check-only 自测**

运行：
```bash
bash scripts/install/install-kernel.sh --domain example.com --email ops@example.com --check-only
```
预期：仅输出检测结果，不写入系统配置。

- [ ] **步骤 6：Commit**

```bash
git add scripts/install/install-kernel.sh scripts/install/lib/*.sh scripts/tests/test_install_kernel_contract.py
git commit -m "feat(install): add generic linux installer scaffold with caddy acme path"
```

---

## 任务 3：规则转换器（clash-rules → client bundle）

**文件：**
- 创建：`scripts/config/generate-client-bundle.py`
- 创建：`scripts/tests/test_generate_client_bundle.py`
- 创建：`scripts/tests/fixtures/clash_rules_*.sample.txt`
- 创建：`scripts/config/sources/clash-rules.lock`

- [ ] **步骤 1：编写失败测试（映射与输出 schema）**

```python
from scripts.config.generate_client_bundle import parse_rules, build_bundle

def test_mapping_priority_and_actions():
    direct = ["DOMAIN-SUFFIX,cn"]
    proxy = ["DOMAIN-SUFFIX,google.com"]
    reject = ["DOMAIN-SUFFIX,ads.com"]
    bundle = build_bundle(direct, proxy, reject, source_meta={"commit":"abc"})
    rules = bundle["profile"]["routing"]["rules"]
    names = [r["name"] for r in rules]
    assert names[0].startswith("reject")
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_generate_client_bundle.py -q
```
预期：FAIL，模块不存在或函数未定义。

- [ ] **步骤 3：实现最小转换器**

实现要点：
- 输入：三类规则文本（direct/proxy/reject）
- 解析：`DOMAIN` / `DOMAIN-SUFFIX` / `DOMAIN-KEYWORD` / `IP-CIDR`
- 输出：`kind=trojan-pro-client-profile`，`version=2`，含 `routing.policyGroups` 与 `routing.rules`
- 优先级：reject > direct > proxy
- 额外输出 lock 元数据（commit/date/source url）

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_generate_client_bundle.py -q
```
预期：PASS。

- [ ] **步骤 5：运行生成命令（fixture 模式）**

运行：
```bash
python3 scripts/config/generate-client-bundle.py \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/trojan-pro-client-profile-sample.json
```
预期：生成 JSON，能被 `json.loads` 解析。

- [ ] **步骤 6：Commit**

```bash
git add scripts/config/generate-client-bundle.py scripts/config/sources/clash-rules.lock scripts/tests/test_generate_client_bundle.py scripts/tests/fixtures/clash_rules_*.sample.txt
git commit -m "feat(config): add clash-rules to client routing bundle generator"
```

---

## 任务 4：中英双文档与索引

**文件：**
- 创建：`docs/zh-CN/*.md`
- 创建：`docs/en/*.md`
- 修改：`docs/README.md`
- 创建：`docs/ops/branch-cleanup.md`

- [ ] **步骤 1：编写失败测试（文档链接完整性）**

在 `scripts/tests/test_docs_bilingual_index.py` 新建最小测试：

```python
import pathlib

DOCS = pathlib.Path("docs")

def test_bilingual_entrypoints_exist():
    assert (DOCS / "zh-CN" / "quickstart.md").exists()
    assert (DOCS / "en" / "quickstart.md").exists()
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_docs_bilingual_index.py -q
```
预期：FAIL，文件不存在。

- [ ] **步骤 3：编写中英文档与 README 索引**

文档必须包含：
- 安装命令
- ACME 注意事项（DNS/80/443）
- 配置生成命令
- 客户端导入步骤
- 规则更新机制（定时重新生成并导入）

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
python3 -m pytest scripts/tests/test_docs_bilingual_index.py -q
```
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add docs/README.md docs/zh-CN/*.md docs/en/*.md docs/ops/branch-cleanup.md scripts/tests/test_docs_bilingual_index.py
git commit -m "docs: add bilingual setup and config generation guides"
```

---

## 任务 5：整体验证与交付

**文件：**
- 修改：`scripts/validate_iter3_truthful_daily_use.sh`（如需挂接新检查）
- 创建：`scripts/validate_repo_cleanup_installer_routing.sh`

- [ ] **步骤 1：编写失败测试（验证脚本存在）**

```python
import pathlib

def test_validation_script_exists():
    assert pathlib.Path("scripts/validate_repo_cleanup_installer_routing.sh").exists()
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
python3 -m pytest scripts/tests/test_validate_repo_cleanup_installer_routing.py -q
```
预期：FAIL。

- [ ] **步骤 3：实现验证脚本**

验证脚本顺序：
1. cleanup dry-run
2. installer `--check-only`
3. bundle generator fixture run
4. docs bilingual index test

- [ ] **步骤 4：运行整体验证**

运行：
```bash
bash scripts/validate_repo_cleanup_installer_routing.sh
```
预期：所有子步骤 PASS，并打印 started/finished 时间戳。

- [ ] **步骤 5：最终 Commit**

```bash
git add scripts/validate_repo_cleanup_installer_routing.sh scripts/tests/test_validate_repo_cleanup_installer_routing.py
git commit -m "chore(validate): add end-to-end validation bundle for cleanup+install+routing"
```

---

## 自检（计划质量检查）

### 1. 规格覆盖度
- 分支清理：任务 1 覆盖
- 通用 Linux 安装 + Caddy ACME：任务 2 覆盖
- clash-rules 静态快照 + 客户端导入：任务 3 覆盖
- 中英双文 + 索引：任务 4 覆盖
- 可执行验证闭环：任务 5 覆盖

### 2. 占位符扫描
- 无 `TODO/待定/后续实现` 占位词。
- 每个任务都有具体文件与命令。

### 3. 类型一致性
- 统一目标 bundle 类型：`trojan-pro-client-profile`，`version=2`。
- 规则优先级统一：`reject > direct > proxy`。
- 清理策略统一：仅保留 `main`。
