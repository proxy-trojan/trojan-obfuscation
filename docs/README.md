# Trojan Documentation

This directory keeps current, actionable project documentation.

## Bilingual entrypoints

- 中文快速开始：`zh-CN/quickstart.md`
- English quickstart: `en/quickstart.md`
- 中文安装骨架：`zh-CN/install-kernel.md`
- English install kernel: `en/install-kernel.md`
- 中文配置生成：`zh-CN/config-generation.md`
- English config generation: `en/config-generation.md`
- 中文 tp CLI：`zh-CN/tp-cli.md`
- English tp CLI: `en/tp-cli.md`
- 中文 DNS provider：`zh-CN/dns-providers.md`
- English DNS providers: `en/dns-providers.md`
- 中文 Full Installer 使用指南：`zh-CN/full-installer-usage.md`
- English Full Installer usage: `en/full-installer-usage.md`
- 中文 Day-2 运维：`zh-CN/day-2-operations.md`
- English day-2 operations: `en/day-2-operations.md`
- Ops runbook: `ops/branch-cleanup.md`
- Ops live acceptance: `ops/full-installer-live-acceptance.md`

## Script index

- `scripts/install/install-kernel.sh` — manifest-backed Linux full installer entrypoint
- `scripts/install/runtime/cli.py` — `tp` / `tpctl` day-2 management CLI
- `scripts/config/generate-client-bundle.py` — clash-rules to client import bundle generator
- `scripts/validate_full_installer_v1.sh` — full installer v1 contract + integration validation bundle
- `scripts/repo/cleanup-branches.sh` — branch cleanup dry-run/apply helper

## Core docs

- `overview.md` — project overview
- `protocol.md` — Trojan protocol notes
- `config.md` — configuration reference
- `build.md` — build instructions
- `usage.md` — runtime usage
- `security.md` — security notes
- `authenticator.md` — authentication design

## Release / delivery

- `branching-and-release-status.md` — current branch strategy and release flow
- `release-playbook.md` — formal release procedure and rollback guidance
- `v1.5.0-release-gates.md` — completion and release gates for the v1.5.0 milestone
- `../CHANGELOG.md` — versioned release history

## Decisions

- `decisions/001-branch-and-release-strategy.md`
- `decisions/002-client-product-direction.md`

## Client docs

- `client-product-architecture.md` — client architecture overview
- `adr-client-product-stack.md` — client stack decision record
- `client-packaging-readiness.md` — current packaging status
- `client-cross-platform-packaging.md` — packaging matrix and CI status

## Runbooks

- `runbooks/local-dev.md` — local development notes
- `runbooks/abuse-control.md` — abuse-control operational notes
