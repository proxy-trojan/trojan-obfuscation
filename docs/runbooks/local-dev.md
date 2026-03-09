# Runbook: Local Development

## Purpose

This runbook captures the current local development workflow for the `feature_1.0_no_obfus_and_no_rules` baseline.

## Prerequisites

For Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  cmake \
  libboost-system-dev \
  libboost-program-options-dev \
  libssl-dev \
  python3 \
  openssl
```

Optional (only if MySQL auth support is required):

```bash
sudo apt-get install -y default-libmysqlclient-dev
```

## Build

```bash
cmake -S . -B build/scan -DCMAKE_BUILD_TYPE=Release -DENABLE_MYSQL=OFF -DENABLE_SSL_KEYLOG=OFF
cmake --build build/scan -j"$(nproc)"
```

## Verify

Run the smoke/integration test suite:

```bash
ctest --test-dir build/scan --output-on-failure -j2
```

Expected tests:

- `LinuxSmokeTest-basic`
- `LinuxSmokeTest-server-config-fails`
- `LinuxSmokeTest-auth-fail-cooldown`
- `LinuxSmokeTest-fallback-budget`

## Key Notes

### SSL keylog

Release-style local builds should keep:

```bash
-DENABLE_SSL_KEYLOG=OFF
```

Enable key logging only for explicit debugging builds.

### Abuse control

The current baseline supports:

- per-IP concurrent connection limits
- authentication-failure cooldown
- fallback session budgeting

See `docs/runbooks/abuse-control.md` for tuning guidance.

## Troubleshooting

### Build fails due to missing Boost/OpenSSL

Re-check the prerequisite packages above.

### Smoke tests fail after security changes

Check:

- `docs/security.md`
- `docs/runbooks/abuse-control.md`
- current config defaults in `examples/server.json-example`

### New runtime guardrails block your local test flow

Temporarily lower the protection scope in a dedicated local config, but keep production defaults conservative.
