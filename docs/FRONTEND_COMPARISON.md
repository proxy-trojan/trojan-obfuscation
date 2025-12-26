# 部署方案对比

本文档对比 Trojan 的部署方案。

## 推荐方案：Trojan 前置

```
Client → Trojan (443, TLS) → 有效请求 → 目标服务器
                           → 无效请求 → Caddy/Nginx (8080) → 伪装网站
```

**优点：**
- 密码在 TLS 内传输，最安全
- 完整控制 TLS 握手特征
- 伪装更真实

**配置示例：**
- Trojan: `examples/server.json-example`
- Caddy: `examples/Caddyfile-example`

## 伪装后端选择

| 后端 | 优点 | 配置示例 |
|------|------|----------|
| **Caddy** | 简单、自动 HTTPS | `Caddyfile-example` |
| **Nginx** | 性能好、成熟 | `nginx-frontend.conf-example` |
| **静态响应** | 最简单 | Trojan 内置 `plain_http_response` |

## 配置示例

### Trojan 服务端

```json
{
    "run_type": "server",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 8080,
    "ssl": {
        "cert": "/path/to/cert.pem",
        "key": "/path/to/key.pem"
    }
}
```

### Caddy 伪装网站

```
:8080 {
    root * /var/www/html
    file_server
}
```

## 证书获取

```bash
# 使用 certbot 获取 Let's Encrypt 证书
certbot certonly --standalone -d example.com

# 证书路径
# /etc/letsencrypt/live/example.com/fullchain.pem
# /etc/letsencrypt/live/example.com/privkey.pem
```
