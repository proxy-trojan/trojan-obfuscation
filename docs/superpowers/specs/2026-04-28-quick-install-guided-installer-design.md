# Guided Quick Install (Linux) — Design Spec

> **Scope note**
>
> This spec defines a guided **Quick Install** experience for a **self-hosted TLS service installer** on Linux.
>
> - Positioning and wording must remain **neutral / legitimate** (ACME, DNS-01, systemd operations, supply-chain safety).
> - Do **not** describe or emphasize any censorship/geo-restriction bypass use cases.
>
> This spec focuses on a *one-liner* bootstrap (`curl | sudo bash`) that downloads a day-2 CLI (`tp`) from GitHub Releases (**latest + sha256**) and then runs an interactive guided install (`tp install`).

## Goals

1. **One-liner entrypoint**: A user can start the installer with a single command:

   ```bash
   curl -fsSL https://github.com/<owner>/<repo>/releases/latest/download/tp-install.sh | sudo bash
   ```

2. **Guided, interactive install**: The installer should prompt for the minimal required configuration:
   - `www domain` — the public web surface domain served by Caddy
   - `edge domain` — the TLS entrypoint domain used for certificate issuance/export
   - `dns provider` — DNS provider for ACME **DNS-01**

3. **Default apply with explicit confirmation**:
   - The guided flow defaults to **apply** (host-mutating installation).
   - Before applying, it must print an explicit **plan** (what files will be written/modified, what services will be restarted) and require the operator to type **`YES`**.

4. **Supply-chain integrity**:
   - The bootstrap must download `tp` from GitHub Releases **latest** and verify its **sha256** using sidecar checksum assets.

5. **Fail-closed behavior**:
   - Missing required DNS provider credentials must stop the flow **before** host mutation.
   - Invalid/missing inputs must result in a non-zero exit.

6. **Bilingual documentation (EN + zh-CN)**:
   - Provide two guides with aligned structure and content:
     - `docs/en/quick-install.md`
     - `docs/zh-CN/quick-install.md`

## Non-goals

- Supporting non-Linux platforms in this quick-install flow.
- Implementing “no-check / skip verification” installation modes.
- Writing or logging sensitive credentials to stdout/stderr.
- Replacing the existing installer kernel; this flow must **reuse** `scripts/install/install-kernel.sh`.

## Current components to reuse

- Installer kernel entrypoint:
  - `scripts/install/install-kernel.sh`
    - modes: `--check-only` and `--apply`
    - required flags: `--www-domain`, `--edge-domain`, `--dns-provider`
- DNS provider registry:
  - `scripts/install/providers/dns-providers.json`
  - Runtime helpers:
    - `scripts/install/runtime/provider_registry.py`
    - `scripts/install/runtime/manifest.py`
- Day-2 CLI surface:
  - `scripts/install/runtime/cli.py` currently provides `tp` / `tpctl` operations.

## UX flow

### Entry command

```bash
curl -fsSL https://github.com/<owner>/<repo>/releases/latest/download/tp-install.sh | sudo bash
```

### Step 1 — Language selection

The guided flow prompts first:

- `1) 中文`  
- `2) English`

After selection, the remaining interaction proceeds in the chosen language only.

### Step 2 — Environment detection & safety preamble

The flow prints (single-language):

- detected architecture: `linux-amd64` or `linux-arm64`
- install destination for `tp`: `/usr/local/bin/tp`
- a short warning that root privileges are required and files under `/etc` may be created/modified

### Step 3 — Collect required inputs

Prompt the operator for:

- `www domain` (required)
- `edge domain` (required)
- `dns provider` (required)
  - present a numbered list from `dns-providers.json` (full support providers)

Validation rules:

- domains must be non-empty strings
- `dns provider` must be one of registry IDs

### Step 4 — Provider credential check (fail closed)

The flow determines required environment keys for the chosen provider from the registry.

Credential sources (in this order):

1. `/etc/trojan-pro/env`
2. current process environment variables

If required keys are missing:

- print `missing_provider_env=<KEY>` lines (single-language)
- print guidance:
  - export the env vars for current shell, or
  - write them to `/etc/trojan-pro/env`
- exit non-zero **before** running apply

> Note: This aligns with the existing kernel preflight (`scripts/install/lib/preflight.sh`).

### Step 5 — Print plan

Before any host mutation, print a “plan” block that includes:

**Paths to be written/updated** (default root prefix `/`):

