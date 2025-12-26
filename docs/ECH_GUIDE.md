# ECH (Encrypted Client Hello) 使用指南

## 概述

ECH (Encrypted Client Hello) 是 TLS 1.3 的扩展，可以加密 ClientHello 中的敏感信息（如 SNI），使 DPI 无法检测真实目标域名。

## 重要说明：OpenSSL ECH 支持状态

> ⚠️ **OpenSSL 3.5/3.6 并不支持 ECH**
>
> 尽管网上有些文章声称 OpenSSL 3.5+ 支持 ECH，但这是**不准确的**。
>
> **实际情况 (截至 2024年12月):**
> - OpenSSL 主线 (3.0, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6): **不支持 ECH**
> - sftcd/openssl ECH 分支: 功能完整，但**未合并到主线**
> - 预计 OpenSSL 4.0 (2026年4月) **可能**包含 ECH
>
> **目前支持 ECH 的 TLS 库:**
> - BoringSSL ✅
> - wolfSSL ✅
> - OpenSSL (sftcd 分支) ✅ (非官方)

## 对 Trojan 的价值

| 传统 TLS | ECH |
|----------|-----|
| SNI 明文可见 | SNI 加密 |
| DPI 可识别目标 | DPI 只看到 CDN 域名 |
| 指纹可分析 | 内层 ClientHello 加密 |

## 方案 1: Cloudflare + ECH (推荐)

### 架构

```
┌──────────┐     ECH      ┌─────────────┐     TLS      ┌────────────┐
│  Client  │ ──────────→  │ Cloudflare  │ ──────────→  │  Trojan    │
│          │              │   (CDN)     │              │  Server    │
└──────────┘              └─────────────┘              └────────────┘
     │                          │
     │ SNI: cloudflare-ech.com  │ 真实连接到你的服务器
     │ (DPI 只看到这个)          │
```

### 配置步骤

#### 1. 服务器配置

将你的域名添加到 Cloudflare：

1. 登录 Cloudflare Dashboard
2. 添加你的域名 (如 `your-trojan.com`)
3. 启用 "Proxy" (橙色云朵)
4. SSL/TLS 设置为 "Full (strict)"

#### 2. 启用 ECH

在 Cloudflare Dashboard:
1. 进入 SSL/TLS → Edge Certificates
2. 启用 "Encrypted Client Hello"

#### 3. 客户端配置

```json
{
    "run_type": "client",
    "remote_addr": "your-trojan.com",
    "remote_port": 443,
    "ssl": {
        "sni": "your-trojan.com",
        "verify": true
    }
}
```

客户端需要使用支持 ECH 的软件：
- Firefox 118+ (需要在 about:config 启用 `network.dns.echconfig.enabled`)
- Chrome 117+ (需要启用 Secure DNS)

### 验证 ECH 是否生效

```bash
# 使用 curl 测试 (需要支持 ECH 的版本)
curl -v --ech true https://your-trojan.com

# 或使用 Cloudflare 的测试页面
# https://www.cloudflare.com/ssl/encrypted-sni/
```

## 方案 2: 自建 ECH (高级)

### 要求

- 使用 BoringSSL 替代 OpenSSL
- 自己管理 ECH 密钥
- 通过 DNS HTTPS 记录发布 ECH 配置

### ECH 密钥生成

```bash
# 使用 BoringSSL 工具生成 ECH 配置
bssl generate-ech -out-ech-config-list ech_configs.bin \
    -out-ech-config ech_config.bin \
    -out-private-key ech_key.bin \
    -public-name cloudflare-ech.com \
    -config-id 1
```

### DNS 配置

添加 HTTPS 记录：
```
your-trojan.com. 300 IN HTTPS 1 . alpn="h2,http/1.1" ech="<base64-encoded-ech-config>"
```

## 当前限制

| 限制 | 说明 | 解决方案 |
|------|------|---------|
| OpenSSL 不支持 ECH | 主线版本 (包括 3.6) 均不支持 | 使用 Cloudflare 方案 |
| 需要 DNS HTTPS 记录 | 传统 DNS 不支持 | 使用 DoH/DoT |
| 客户端支持有限 | 部分软件不支持 | 使用支持的浏览器 |

## Trojan 的 ECH 支持状态

### 当前实现

我们在 `src/obfuscation/fingerprint.h/cpp` 中预留了 ECH 接口：

```cpp
// ECH 配置结构
struct ECHConfig {
    std::string public_name;      // 外层 SNI
    std::vector<uint8_t> ech_config_list;  // ECH 配置
    bool enabled = false;
};

// API
bool set_ech_config(SSL* ssl, const ECHConfig& config);
bool is_ech_supported();
```

### 编译选项

如果你想使用 ECH，需要用 BoringSSL 替代 OpenSSL 编译：

```bash
# 1. 克隆 BoringSSL
git clone https://boringssl.googlesource.com/boringssl
cd boringssl && mkdir build && cd build
cmake .. && make

# 2. 编译 Trojan 时指定 BoringSSL
cmake -DOPENSSL_ROOT_DIR=/path/to/boringssl ..
make
```

### 检测 ECH 支持

```cpp
#include "obfuscation/fingerprint.h"

FingerprintRandomizer fp;
if (fp.is_ech_supported()) {
    // 可以使用 ECH
    FingerprintRandomizer::ECHConfig config;
    config.enabled = true;
    config.public_name = "cloudflare-ech.com";
    fp.set_ech_config(ssl, config);
}
```

## 未来计划

Trojan 计划在以下条件满足时添加完整 ECH 支持：

1. **短期**: 提供 BoringSSL 编译选项 (CMake 配置)
2. **中期**: 监控 OpenSSL 4.0 开发进度
3. **长期**: OpenSSL 主线支持 ECH 后，默认启用

### 时间线预估

| 时间 | 事件 |
|------|------|
| 2024 Q4 | 添加 BoringSSL 编译支持 |
| 2025 | 测试 ECH 功能 |
| 2026 Q2 | OpenSSL 4.0 发布 (可能包含 ECH) |

## 参考资料

- [Cloudflare ECH 文档](https://developers.cloudflare.com/ssl/edge-certificates/ech/)
- [ECH 规范 (RFC 草案)](https://datatracker.ietf.org/doc/draft-ietf-tls-esni/)
- [Firefox ECH 支持](https://wiki.mozilla.org/Security/Encrypted_Client_Hello)
