# Design Spec: Full Installer v1 + Day-2 Management CLI

- Date: 2026-04-25
- Owner: assistant + user
- Scope: `trojan-obfuscation`
- Status: draft for user review
- Supersedes: `docs/superpowers/specs/2026-04-24-repo-cleanup-installer-routing-design.md` for installer/runtime delivery scope

## 1. Goal

Deliver a **real host-mutating installer** for Trojan-Pro that can:

- mutate a target Linux host safely
- install dependencies and managed binaries
- configure a public web surface and a Trojan edge entrypoint
- manage certificates automatically through DNS-01
- expose a short day-2 management CLI (`tp`, with `tpctl` compatibility alias)
- remain operable after first install instead of behaving like a one-shot bootstrap script

This design intentionally upgrades the prior “installer skeleton + static bundle converter” direction into a **full installer v1** with explicit operational boundaries.

## 2. Confirmed decisions

User-confirmed decisions from brainstorming:

1. Installer depth: **full host-mutating installer**
2. OS scope: **generic Linux multi-distro**
3. Trojan delivery: **prebuilt release binary**
4. Front door topology: **Caddy on 80/443, Trojan behind it**
5. Caddy delivery: **prebuilt custom Caddy binary**
6. Domain topology: **split domains**
   - `www.example.com` → public web surface
   - `edge.example.com` → Trojan entrypoint
7. Certificates: **automatic**, with DNS API credentials accepted
8. Priority: **security + detectability resistance first**
9. DNS provider strategy: **all compiled providers selectable, but with support tiers**
10. Public web mode: **built-in static site by default, later switchable to real upstream**
11. Fully supported DNS providers in v1:
    - Cloudflare
    - Route53
    - AliDNS
    - DNSPod
    - Google Cloud DNS
12. Day-2 management CLI:
    - primary command: `tp`
    - compatibility alias: `tpctl`
    - scope: **lightweight management**, not a full control plane

## 3. Non-goals

Explicitly excluded from v1:

- building a full GUI/server control plane
- supporting every DNS provider as fully documented and CI-covered
- client runtime rule-provider subscription
- multi-node orchestration or clustered deployment
- non-Linux host installation
- building Caddy on the target host with `xcaddy`
- compiling Trojan from source on the target host

## 4. High-level architecture

### 4.1 Public topology

```text
Internet
  ├─ 80/tcp  ───────────────> custom Caddy
  └─ 443/tcp ───────────────> custom Caddy (layer4 front door)
                                 ├─ SNI = www.example.com
                                 │    └─ TLS terminated by Caddy
                                 │       ├─ serve built-in static site
                                 │       └─ optional later switch to real upstream
                                 └─ SNI = edge.example.com
                                      └─ L4 passthrough to local Trojan
                                             (127.0.0.1:<edge_port>)
```

### 4.2 Core principles

- public 80/443 are owned only by **custom Caddy**
- Trojan never binds a public interface by default
- the public web surface and the Trojan edge entrypoint are intentionally separated by SNI/domain
- certificate lifecycle is centrally managed, while runtime consumers use stable exported paths
- installer changes must be rollback-aware and fail closed

## 5. Installer responsibilities

The installer is responsible for:

1. preflight checks
2. dependency installation
3. downloading and verifying prebuilt Trojan and custom Caddy binaries
4. rendering runtime configuration
5. bootstrapping certificates
6. activating services
7. validating the resulting deployment
8. storing enough state for subsequent day-2 management via `tp`

The installer is **not** responsible for:

- generating arbitrary website content
- operating as a generic config-management engine
- making every possible DNS provider “first-class supported” in v1

## 6. File and state model

### 6.1 Single source of truth

The single source of truth is:

```text
/etc/trojan-pro/install-manifest.json
```

This manifest records:

- `www_domain`
- `edge_domain`
- selected DNS provider id
- provider support tier
- required env key names / references
- current web mode (`static` or `upstream`)
- configured upstream URL if present
- Trojan local listen address/port
- installed Trojan and Caddy versions
- certificate mode and managed cert paths
- install/apply timestamps
- last successful validation summary

### 6.2 Sensitive environment

Sensitive values live in:

```text
/etc/trojan-pro/env
```

Examples:

