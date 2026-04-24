# Design Spec: Repo Cleanup + Bilingual Docs + One-Click Kernel Install + Rule-Based Client Bundle

- Date: 2026-04-24
- Owner: assistant + user
- Scope: trojan-obfuscation repo

## 1) Confirmed decisions

User-confirmed decisions in brainstorming:

1. Branch cleanup policy: **A** (keep only `main`)
2. Install target: **3** (generic Linux with package-manager auto-detection)
3. Rule integration path: **1** (static snapshot conversion for client import)
4. Certificate path: **1** (Caddy built-in ACME auto issue/renew)

## 2) Scope split (subprojects)

### A. Repo hygiene
- Keep only `main` locally/remotely.
- Delete old local + remote branches after dry-run preview.

### B. Bilingual documentation
- Introduce bilingual docs structure and entry points.
- Ensure Chinese and English docs are aligned for installation, cert issuance, config generation, and client import.

### C. One-click kernel install script
- Generic Linux script with package manager detection (`apt` / `dnf` / `yum` / `pacman` / `zypper`).
- Install trojan core + Caddy + service units.
- Use Caddy ACME for certificate auto issue/renew.

### D. Rule-based client import bundle
- Pull Clash rules from Loyalsoldier source.
- Convert to static routing snapshot compatible with current client routing model.
- Generate importable client profile JSON bundle.

## 3) Architecture and data flow

### 3.1 Branch cleanup flow

`cleanup-branches.sh --dry-run`
→ enumerate local/remote branches
→ compute delete candidates = all except `main` and `origin/main`
→ print deterministic summary

`cleanup-branches.sh --apply`
→ delete local candidates
→ delete remote candidates (`git push origin --delete <branch>`)
→ verify only main remains

### 3.2 Install flow

`install-kernel.sh`
→ detect distro/package manager
→ install dependencies
→ install/upgrade trojan core
→ install/configure Caddy
→ write runtime configs
→ `systemctl daemon-reload && systemctl enable --now ...`
→ health checks (`systemctl is-active`, Caddy endpoint/check)

### 3.3 Rule conversion flow

`generate-client-bundle.py --refresh-rules`
→ fetch latest Loyalsoldier rules (`direct`, `proxy`, `reject`)
→ normalize and parse rule lines
→ map to routing policy groups + routing rules
→ serialize profile bundle (`kind=trojan-pro-client-profile`, `version=2`)
→ emit artifact under `dist/client-import/`
→ write lock metadata (`source commit/date`) for traceability

## 4) Mapping model: clash-rules → client routing model

Current client routing model (`RoutingRuleMatch`) supports static fields:
- `domainExact`
- `domainSuffix`
- `domainKeyword`
- `domainRegex`
- `ipCidr`
- plus process/protocol/port constraints

No native remote rule-provider URL in routing model.

### Mapping policy

- `reject` list → high-priority rules, action = `block`
- `direct` list → mid-priority rules, action = policy group `direct-group`
- `proxy` list → lower-priority rules, action = policy group `proxy-group`
- fallback/default action = `proxy`

Priority order is deterministic: `reject` > `direct` > `proxy`.

### Update model

Because routing is static, update by regeneration:
- periodic CI/cron regeneration of importable bundle
- users re-import latest bundle in client

## 5) Error handling

### Branch cleanup
- `--apply` requires explicit flag; default is dry-run.
- If any branch deletion fails, print failed set and exit non-zero.

### Installer
- fail-fast on unsupported OS/package manager.
- fail-fast on missing required commands after install.
- fail-fast when Caddy ACME issuance fails (DNS/port conflicts).

### Rule conversion
- fail on fetch errors, invalid source format, empty effective rule set.
- validate output schema before writing final artifact.

## 6) File plan

### Scripts
- `scripts/repo/cleanup-branches.sh`
- `scripts/install/install-kernel.sh`
- `scripts/install/lib/detect-os.sh`
- `scripts/install/lib/install-deps.sh`
- `scripts/install/lib/install-core.sh`
- `scripts/install/lib/configure-caddy.sh`
- `scripts/install/lib/write-runtime-config.sh`
- `scripts/config/generate-client-bundle.py`
- `scripts/config/sources/clash-rules.lock` (generated metadata)

### Artifacts
- `dist/client-import/trojan-pro-client-profile-<date>.json`

### Docs (bilingual)
- `docs/zh-CN/quickstart.md`
- `docs/en/quickstart.md`
- `docs/zh-CN/install-kernel.md`
- `docs/en/install-kernel.md`
- `docs/zh-CN/config-generation.md`
- `docs/en/config-generation.md`
- `docs/README.md` entry updates
- `docs/ops/branch-cleanup.md`

## 7) Verification plan

1. Branch cleanup dry-run output review
2. Apply cleanup and verify local/remote branches
3. Installer smoke test on one generic Linux target (fresh host/container)
4. Caddy ACME check and renewal readiness check
5. Bundle generation test + schema validation
6. Client import manual verification
7. Bilingual doc link and consistency check

## 8) Scope boundaries / YAGNI

Included now:
- static snapshot conversion path (no client subscription feature)
- one install path with Caddy ACME

Explicitly excluded now:
- adding remote rule-provider subscription into client runtime
- non-Linux platform installers
- advanced multi-node deployment orchestration

## 9) Open risks

1. Rule source format drift upstream (mitigate with parser validation + lock metadata)
2. ACME issuance environment constraints (ports, DNS, firewall)
3. Large rule volume affecting client import size/perf (mitigate by curated subset + deterministic ordering)

## 10) Success criteria

- Branch state after cleanup: only `main`/`origin/main` remain.
- One-command installer completes on supported Linux and starts services.
- Generated bundle imports in client and routing rules are visible/effective.
- Chinese/English docs are complete, consistent, and executable by copy/paste.
