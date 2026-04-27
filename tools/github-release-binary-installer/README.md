# GitHub Release binary installer (Linux)

A small **generic** installer for a single executable binary distributed via **GitHub Releases**.

This is intended for **normal / legal** software distribution (internal tools, open-source utilities, etc.).

## Assumptions

- Your GitHub Release contains **two** Linux binaries:
  - `<tool>-linux-amd64`
  - `<tool>-linux-arm64`
- Each asset has a matching `sha256sum` sidecar file:
  - `<asset>.sha256`

The `.sha256` file may be either:

- `sha256sum` format: `<hash>  <filename>`
- or just the hash on the first line

## Usage

### Check-only (no writes)

```bash
bash tools/github-release-binary-installer/install-binary.sh \
  --repo owner/repo \
  --tool mytool \
  --check-only
```

### Install latest to /usr/local/bin

```bash
sudo bash tools/github-release-binary-installer/install-binary.sh \
  --repo owner/repo \
  --tool mytool
```

### Force target

```bash
sudo bash tools/github-release-binary-installer/install-binary.sh \
  --repo owner/repo \
  --tool mytool \
  --target linux-arm64
```

### Install a specific tag

```bash
sudo bash tools/github-release-binary-installer/install-binary.sh \
  --repo owner/repo \
  --tool mytool \
  --version v1.2.3
```

## Flags

- `--repo <owner/repo>` (required)
- `--tool <name>` (required)
- `--version latest|<tag>` (default: `latest`)
- `--target auto|linux-amd64|linux-arm64` (default: `auto`)
- `--install-dir <dir>` (default: `/usr/local/bin`)
- `--dest-name <name>` (default: `<tool>`)
- `--check-only`

## Notes

- Latest download URL form:
  - `https://github.com/<owner>/<repo>/releases/latest/download/<asset>`
- Tagged URL form:
  - `https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>`
