# Trojan-Pro

Trojan-Pro is a high-performance C++ implementation of the Trojan protocol.

This repo also includes:
- a **manifest-backed Linux installer kernel** (Full Installer v1)
- a lightweight day-2 management CLI: `tp` / `tpctl`
- a desktop-first client product line (under `client/`)

---

## Quick install (guided) — Linux

Run the one-liner to start the guided installer:

```bash
curl -fsSL https://github.com/proxy-trojan/trojan-obfuscation/releases/latest/download/tp-install.sh | sudo bash
```

Docs:
- English: `docs/en/quick-install.md`
- 中文：`docs/zh-CN/quick-install.md`

---

## Full Installer v1 (kernel entrypoint) — Linux

If you prefer running the installer kernel directly:

### 1) Preflight (check-only)

```bash
export CLOUDFLARE_API_TOKEN="..."

bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --check-only
```

### 2) Apply

```bash
sudo bash scripts/install/install-kernel.sh \
  --www-domain www.example.com \
  --edge-domain edge.example.com \
  --dns-provider cloudflare \
  --apply
```

### 3) Validate / status

```bash
tp status --json
tp validate
```

### 4) Export a manifest-backed client bundle

```bash
tp export-client-bundle \
  --direct scripts/tests/fixtures/clash_rules_direct.sample.txt \
  --proxy scripts/tests/fixtures/clash_rules_proxy.sample.txt \
  --reject scripts/tests/fixtures/clash_rules_reject.sample.txt \
  --output dist/client-import/managed-edge.json
```

See detailed docs:
- `docs/en/full-installer-usage.md`
- `docs/zh-CN/full-installer-usage.md`
- `docs/en/day-2-operations.md`
- `docs/zh-CN/day-2-operations.md`

---

## Build from source (core)

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"
```

Or use the helper script:

```bash
./scripts/build-trojan-core.sh
```

---

## Basic usage (core binary)

### Run as server

```bash
./trojan -c server.json
```

### Run as client

```bash
./trojan -c client.json
```

Example config structure:

```json
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 443,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": ["your-password"],
  "ssl": {
    "cert": "/path/to/fullchain.crt",
    "key": "/path/to/private.key",
    "sni": "your-domain.com"
  }
}
```

---

## Documentation

- `docs/README.md`
- `docs/branching-and-release-status.md`
- `CHANGELOG.md`

---

## License

GPLv3.