- DNS API credentials
- Trojan password material if stored locally
- any future provider-specific secret

Requirements:

- file mode `0600`
- never echoed in normal logs
- never required as plain CLI flags for day-2 operations once installed

### 6.3 Rendered artifacts

Generated runtime artifacts are derived from the manifest:

```text
/etc/trojan-pro/config.json         # Trojan runtime config
/etc/caddy/Caddyfile                # Custom Caddy config
/etc/trojan-pro/certs/current/*     # stable exported cert paths for Trojan
```

Rendered files are **outputs**, not the source of truth.

### 6.4 Backups and state

```text
/var/lib/trojan-pro/
  backups/<timestamp>/
  state/
  site/
```

Backups store:

- previous manifest
- previous Trojan config
- previous Caddy config
- previous service unit or overrides if changed
- metadata describing the change attempt

## 7. Installation flow

The installer uses a fixed staged pipeline:

1. **preflight**
2. **install dependencies**
3. **install binaries**
4. **render config**
5. **certificate bootstrap**
6. **activate services**
7. **validate deployment**

### 7.1 Preflight

Preflight must check at least:

- root/sudo availability
- supported architecture
- supported package manager
- systemd availability
- port 80/443 conflicts
- DNS resolution sanity for `www` and `edge`
- DNS provider credentials present for the selected provider
- required commands and writable install paths

If preflight fails, installer exits before mutating runtime state.

### 7.2 Install dependencies

Supported package-manager families:

- `apt`
- `dnf`
- `yum` (compat entry for RHEL family)
- `pacman`
- `zypper`

v1 capability target is “generic Linux”, but validation is done by package-manager family, not by claiming infinite distro coverage.

### 7.3 Install binaries

Installer downloads and verifies:

- Trojan prebuilt binary
- custom Caddy prebuilt binary

Requirements:

- architecture-aware asset selection
- SHA256 verification against a signed/controlled manifest
- download to staging path first
- atomic move into final install path after verification
- do not overwrite a running binary in-place without backup/switch logic

Recommended paths:

```text
/usr/local/bin/trojan
/usr/local/bin/caddy-custom
/usr/local/bin/tp
/usr/local/bin/tpctl -> /usr/local/bin/tp
```

### 7.4 Render config

Render outputs include:

- Trojan runtime config
- Caddy layer4 + web config
- environment files
- systemd unit files or drop-ins
- default static site for `www`

All rendered outputs are written to staging or temp paths first, syntax-checked where possible, then promoted.

### 7.5 Certificate bootstrap

Certificates are obtained automatically through DNS-01.

Default v1 certificate model:

- `www.example.com` gets its own certificate
- `edge.example.com` gets its own certificate

Rationale:

- smaller blast radius than a default wildcard-first model
- more realistic public-surface behavior
- clearer failure isolation between web and edge roles

Caddy handles ACME automation; Trojan consumes stable exported cert/key paths instead of depending directly on internal Caddy storage layout.

### 7.6 Activate services

Typical activation sequence:

- `systemctl daemon-reload`
- start/restart/reload custom Caddy as needed
- start/restart/reload Trojan as needed

Activation happens only after config rendering and certificate availability checks pass.

### 7.7 Validate deployment

Validation must check:

- config syntax / parse validity
- systemd service health
- `www` reachable and serving expected content mode
- `edge` entrypoint alive on the intended SNI path
- certificate files exist and are not obviously expired
- last-known-good snapshot updated only after success

## 8. Day-2 management CLI

### 8.1 Command names

- primary command: `tp`
- compatibility alias: `tpctl`

Because `tp` may collide with existing aliases or local tools, installer must:

- detect whether `tp` already exists and is not ours
- refuse silent overwrite
- provide a clear fallback message instructing the user to use `tpctl`

### 8.2 Command scope

The CLI is intentionally **lightweight management**, not a universal control plane.

#### Observe / diagnose

```bash
tp status
tp doctor
tp validate
tp logs [trojan|caddy]
tp restart [trojan|caddy|all]
tp reload [trojan|caddy|all]
tp uninstall
```

#### Light configuration / lifecycle management

