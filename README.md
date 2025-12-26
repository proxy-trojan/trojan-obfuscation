# Trojan-Obfuscation

An enhanced version of Trojan with advanced TLS fingerprint obfuscation and traffic camouflage capabilities.

Trojan-Obfuscation is based on the original [Trojan](https://github.com/trojan-gfw/trojan) project, with significant improvements in anti-detection and traffic obfuscation to help bypass modern deep packet inspection (DPI) systems.

## What is Trojan?

Trojan is an unidentifiable mechanism that helps you bypass network restrictions. Unlike traditional obfuscation-based proxies, Trojan mimics the most common protocol on the Internet - HTTPS - to avoid both active/passive detection and ISP QoS limitations.

## Key Features

### Core Features (from Original Trojan)
- ✅ **TLS 1.3 Support** - Modern cipher suites with forward secrecy
- ✅ **HTTPS Camouflage** - Traffic looks like regular HTTPS to avoid detection
- ✅ **SOCKS5 Proxy** - Full SOCKS5 support with UDP forwarding
- ✅ **NAT Mode** - Transparent proxy mode (Linux only)
- ✅ **MySQL Authentication** - Centralized user management
- ✅ **High Performance** - Built on Boost.Asio for efficient async I/O

### Enhanced Features (Obfuscation Module)
- 🎯 **TLS Fingerprint Randomization** - Mimic real browsers (Chrome, Firefox, Safari, Edge, Opera, Brave)
- 🎯 **JA3 Fingerprint Evasion** - Randomize TLS ClientHello to avoid fingerprint-based detection
- 🎯 **GREASE Support** - RFC 8701 compliant GREASE extensions
- 🎯 **Handshake Mimicry** - Collect and replay handshake patterns from real websites
- 🎯 **Timing Obfuscation** - Configurable timing profiles (aggressive/balanced/stealth)
- 🎯 **Pre-computation Cache** - Minimize latency overhead with cached fingerprints
- 🎯 **Async Prefetch** - Background prefetch of handshake patterns

### Supported Browser Fingerprints

| Browser | Versions | GREASE | Engine |
|---------|----------|--------|--------|
| Chrome  | 120, 121 | ✅ | Chromium |
| Firefox | 121, 122 | ❌ | Mozilla |
| Safari  | 17       | ❌ | WebKit |
| Edge    | 120, 121 | ✅ | Chromium |
| Opera   | 106      | ✅ | Chromium |
| Brave   | 1.61     | ✅ | Chromium |

## Quick Start

### Prerequisites

- [CMake](https://cmake.org/) >= 3.7.2
- [Boost](http://www.boost.org/) >= 1.66.0
- [OpenSSL](https://www.openssl.org/) >= 1.1.0
- [libmysqlclient](https://dev.mysql.com/downloads/connector/c/) (optional)

**Debian/Ubuntu:**
\`\`\`bash
sudo apt -y install build-essential cmake libboost-system-dev libboost-program-options-dev libssl-dev default-libmysqlclient-dev
\`\`\`

**macOS:**
\`\`\`bash
brew install cmake boost openssl@1.1
\`\`\`

### Build

#### Option 1: One-command build (recommended)

This repo provides a cross-platform build script that:
- detects OS/arch automatically
- builds via CMake
- outputs versioned artifacts into `dist/`

\`\`\`bash
# Native build (current platform)
./scripts/build-trojan-core.sh

# Build with options
./scripts/build-trojan-core.sh --build-type Release --clean
\`\`\`

**Build Script Options:**

| Option | Description |
|--------|-------------|
| `--build-type <type>` | Release, Debug, RelWithDebInfo, MinSizeRel (default: Release) |
| `--target-os <os>` | linux, macos, windows, android, ios (default: auto-detect) |
| `--target-arch <arch>` | x86_64, arm64, armv7 (default: auto-detect) |
| `--build-all` | Build for all desktop platforms (Linux/macOS/Windows × x86_64/arm64) |
| `--build-mobile` | Build for all mobile platforms (Android arm64/armv7, iOS arm64) |
| `--clean` | Remove build directory before building |
| `--no-strip` | Do not strip the output binary |

**Cross-compilation Examples:**

\`\`\`bash
# Cross-compile for Linux ARM64
./scripts/build-trojan-core.sh --target-os linux --target-arch arm64

# Cross-compile for Windows x86_64 (requires mingw-w64)
./scripts/build-trojan-core.sh --target-os windows --target-arch x86_64

# Build all desktop platforms
./scripts/build-trojan-core.sh --build-all

# Build all mobile platforms (requires Android NDK / Xcode)
./scripts/build-trojan-core.sh --build-mobile
\`\`\`

**Output Artifacts:**
- `dist/trojan-<version>-<os>-<arch>` - Versioned binary
- `dist/trojan` - Convenience copy of the latest build

#### Option 2: Manual CMake build

\`\`\`bash
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DENABLE_MYSQL=OFF

# Linux:
# make -j$(nproc)
# macOS:
# make -j$(sysctl -n hw.ncpu)
make
\`\`\`

### Basic Client Configuration

Create \`config.json\`:

\`\`\`json
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "your-server.com",
    "remote_port": 443,
    "password": ["your-password"],
    "ssl": {
        "verify": true,
        "sni": "your-server.com"
    }
}
\`\`\`

### Client Configuration with Obfuscation (Recommended)

\`\`\`json
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "your-server.com",
    "remote_port": 443,
    "password": ["your-password"],
    "ssl": {
        "verify": true,
        "sni": "your-server.com",
        "alpn": ["h2", "http/1.1"]
    },
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
            "prefetch": true,
            "prefetch_domains": [
                "www.google.com",
                "www.cloudflare.com"
            ]
        },
        "timing": {
            "profile": "aggressive"
        }
    }
}
\`\`\`

### Server Configuration

\`\`\`json
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": ["your-password"],
    "ssl": {
        "cert": "/path/to/certificate.crt",
        "key": "/path/to/private.key",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256",
        "prefer_server_cipher": true,
        "alpn": ["http/1.1"],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    }
}
\`\`\`

### Running

\`\`\`bash
# Client
./trojan -c client-config.json

# Server
./trojan -c server-config.json
\`\`\`

## Configuration Details

### Obfuscation Options

#### Fingerprint Randomization

\`\`\`json
"fingerprint": {
    "enabled": true,
    "type": "random",      // Options: random, chrome, firefox, safari, edge, opera, brave
    "grease": true         // Enable GREASE extensions
}
\`\`\`

#### Handshake Mimicry

\`\`\`json
"handshake_mimicry": {
    "enabled": true,
    "cache_file": "~/.trojan/handshake.bin",  // Cache file path
    "prefetch": true,                          // Enable background prefetch
    "prefetch_domains": [
        "www.google.com",
        "www.cloudflare.com",
        "www.microsoft.com"
    ]
}
\`\`\`

#### Timing Profiles

| Profile    | Delay Range | Jitter | Use Case |
|------------|-------------|--------|----------|
| aggressive | 0-5ms       | 2ms    | Low latency priority |
| balanced   | 5-50ms      | 10ms   | Balance performance and stealth |
| stealth    | 20-200ms    | 50ms   | High stealth priority |

\`\`\`json
"timing": {
    "profile": "aggressive"  // Options: aggressive, balanced, stealth
}
\`\`\`

### Advanced Options

\`\`\`json
"obfuscation": {
    "padding": {
        "enabled": false,
        "min_bytes": 0,
        "max_bytes": 64
    },
    "record_splitting": {
        "enabled": false
    },
    "cache": {
        "enabled": true,
        "directory": "~/.trojan/cache"
    },
    "tls": {
        "enforce_tls13": true,
        "min_version": "0x0304"
    }
}
\`\`\`

## Documentation

- [Overview](docs/overview.md) - How Trojan works
- [Build Guide](docs/build.md) - Detailed build instructions
- [Configuration](docs/config.md) - Full configuration reference
- [Obfuscation Guide](src/obfuscation/README.md) - Advanced obfuscation features
- [ECH Guide](docs/ECH_GUIDE.md) - Encrypted Client Hello support

## Examples

See the [examples/](examples/) directory for more configuration examples:

- \`client.json-example\` - Basic client configuration
- \`client-obfuscation.json-example\` - Client with obfuscation
- \`server.json-example\` - Server configuration
- \`nat.json-example\` - NAT mode configuration
- \`forward.json-example\` - Forward proxy configuration

## Development & Secondary Development

### Project Structure

\`\`\`
trojan-obfuscation/
├── src/
│   ├── core/              # Core proxy logic
│   ├── session/           # Session management
│   ├── proto/             # Protocol implementation
│   ├── ssl/               # TLS/SSL wrapper
│   └── obfuscation/       # Obfuscation module (NEW)
│       ├── fingerprint.cpp          # TLS fingerprint randomization
│       ├── handshake_mimicker.cpp   # Handshake pattern mimicry
│       ├── ja3_tool.cpp             # JA3 fingerprint analysis
│       └── obfuscation_manager.cpp  # Unified management
├── docs/              # Documentation
├── examples/          # Configuration examples
├── cmake/             # CMake modules
└── CMakeLists.txt     # Build configuration
\`\`\`

### Adding New Features

#### 1. Add New Browser Fingerprints

Edit \`src/obfuscation/fingerprint.cpp\`:

\`\`\`cpp
void FingerprintRandomizer::generate_chrome_fingerprint(FingerprintConfig& config) {
    config.cipher_suites = {
        0x1301, 0x1302, 0x1303,  // TLS 1.3
        0xc02b, 0xc02f, 0xc02c, 0xc030,  // TLS 1.2
        // Add your cipher suites
    };
    config.supported_groups = {0x001d, 0x0017, 0x0018};
    config.signature_algorithms = {0x0403, 0x0503, 0x0603};
    // Configure other parameters
}
\`\`\`

#### 2. Add Custom Obfuscation Logic

Create a new module in \`src/obfuscation/\`:

\`\`\`cpp
// src/obfuscation/custom_obfuscator.h
#pragma once
#include <string>
#include <openssl/ssl.h>

class CustomObfuscator {
public:
    bool apply(SSL* ssl, const std::string& config);
    void configure(const boost::property_tree::ptree& pt);
};
\`\`\`

#### 3. Integrate with Core

Modify \`src/ssl/sslsession.cpp\` to use your obfuscation:

\`\`\`cpp
#include "obfuscation/obfuscation_manager.h"

void SSLSession::start() {
    if (config.obfuscation.enabled) {
        ObfuscationManager obfuscator(config.obfuscation);
        obfuscator.apply_to_ssl(ssl_socket.native_handle());
    }
    // Continue with normal handshake
}
\`\`\`

### Building with Custom Options

\`\`\`bash
cmake .. \\
    -DCMAKE_BUILD_TYPE=Release \\
    -DENABLE_MYSQL=ON \\
    -DENABLE_NAT=ON \\
    -DENABLE_REUSE_PORT=ON \\
    -DENABLE_SSL_KEYLOG=ON \\
    -DENABLE_TLS13_CIPHERSUITES=ON
\`\`\`

### Testing Your Changes

\`\`\`bash
# Build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
make

# Run with verbose logging
./trojan -c config.json -l 2
\`\`\`

### Contributing

We welcome contributions! Areas for improvement:

1. **More Browser Fingerprints** - Add fingerprints for newer browser versions
2. **Protocol Obfuscation** - Implement additional obfuscation techniques
3. **Performance Optimization** - Reduce overhead of obfuscation
4. **Platform Support** - Improve Windows and mobile platform support
5. **Documentation** - Improve guides and examples

## Important Notes

1. **Server-side Camouflage Required**: The obfuscation module addresses client-side fingerprinting. You still need a proper web server (like Caddy or Nginx) as fallback on the server side.

2. **Client-side Only**: Obfuscation features only work when \`run_type\` is set to \`client\`.

3. **Certificate Required**: Server must have a valid TLS certificate. Use Let's Encrypt for free certificates.

4. **Fingerprint Updates**: Browser fingerprints need periodic updates to stay effective.

## Comparison with Original Trojan

| Feature | Original Trojan | Trojan-Obfuscation |
|---------|----------------|-------------------|
| TLS Fingerprint | Static (OpenSSL default) | Randomized (browser mimicry) |
| JA3 Fingerprint | Predictable | Randomized with GREASE |
| Handshake Pattern | Fixed | Adaptive mimicry |
| Detection Resistance | Medium | High |
| Performance Overhead | Minimal | Low (~5-10ms) |

## Credits

This project is based on the original [Trojan](https://github.com/trojan-gfw/trojan) by GreaterFire.

**Original Project**: https://github.com/trojan-gfw/trojan

**Enhancements**: Advanced TLS obfuscation, JA3 randomization, handshake mimicry

**Author**: beautiful.us@protonmail.com

## License

[GPLv3](LICENSE)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

## Disclaimer

This software is provided for educational and research purposes only. Users are responsible for complying with local laws and regulations. The authors and contributors are not responsible for any misuse of this software.
