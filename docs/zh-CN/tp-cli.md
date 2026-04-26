# tp CLI

`tp` 是 manifest 驱动的 full installer 部署在 day-2 场景下的管理命令面。
`tpctl` 是兼容别名，实际指向同一个命令。

## 核心命令

- `tp status`
- `tp validate`
- `tp rotate-password`
- `tp set-web-mode static`
- `tp set-web-mode upstream --upstream https://origin.example.com`
- `tp reconfigure-dns-provider <provider>`
- `tp export-client-bundle --direct <file> --proxy <file> --reject <file> --output <file>`

## 说明

- 做 staged 验证或 fixture 测试时，可使用 `--root-prefix <path>`。
- `status --json` 会直接打印当前 install manifest。
- `validate` 会检查 manifest、Trojan config、Caddyfile 是否存在。
- `export-client-bundle` 复用 manifest-backed bundle export 路径。