- `/etc/trojan-pro/install-manifest.json`
- `/etc/trojan-pro/config.json`
- `/etc/caddy/Caddyfile`
- `/etc/trojan-pro/env` (only if operator opts to persist; otherwise remain read-only)
- `/usr/local/bin/tp`
- `/usr/local/bin/tpctl` (symlink)

**Services that may be restarted**:

- `caddy-custom.service`
- `trojan-pro.service` (if present in the installer)

**Rollback behavior**:

- last-known-good backups are created for manifest / Trojan config / Caddyfile before apply
- on validation failure, backups are restored and installer exits non-zero

### Step 6 — Confirmation gate

Prompt:

- “Type `YES` to continue, anything else to abort.”

Rules:

- only the exact string `YES` proceeds
- any other input exits with code 2

### Step 7 — Execute installation

The guided flow should run the kernel in two phases for operator clarity:

1) preflight plan run:

```bash
bash scripts/install/install-kernel.sh \
  --www-domain <www> \
  --edge-domain <edge> \
  --dns-provider <provider> \
  --check-only
```

2) apply:

```bash
bash scripts/install/install-kernel.sh \
  --www-domain <www> \
  --edge-domain <edge> \
  --dns-provider <provider> \
  --apply
```

The apply phase must be invoked only after the `YES` confirmation.

### Step 8 — Post-install instructions

Print:

```bash
tp status --json
tp validate
```

Also provide a short “Where to look for logs” pointer (without dumping secrets).

## Bootstrap script (`tp-install.sh`) design

### Responsibilities

`tp-install.sh` must remain intentionally small:

1. Detect architecture (amd64 vs arm64)
2. Download `tp` from GitHub Releases **latest**
3. Download the matching `.sha256` file
4. Verify sha256
5. Install `tp` to `/usr/local/bin/tp`
6. Execute `tp install` (interactive)

### Asset names (Release)

Required assets:

- `tp-linux-amd64`
- `tp-linux-amd64.sha256`
- `tp-linux-arm64`
- `tp-linux-arm64.sha256`
- `tp-install.sh`

Recommended:

- `tp-install.sh.sha256`

### Argument passthrough

Allow passing arguments through to `tp install`:

```bash
curl -fsSL .../tp-install.sh | sudo bash -s -- --lang en
```

Rule:

- Everything after `--` is forwarded to `tp install`.

### Dependencies

- `curl`
- `sha256sum`

If missing, print a single-language error and exit non-zero.

## `tp install` interface

### Subcommand

- `tp install`

### Flags

- `--lang en|zh-CN` (optional)
  - if omitted, prompt language selection
- `--non-interactive` (optional; for CI/contract tests)
  - requires passing all required inputs via flags
- `--www-domain <domain>` (non-interactive)
- `--edge-domain <domain>` (non-interactive)
- `--dns-provider <id>` (non-interactive)
- `--yes` (optional)
  - bypasses interactive `YES` prompt **only** for non-interactive use

Defaults:

- interactive by default
- apply by default, but still runs kernel `--check-only` first for readability

### Exit codes

- `0` success
- `1` validation/preflight failure
- `2` aborted by operator or invalid input

## Logging & secrecy

- Do not echo credential values.
- When reporting missing provider env, print only key names, e.g. `missing_provider_env=AWS_ACCESS_KEY_ID`.
- Any debug logging should be opt-in (e.g., `TP_DEBUG=1`) and still avoid secrets.

## Failure modes & handling

- **sha256 mismatch** (bootstrap): abort, do not execute downloaded binary.
- **unsupported arch**: abort with clear message.
- **missing provider env**: abort before apply.
- **kernel apply validate fails**: rely on existing rollback seam; surface non-zero exit.

## Testing strategy

### Contract tests

- Add/extend a CLI contract test to ensure:
  - `tp install --help` exists
  - `tp install --lang en` and `--lang zh-CN` parse
  - `tp install --non-interactive ... --yes` prints plan markers

### Doc consistency tests (optional but recommended)

- Add a small test ensuring both quick-install docs contain the same section headings.

### CI verification

- Ensure the existing `scripts/validate_full_installer_v1.sh` remains green after changes.

## Documentation deliverables

### New docs

- `docs/en/quick-install.md`
- `docs/zh-CN/quick-install.md`

### Index updates

- Add entries to `docs/README.md` bilingual entrypoints.
- Update root `README.md` Quick install section to:
  - show the one-liner
  - link to both quick-install docs

## Rollout notes

- Keep quick-install as “staging / controlled rollout” posture unless the operator has validated host prerequisites.
- Always prefer minimal bootstrap script + verified binary execution.