```bash
tp rotate-password
tp renew-cert
tp set-web-mode static
tp set-web-mode upstream
tp set-upstream https://example-upstream.com
tp export-client-bundle
tp upgrade-binaries
tp reconfigure-dns-provider
```

### 8.3 Behavioral rules

- CLI changes mutate the manifest first
- rendered configs are regenerated from the manifest
- apply only proceeds after validation gates succeed
- sensitive values are never required to be re-passed on every day-2 action unless explicitly rotating/replacing them

### 8.4 Required status surface

`tp status` should expose at least:

- `www` and `edge` domains
- selected DNS provider
- support tier
- web mode (`static`/`upstream`)
- installed Trojan and Caddy versions
- certificate expiry summary
- service health summary
- last successful apply timestamp
- last successful validate timestamp

### 8.5 Required doctor surface

`tp doctor` should inspect at least:

- port occupancy
- provider env presence (without printing values)
- cert file existence and near-expiry state
- Caddy config validity
- Trojan config validity
- systemd service state
- recent relevant log excerpts

## 9. DNS provider strategy

### 9.1 Support tiers

The design separates **selectable providers** from **fully supported providers**.

All DNS providers compiled into custom Caddy may be exposed as selectable options.
Only the following providers are fully supported in v1:

- Cloudflare
- Route53
- AliDNS
- DNSPod
- Google Cloud DNS

“Fully supported” means:

- complete docs and examples
- complete env-key validation guidance
- contract/path-level tests
- operator-facing troubleshooting guidance

All other compiled-in providers are **best effort**.

### 9.2 Provider registry model

Each provider entry should define at least:

- `id`
- `support_tier`
- `caddy_dns_module`
- `required_env_keys`
- `optional_env_keys`
- `docs_slug`
- `example_ref`

This enables `tp reconfigure-dns-provider` to work by changing registry-backed metadata instead of hardcoding custom logic per provider in random places.

## 10. Custom Caddy delivery

### 10.1 Why custom Caddy

Stock distro Caddy is insufficient for the chosen topology because the public front door needs layer4 routing behavior in addition to normal HTTPS site handling.

### 10.2 Delivery model

Installer does **not** build Caddy on the target host.
It downloads a prebuilt custom Caddy artifact with the required modules compiled in.

Expected release assets:

- `linux-amd64`
- `linux-arm64`

Each artifact manifest records:

- Caddy version
- target architecture
- SHA256
- compiled modules
- recommended install path

Installer only accepts binaries listed in the controlled manifest.

## 11. Certificate model

### 11.1 Public web cert

`www.example.com` uses Caddy-managed ACME automation for normal HTTPS termination.

### 11.2 Edge cert

`edge.example.com` certificate material is managed through the installer-controlled certificate workflow and exported to a stable path that Trojan consumes, such as:

```text
/etc/trojan-pro/certs/current/edge.crt
/etc/trojan-pro/certs/current/edge.key
```

Trojan must not depend on undocumented/internal Caddy storage layout.

### 11.3 Secret handling rules

- no secret values in logs
- no secret values in status output
- no routine day-2 workflows that require putting secrets back on the command line
- credential presence is reported as configured/missing only

## 12. Routing behavior

### 12.1 443 behavior

- `SNI == www.example.com`
  - TLS terminated by Caddy
  - serves built-in static site or proxies to configured upstream
- `SNI == edge.example.com`
  - layer4 passthrough to local Trojan on `127.0.0.1:<edge_port>`
- any other SNI
  - must **not** be forwarded to Trojan
  - rejected or handled by explicit public-surface policy, but never silently mixed into the edge path

### 12.2 80 behavior

Port 80 is used for:

- health checks
- public redirect/bootstrap behavior as configured
- public web handling only

It never serves as a Trojan path.

## 13. Public web surface strategy

Default public web mode is:

- built-in static site for `www`

Later the operator may switch to:

- `upstream` mode via `tp set-web-mode upstream` and `tp set-upstream <url>`

This preserves a low-friction first install while keeping a path toward a more realistic public surface.

## 14. Failure handling and rollback

### 14.1 Failure classes that must be handled explicitly

1. port 80/443 already occupied
2. provider credentials missing or invalid
3. binary checksum mismatch
4. rendered config invalid
5. service start/reload failure
6. cert refresh succeeded but service reload failed

