# Quick Install (Guided) — Linux

This page describes the shortest **guided** path to install a self-hosted TLS service stack on a Linux host.

- Entry: **one-liner** (`curl | sudo bash`)
- Supply-chain safety: downloads `tp` from **GitHub Releases (latest)** and verifies **sha256**
- Guided install: runs `tp install` (interactive) and requires an explicit `YES` before host mutation

> Neutral positioning
>
> This guide focuses on infrastructure installation and operations (ACME DNS-01, systemd). It does not cover any specific network-circumvention use case.

---

## 1) Prerequisites

- A Linux host (systemd assumed)
- A domain with DNS records prepared for:
  - `www.<domain>` (public web surface)
  - `edge.<domain>` (TLS entry domain)
- Ports **80** and **443** reachable (both OS firewall and provider edge)
- DNS provider API credentials for **ACME DNS-01**

Supported DNS providers (full tier):

- `cloudflare`
- `route53`
- `alidns`
- `dnspod`
- `gcloud`

---

## 2) One-liner (guided)

Run:

```bash
curl -fsSL https://github.com/proxy-trojan/trojan-obfuscation/releases/latest/download/tp-install.sh | sudo bash
```

What happens:

1. The script downloads `tp` for your CPU architecture and verifies its `.sha256` checksum.
2. It installs `tp` to `/usr/local/bin/tp`.
3. It starts an interactive guided flow: `tp install`.

---

## 3) What you will be asked

The guided installer will prompt for:

- `www domain`
- `edge domain`
- `dns provider`

It will also check the required environment keys for the chosen provider.

> Credentials are read from `/etc/trojan-pro/env` and the current process environment.

---

## 4) Plan + confirmation gate (required)

Before it mutates the host, the installer prints a plan including:

- Files that will be written/updated (paths under `/etc`)
- Services that may be restarted
- Rollback notes (last-known-good backups)

You must type **`YES`** to continue. Any other input aborts.

---

## 5) Post-install verification

After apply completes:

```bash
tp status --json
tp validate
```

---

## 6) Troubleshooting

### missing_provider_env=...

Required DNS provider credential env keys are missing.

Fix options:

- Export the required env keys in your shell session, or
- Put them into `/etc/trojan-pro/env` (recommended for day-2 operations)

See:
- `docs/en/dns-providers.md`

### ACME fails / certificate not issued

Common causes:

- DNS is not pointing to the target host yet (propagation incomplete)
- Ports **80/443** are blocked
- Another service is already bound to **80/443**

Re-check DNS and ports, then re-run the installer.

### Aborted by design (did not type YES)

This is expected behavior. Re-run the one-liner and confirm with `YES`.
