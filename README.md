# Trojan-Pro

Trojan-Pro is a high-performance C++ implementation of the Trojan protocol, with a multi-platform release pipeline for both the core binary and desktop/mobile client packages.

## What it provides

- Trojan core server/client
- Multi-platform release artifacts via GitHub Actions
- Desktop-first client packaging (Linux / Windows / macOS)
- Optional Android client APK lane

## Quick start

### 1) Download a release

Get the latest release from:

- <https://github.com/proxy-trojan/trojan-obfuscation/releases>

### 2) Build from source

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

Or use the helper script:

```bash
./scripts/build-trojan-core.sh
```

## Basic usage

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

More details:
- `docs/config.md`
- `docs/usage.md`
- `docs/build.md`

## Release artifacts

Current release flow produces:

### Core
- Linux x86_64
- Linux aarch64
- macOS x86_64
- macOS arm64
- Windows x86_64

### Client
- Linux `.deb`
- Linux `.tar.gz`
- Windows `.zip`
- macOS `.app.zip`
- Android `.apk` (release lane enabled in tagged releases)

## Client workspace

The desktop-first client lives in:

```bash
client/
```

Client docs:
- `client/README.md`
- `docs/client-product-architecture.md`
- `docs/client-packaging-readiness.md`
- `docs/client-cross-platform-packaging.md`

## Documentation

- `docs/README.md`
- `docs/branching-and-release-status.md`
- `CHANGELOG.md`

## License

GPLv3.\n