### 14.2 Rollback rules

Before any apply-like mutation, backup:

- previous manifest
- previous Trojan config
- previous Caddy config
- service unit or override files if changed

On failure during apply/upgrade/reconfigure:

1. restore last-known-good configuration
2. try to restore service availability
3. emit a clear failure reason
4. do not mark the new state as successful

### 14.3 Fail-closed rule

The system must not silently leave behind an ambiguous half-good state such as:

- `www` healthy but `edge` miswired while reported as success
- new binary installed but service not actually recoverable
- certificate files replaced without a usable runtime reload path

## 15. Upgrade strategy

### 15.1 Binary upgrade

`tp upgrade-binaries` follows:

```text
download to staging
→ checksum verify
→ inspect version/arch
→ backup current binaries/config refs
→ atomic switch
→ validate
→ success snapshot or rollback
```

### 15.2 Password rotation

`tp rotate-password` must:

- update manifest/runtime references safely
- regenerate Trojan config
- reload Trojan
- warn that clients need updated credentials
- optionally chain into `tp export-client-bundle`

## 16. Testing and validation strategy

Validation is layered into four levels.

### 16.1 L1: Local contract tests

Cover:

- manifest schema
- provider registry correctness
- config rendering
- CLI argument/output contracts
- rollback selection logic

### 16.2 L2: Offline integration tests

Cover:

- package-manager family branches
- binary download/verify/stage/promote logic
- systemd unit generation
- static site generation
- install/upgrade/uninstall flows without requiring real ACME

### 16.3 L3: Semi-real host smoke tests

Cover at least:

- fresh host install
- `tp validate`
- `tp doctor`
- `tp reload`
- `tp upgrade-binaries`
- `tp rotate-password`

### 16.4 L4: Limited live acceptance

Only for fully supported DNS providers, validate real flows for:

- DNS-01
- certificate refresh
- `www` reachability
- `edge` entrypoint viability

## 17. Formal validation matrix

### 17.1 Package-manager families to validate in v1

- Debian/Ubuntu (`apt`)
- Rocky/Alma/RHEL family (`dnf` / `yum` compatibility path)
- Arch (`pacman`)
- openSUSE Leap (`zypper`)

### 17.2 Architectures to validate

- `linux-amd64`
- `linux-arm64` (at least binary-path contract and selected smoke coverage)

### 17.3 DNS provider live validation scope

Live acceptance is only promised for:

- Cloudflare
- Route53
- AliDNS
- DNSPod
- Google Cloud DNS

## 18. Observability and operator UX

The installer and `tp` should produce outputs that are:

- short by default
- evidence-oriented
- safe for logs
- explicit about which stage failed

Examples of required operator evidence:

- selected provider id and support tier
- binary versions and checksums verified
- config validation result
- cert availability summary
- service health state
- last-known-good rollback target id

## 19. Security and detectability posture

Primary non-functional priorities are, in order:

1. **security**
2. **detectability resistance**
3. **operability**
4. **extensibility**

Implications:

- no “pretend success” on partial install
- split-domain public/edge separation by default
- public web surface must remain independently plausible
- unknown traffic must not be lazily mixed into the Trojan path
- secret handling must stay out of normal operator output

## 20. Success criteria

The design is considered successfully implemented when all of the following are true:

1. a supported Linux host can be installed end-to-end using the full installer
2. public 80/443 are owned only by custom Caddy
3. Trojan listens only on a local/private interface by default
4. `www` is publicly reachable over HTTPS
5. `edge` is reachable through the intended SNI route
6. DNS-01 certificate automation works for the selected fully supported provider
7. `tp` can perform status/doctor/validate/reload and selected lightweight management actions
8. failed apply/upgrade/reconfigure operations restore a last-known-good state
9. docs clearly separate fully supported providers from best-effort selectable ones
10. no placeholder-level design gaps remain in the v1 scope

## 21. Scope checkpoints for implementation planning

To keep implementation tractable, the plan should treat this design as four major workstreams:

1. installer/runtime truth foundation
2. custom Caddy + provider registry + cert/export model
3. `tp` lightweight management CLI
4. validation matrix + docs + live acceptance gates

Each workstream should be independently reviewable and validated.
