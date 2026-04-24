# Branch cleanup runbook / 分支清理运维说明

This page is bilingual by design.

## Purpose / 目的

Use `scripts/repo/cleanup-branches.sh` to review and prune local/remote branches safely.

使用 `scripts/repo/cleanup-branches.sh` 安全查看并清理本地/远端分支。

## Safe usage / 安全使用

Dry-run first:

```bash
bash scripts/repo/cleanup-branches.sh
```

Apply only after review:

```bash
bash scripts/repo/cleanup-branches.sh --apply
```

## Notes / 注意事项

- The script protects `main` and the current branch.
- Detached HEAD refuses `--apply`.
- Unmerged local branches are skipped instead of force deleted.
- Stale remote-tracking refs are handled with summary output.

- 脚本会保护 `main` 和当前分支。
- detached HEAD 下拒绝 `--apply`。
- 未合并的本地分支不会被强删，而是进入 skipped summary。
- stale remote-tracking refs 会进入摘要输出，不会中途崩溃。
