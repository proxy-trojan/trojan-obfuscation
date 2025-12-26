# 高级混淆与伪装模块

## 概述

本模块为 Trojan 提供高级 TLS 指纹混淆和握手伪装功能：

1. **TLS 指纹随机化** - 模拟 Chrome, Firefox, Safari, Edge, Opera, Brave 等浏览器
2. **握手数据混淆** - 从真实网站采集或随机生成握手数据
3. **JA3 指纹验证** - 验证和分析 TLS ClientHello 指纹
4. **最小化延迟开销** - 使用预计算缓存和异步预取

## 文件结构

```
src/obfuscation/
├── fingerprint.h/cpp        # TLS 指纹随机化
├── handshake_mimicker.h/cpp # 握手数据混淆
├── ja3_tool.h/cpp           # JA3 指纹验证工具
├── obfuscation_manager.h/cpp # 统一管理入口
└── README.md
```

## 支持的浏览器指纹

| 浏览器 | 版本 | GREASE | 备注 |
|--------|------|--------|------|
| Chrome | 120, 121 | ✅ | 基于 Chromium |
| Firefox | 121, 122 | ❌ | Mozilla 引擎 |
| Safari | 17 | ❌ | WebKit 引擎 |
| Edge | 120, 121 | ✅ | 基于 Chromium |
| Opera | 106 | ✅ | 基于 Chromium |
| Brave | 1.61 | ✅ | 基于 Chromium |

## 配置示例

```json
{
  "obfuscation": {
    "enabled": true,
    "fingerprint": {
      "enabled": true,
      "type": "random",
      "grease": true
    },
    "handshake_mimicry": {
      "enabled": true,
      "cache_file": "~/.trojan/handshake.bin",
      "prefetch": true
    },
    "timing": {
      "profile": "aggressive"
    },
    "padding": {
      "enabled": false
    }
  }
}
```

## 时序配置

| 配置 | 延迟范围 | 抖动 | 适用场景 |
|------|---------|------|---------|
| aggressive | 0-5ms | 2ms | 低延迟优先 |
| balanced | 5-50ms | 10ms | 平衡 |
| stealth | 20-200ms | 50ms | 高隐蔽性 |

## JA3 指纹工具

```cpp
#include "obfuscation/ja3_tool.h"

JA3Tool tool;

// 解析 ClientHello
JA3Fingerprint fp;
tool.parse_client_hello(raw_data, fp);

// 计算 JA3 哈希
std::string hash = tool.calculate_ja3_hash(fp);

// 验证指纹
std::string desc;
if (tool.verify_fingerprint(hash, desc)) {
    std::cout << "Known: " << desc << std::endl;
}

// 生成报告
std::cout << tool.generate_report(fp);
```

## 编译

在 CMakeLists.txt 中添加：

```cmake
set(OBFUSCATION_SOURCES
    src/obfuscation/fingerprint.cpp
    src/obfuscation/handshake_mimicker.cpp
    src/obfuscation/ja3_tool.cpp
    src/obfuscation/obfuscation_manager.cpp
)

add_executable(trojan
    ${TROJAN_SOURCES}
    ${OBFUSCATION_SOURCES}
)
```

## 注意事项

1. **Caddy 仍然需要** - 混淆模块解决客户端指纹问题，Caddy 解决服务端伪装问题
2. **仅客户端生效** - 混淆配置仅在 `run_type: client` 时生效
3. **指纹更新** - 浏览器指纹需要定期更新以保持有效性