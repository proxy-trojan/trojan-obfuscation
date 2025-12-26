#!/bin/bash
#
# Trojan + Caddy 一键部署脚本
# 支持: Debian/Ubuntu, CentOS/RHEL/Fedora, Alpine, Arch Linux
# 功能: 自动安装依赖、编译Trojan、配置Caddy、申请SSL证书、启动服务
#

set -e

# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==================== 全局变量 ====================
# NOTE:
# This script deploys *trojan-pro* (this repository). It expects to run from within
# the repo checkout so it can call scripts/build-trojan-core.sh.
INSTALL_DIR="/usr/local/trojan"
CONFIG_DIR="/etc/trojan"
LOG_DIR="/var/log/trojan"
WEB_DIR="/var/www/html"
CADDY_CONFIG="/etc/caddy/Caddyfile"

DOMAIN=""
EMAIL=""
PASSWORD=""
REMOTE_PORT=8080
CLIENT_CONFIG_DIR="/etc/trojan/clients"
ENABLE_OBFUSCATION=true
OBFUSCATION_PROFILE="aggressive"

# ==================== 工具函数 ====================
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║          Trojan + Caddy 一键部署脚本 v1.0                    ║"
    echo "║                                                              ║"
    echo "║  支持系统: Debian/Ubuntu, CentOS/RHEL, Alpine, Arch         ║"
    echo "║  推荐方案: Caddy (自动HTTPS) + Trojan (代理服务)            ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local answer
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -r -p "$prompt" answer
    answer=${answer:-$default}
    
    [[ "$answer" =~ ^[Yy]$ ]]
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# ==================== 系统检测 ====================
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$PRETTY_NAME
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
        OS_VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release 2>/dev/null || echo "unknown")
        OS_NAME=$(cat /etc/redhat-release)
    elif [[ -f /etc/alpine-release ]]; then
        OS="alpine"
        OS_VERSION=$(cat /etc/alpine-release)
        OS_NAME="Alpine Linux $OS_VERSION"
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi
    
    log_info "检测到系统: $OS_NAME"
}

detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l|armhf)
            ARCH="armv7"
            ;;
        *)
            log_warn "未知架构: $ARCH，将尝试继续安装"
            ;;
    esac
    log_info "系统架构: $ARCH"
}

check_network() {
    log_step "检查网络连接..."
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null && ! ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
        log_error "网络连接失败，请检查网络设置"
        exit 1
    fi
    log_info "网络连接正常"
}

# ==================== 包管理器封装 ====================
pkg_update() {
    log_step "更新软件包列表..."
    case $OS in
        debian|ubuntu|linuxmint|pop)
            apt-get update -qq
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf &>/dev/null; then
                dnf check-update -q || true
            else
                yum check-update -q || true
            fi
            ;;
        alpine)
            apk update -q
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm &>/dev/null
            ;;
    esac
}

pkg_install() {
    local packages="$@"
    log_info "安装软件包: $packages"
    
    case $OS in
        debian|ubuntu|linuxmint|pop)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $packages
            ;;
        centos|rhel|rocky|almalinux)
            if command -v dnf &>/dev/null; then
                dnf install -y -q $packages
            else
                yum install -y -q $packages
            fi
            ;;
        fedora)
            dnf install -y -q $packages
            ;;
        alpine)
            apk add -q $packages
            ;;
        arch|manjaro)
            pacman -S --noconfirm --needed $packages &>/dev/null
            ;;
        *)
            log_error "不支持的包管理器"
            exit 1
            ;;
    esac
}

# ==================== 依赖安装 ====================
install_dependencies() {
    log_step "安装编译依赖..."
    
    case $OS in
        debian|ubuntu|linuxmint|pop)
            pkg_install build-essential cmake libboost-system-dev libboost-program-options-dev \
                        libssl-dev default-libmysqlclient-dev git curl wget
            ;;
        centos|rhel|rocky|almalinux)
            # 启用 EPEL
            pkg_install epel-release || true
            pkg_install gcc gcc-c++ make cmake boost-devel openssl-devel \
                        mariadb-devel git curl wget
            ;;
        fedora)
            pkg_install gcc gcc-c++ make cmake boost-devel openssl-devel \
                        mariadb-devel git curl wget
            ;;
        alpine)
            pkg_install build-base cmake boost-dev openssl-dev mariadb-dev \
                        git curl wget linux-headers
            ;;
        arch|manjaro)
            pkg_install base-devel cmake boost openssl mariadb-libs git curl wget
            ;;
    esac
    
    log_info "依赖安装完成"
}


# ==================== Trojan 编译安装 ====================
install_trojan_from_source() {
    log_step "编译并安装 trojan-pro..."

    # We expect deploy.sh to be executed from within this repo checkout.
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root
    project_root="$(cd "$script_dir/.." && pwd)"

    local build_script="$project_root/scripts/build-trojan-core.sh"
    if [[ ! -x "$build_script" ]]; then
        log_error "未找到构建脚本: $build_script"
        log_error "请在 trojan-pro 仓库中运行本脚本，例如:"
        log_error "  sudo ./scripts/deploy.sh"
        exit 1
    fi

    # Build trojan core into dist/
    (
        cd "$project_root"
        "$build_script" --build-type Release
    )

    local bin_src="$project_root/dist/trojan"
    if [[ ! -f "$bin_src" ]]; then
        log_error "编译成功但未找到产物: $bin_src"
        exit 1
    fi

    log_info "安装 trojan 到 /usr/local/bin/trojan"
    install -m 0755 "$bin_src" /usr/local/bin/trojan

    # 创建配置/日志目录
    mkdir -p "$CONFIG_DIR" "$LOG_DIR"

    # 验证安装
    if command -v /usr/local/bin/trojan &>/dev/null; then
        log_info "trojan-pro 安装成功: $(/usr/local/bin/trojan --version 2>&1 | head -1 || echo 'installed')"
    else
        log_error "trojan-pro 安装失败"
        exit 1
    fi
}

# ==================== Caddy 安装 ====================
install_caddy() {
    log_step "安装 Caddy Web 服务器..."
    
    case $OS in
        debian|ubuntu|linuxmint|pop)
            pkg_install debian-keyring debian-archive-keyring apt-transport-https curl
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
                gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null || true
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
                tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
            apt-get update -qq
            pkg_install caddy
            ;;
        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf &>/dev/null; then
                dnf install -y 'dnf-command(copr)' || true
                dnf copr enable -y @caddy/caddy || true
                dnf install -y caddy
            else
                yum install -y yum-plugin-copr || true
                yum copr enable -y @caddy/caddy || true
                yum install -y caddy
            fi
            ;;
        alpine)
            pkg_install caddy
            ;;
        arch|manjaro)
            pkg_install caddy
            ;;
        *)
            # 通用安装方式
            log_info "使用官方脚本安装 Caddy..."
            curl -sS https://webi.sh/caddy | sh
            ;;
    esac
    
    # 验证安装
    if command -v caddy &>/dev/null; then
        log_info "Caddy 安装成功: $(caddy version 2>&1 | head -1)"
    else
        log_error "Caddy 安装失败"
        exit 1
    fi
}

# ==================== 配置生成 ====================
generate_password() {
    # 生成安全的随机密码
    local length=${1:-32}
    if command -v openssl &>/dev/null; then
        openssl rand -base64 $length | tr -dc 'a-zA-Z0-9' | head -c $length
    else
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c $length
    fi
}

configure_trojan() {
    log_step "配置 Trojan..."
    
    local cert_path="/etc/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${DOMAIN}/${DOMAIN}.crt"
    local key_path="/etc/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${DOMAIN}/${DOMAIN}.key"
    
    # 如果使用 Caddy 自动证书，先用占位符
    if [[ ! -f "$cert_path" ]]; then
        cert_path="/etc/trojan/server.crt"
        key_path="/etc/trojan/server.key"
    fi
    
    cat > "$CONFIG_DIR/config.json" << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": ${REMOTE_PORT},
    "password": [
        "${PASSWORD}"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "${cert_path}",
        "key": "${key_path}",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": "",
        "key": "",
        "cert": "",
        "ca": ""
    }
}
EOF
    
    chmod 600 "$CONFIG_DIR/config.json"
    log_info "Trojan 配置已生成: $CONFIG_DIR/config.json"
}

configure_caddy() {
    log_step "配置 Caddy..."
    
    mkdir -p /etc/caddy
    mkdir -p "$WEB_DIR"
    mkdir -p /var/log/caddy
    
    # 创建伪装网站
    cat > "$WEB_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
               display: flex; justify-content: center; align-items: center; 
               min-height: 100vh; margin: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .container { text-align: center; color: white; padding: 2rem; }
        h1 { font-size: 3rem; margin-bottom: 1rem; }
        p { font-size: 1.2rem; opacity: 0.9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome</h1>
        <p>This server is running normally.</p>
    </div>
</body>
</html>
EOF

    # Caddy 配置 - 作为伪装后端
    cat > "$CADDY_CONFIG" << EOF
# Caddy 作为 Trojan 的伪装后端
# 当非 Trojan 流量到达时，显示正常网站

:${REMOTE_PORT} {
    root * ${WEB_DIR}
    file_server
    
    log {
        output file /var/log/caddy/access.log {
            roll_size 10mb
            roll_keep 5
        }
    }
    
    # 安全头
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
    }
}
EOF

    log_info "Caddy 配置已生成: $CADDY_CONFIG"
}

# ==================== 客户端配置生成 ====================
generate_client_configs() {
    log_step "生成客户端配置文件..."
    
    mkdir -p "$CLIENT_CONFIG_DIR"
    
    # 1. 基础客户端配置 (无混淆)
    generate_basic_client_config
    
    # 2. 带混淆的客户端配置
    generate_obfuscation_client_config
    
    # 3. Clash 配置
    generate_clash_config
    
    # 4. 生成配置信息卡片
    generate_config_card
    
    log_info "客户端配置已生成到: $CLIENT_CONFIG_DIR"
}

generate_basic_client_config() {
    cat > "$CLIENT_CONFIG_DIR/client-basic.json" << EOF
{
    "_comment": "基础客户端配置 - 适用于标准 Trojan 客户端",
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "${DOMAIN}",
    "remote_port": 443,
    "password": [
        "${PASSWORD}"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "",
        "cipher": "",
        "cipher_tls13": "",
        "sni": "${DOMAIN}",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": true,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF
    log_info "基础配置: $CLIENT_CONFIG_DIR/client-basic.json"
}

generate_obfuscation_client_config() {
    cat > "$CLIENT_CONFIG_DIR/client-obfuscation.json" << EOF
{
    "_comment": "高级混淆客户端配置 - 需要使用支持混淆模块的 Trojan 客户端",
    "_note": "此配置包含 TLS 指纹伪装和握手混淆功能",
    
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "${DOMAIN}",
    "remote_port": 443,
    "password": [
        "${PASSWORD}"
    ],
    "log_level": 1,
    
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "",
        "cipher": "",
        "cipher_tls13": "",
        "sni": "${DOMAIN}",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": true,
        "curves": ""
    },
    
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    
    "obfuscation": {
        "enabled": true,
        
        "fingerprint": {
            "_comment": "TLS 指纹随机化 - 模拟真实浏览器",
            "_options": "chrome, firefox, safari, edge, random",
            "enabled": true,
            "type": "random",
            "grease": true
        },
        
        "handshake_mimicry": {
            "_comment": "握手数据混淆 - 从真实网站采集特征",
            "enabled": true,
            "cache_file": "~/.trojan/handshake.bin",
            "prefetch": true,
            "prefetch_domains": [
                "www.google.com",
                "www.cloudflare.com",
                "www.microsoft.com",
                "www.apple.com"
            ]
        },
        
        "timing": {
            "_comment": "时序混淆配置",
            "_profiles": "aggressive(低延迟) / balanced(平衡) / stealth(高隐蔽)",
            "profile": "${OBFUSCATION_PROFILE}"
        },
        
        "padding": {
            "_comment": "协议填充 - 增加流量随机性",
            "enabled": false,
            "min_bytes": 0,
            "max_bytes": 64
        },
        
        "record_splitting": {
            "_comment": "TLS 记录分片",
            "enabled": false
        },
        
        "cache": {
            "_comment": "缓存配置 - 减少启动延迟",
            "enabled": true,
            "directory": "~/.trojan/cache"
        },
        
        "tls": {
            "_comment": "TLS 版本控制",
            "enforce_tls13": true,
            "min_version": "0x0304"
        }
    }
}
EOF
    log_info "混淆配置: $CLIENT_CONFIG_DIR/client-obfuscation.json"
}

generate_clash_config() {
    cat > "$CLIENT_CONFIG_DIR/clash-config.yaml" << EOF
# Clash 配置文件
# 适用于 Clash / ClashX / Clash for Windows / Clash for Android

mixed-port: 7890
allow-lan: false
mode: rule
log-level: info

proxies:
  - name: "${DOMAIN}"
    type: trojan
    server: ${DOMAIN}
    port: 443
    password: ${PASSWORD}
    sni: ${DOMAIN}
    skip-cert-verify: false
    udp: true

proxy-groups:
  - name: "Proxy"
    type: select
    proxies:
      - "${DOMAIN}"
      - DIRECT

rules:
  # 私有地址直连
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  
  # 国内域名直连 (可选)
  # - DOMAIN-SUFFIX,cn,DIRECT
  # - GEOIP,CN,DIRECT
  
  # 默认代理
  - MATCH,Proxy
EOF
    log_info "Clash 配置: $CLIENT_CONFIG_DIR/clash-config.yaml"
}

generate_config_card() {
    local server_ip=$(curl -s4 ifconfig.me 2>/dev/null || curl -s4 ip.sb 2>/dev/null || echo "YOUR_SERVER_IP")
    
    cat > "$CLIENT_CONFIG_DIR/README.txt" << EOF
╔══════════════════════════════════════════════════════════════════════╗
║                     Trojan 客户端连接信息                            ║
╚══════════════════════════════════════════════════════════════════════╝

=== 服务器信息 ===
  地址: ${DOMAIN}
  IP:   ${server_ip}
  端口: 443
  密码: ${PASSWORD}

=== 配置文件说明 ===

1. client-basic.json
   - 基础配置，适用于所有标准 Trojan 客户端
   - 无混淆功能

2. client-obfuscation.json  [推荐]
   - 包含高级混淆功能
   - 需要使用支持混淆模块的 Trojan 客户端
   - 功能: TLS 指纹伪装、握手混淆、时序混淆

3. clash-config.yaml
   - 适用于 Clash 系列客户端
   - ClashX (macOS)
   - Clash for Windows
   - Clash for Android

=== 混淆配置说明 ===

指纹类型 (fingerprint.type):
  - chrome   : 模拟 Chrome 浏览器
  - firefox  : 模拟 Firefox 浏览器
  - safari   : 模拟 Safari 浏览器
  - edge     : 模拟 Edge 浏览器
  - random   : 随机选择 (推荐)

时序配置 (timing.profile):
  - aggressive : 低延迟优先 (0-5ms)
  - balanced   : 平衡模式 (5-50ms)
  - stealth    : 高隐蔽性 (20-200ms)

=== 客户端下载 ===

Windows:
  - Trojan-Qt5: https://github.com/Trojan-Qt5/Trojan-Qt5/releases
  - Clash for Windows: https://github.com/Fndroid/clash_for_windows_pkg/releases

macOS:
  - ClashX: https://github.com/yichengchen/clashX/releases
  - Trojan-Qt5: https://github.com/Trojan-Qt5/Trojan-Qt5/releases

Linux:
  - 命令行: trojan client-basic.json
  - Clash: https://github.com/Dreamacro/clash/releases

iOS:
  - Shadowrocket (App Store, 付费)
  - Quantumult X (App Store, 付费)

Android:
  - Clash for Android: https://github.com/Kr328/ClashForAndroid/releases
  - v2rayNG: https://github.com/2dust/v2rayNG/releases

=== 使用方法 ===

1. 命令行 (Linux/macOS):
   trojan /path/to/client-obfuscation.json

2. 图形客户端:
   导入对应的配置文件即可

3. 浏览器代理设置:
   - 类型: SOCKS5
   - 地址: 127.0.0.1
   - 端口: 1080

=== 注意事项 ===

1. 混淆功能仅在客户端生效
2. 使用混淆配置需要编译支持混淆模块的 Trojan
3. 第三方客户端 (Clash/Shadowrocket) 不支持混淆功能
4. 建议定期更新客户端以获取最新指纹库

生成时间: $(date '+%Y-%m-%d %H:%M:%S')
EOF
    log_info "配置说明: $CLIENT_CONFIG_DIR/README.txt"
}

# ==================== 导出客户端配置 ====================
export_client_config() {
    log_step "导出客户端配置..."
    
    if [[ ! -d "$CLIENT_CONFIG_DIR" ]]; then
        log_error "客户端配置目录不存在，请先运行安装"
        return 1
    fi
    
    local export_dir="/tmp/trojan-client-$(date +%Y%m%d%H%M%S)"
    mkdir -p "$export_dir"
    
    cp -r "$CLIENT_CONFIG_DIR"/* "$export_dir/"
    
    # 创建压缩包
    local archive_name="trojan-client-config.tar.gz"
    tar -czf "/tmp/$archive_name" -C /tmp "$(basename $export_dir)"
    
    echo ""
    echo -e "${GREEN}客户端配置已导出:${NC}"
    echo -e "  目录: ${YELLOW}$export_dir${NC}"
    echo -e "  压缩包: ${YELLOW}/tmp/$archive_name${NC}"
    echo ""
    echo -e "下载命令 (在本地执行):"
    echo -e "  ${CYAN}scp root@${DOMAIN}:/tmp/$archive_name ./${NC}"
    echo ""
    
    rm -rf "$export_dir"
}

# ==================== 显示客户端配置 ====================
show_client_config() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    客户端配置信息                            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ -f "$CLIENT_CONFIG_DIR/README.txt" ]]; then
        cat "$CLIENT_CONFIG_DIR/README.txt"
    else
        echo -e "${CYAN}=== 基础连接信息 ===${NC}"
        echo -e "  服务器: ${YELLOW}${DOMAIN}${NC}"
        echo -e "  端口:   ${YELLOW}443${NC}"
        echo -e "  密码:   ${YELLOW}${PASSWORD}${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}=== 配置文件位置 ===${NC}"
    if [[ -d "$CLIENT_CONFIG_DIR" ]]; then
        ls -la "$CLIENT_CONFIG_DIR" 2>/dev/null | tail -n +2
    else
        echo -e "  ${RED}配置目录不存在${NC}"
    fi
    echo ""
}

# ==================== 混淆配置选项 ====================
configure_obfuscation_options() {
    echo ""
    echo -e "${CYAN}=== 混淆配置选项 ===${NC}"
    echo ""
    echo "  1) aggressive - 低延迟优先 (推荐日常使用)"
    echo "  2) balanced   - 平衡模式"
    echo "  3) stealth    - 高隐蔽性 (延迟较高)"
    echo ""
    
    local choice
    read -r -p "请选择混淆配置 [1-3] (默认: 1): " choice
    choice=${choice:-1}
    
    case $choice in
        1) OBFUSCATION_PROFILE="aggressive" ;;
        2) OBFUSCATION_PROFILE="balanced" ;;
        3) OBFUSCATION_PROFILE="stealth" ;;
        *) OBFUSCATION_PROFILE="aggressive" ;;
    esac
    
    log_info "混淆配置: $OBFUSCATION_PROFILE"
}

# ==================== SSL 证书 ====================
setup_ssl_certificate() {
    log_step "配置 SSL 证书..."
    
    local cert_dir="/etc/trojan"
    
    echo ""
    echo -e "${CYAN}SSL 证书配置选项:${NC}"
    echo "  1) 使用 acme.sh 自动申请 Let's Encrypt 证书 (推荐)"
    echo "  2) 使用自签名证书 (仅测试用)"
    echo "  3) 使用已有证书 (手动指定路径)"
    echo ""
    
    local ssl_choice
    read -r -p "请选择 [1-3] (默认: 1): " ssl_choice
    ssl_choice=${ssl_choice:-1}
    
    case $ssl_choice in
        1)
            setup_acme_certificate
            ;;
        2)
            setup_self_signed_certificate
            ;;
        3)
            setup_existing_certificate
            ;;
        *)
            log_warn "无效选择，使用自签名证书"
            setup_self_signed_certificate
            ;;
    esac
}

setup_acme_certificate() {
    log_info "使用 acme.sh 申请 Let's Encrypt 证书..."
    
    # 安装 acme.sh
    if [[ ! -f ~/.acme.sh/acme.sh ]]; then
        curl -sS https://get.acme.sh | sh -s email="$EMAIL"
        source ~/.bashrc 2>/dev/null || true
    fi
    
    local acme_sh=~/.acme.sh/acme.sh
    
    # 确保 80 端口可用
    if ss -tlnp | grep -q ':80 '; then
        log_warn "端口 80 被占用，尝试停止相关服务..."
        systemctl stop caddy 2>/dev/null || true
        systemctl stop nginx 2>/dev/null || true
        systemctl stop apache2 2>/dev/null || true
        systemctl stop httpd 2>/dev/null || true
    fi
    
    # 申请证书
    log_info "申请证书中，请确保域名 $DOMAIN 已解析到本服务器..."
    
    $acme_sh --issue -d "$DOMAIN" --standalone --keylength ec-256 || {
        log_error "证书申请失败，请检查:"
        log_error "  1. 域名是否正确解析到本服务器"
        log_error "  2. 端口 80 是否可访问"
        log_error "  3. 防火墙是否放行"
        return 1
    }
    
    # 安装证书
    mkdir -p /etc/trojan
    $acme_sh --install-cert -d "$DOMAIN" --ecc \
        --key-file /etc/trojan/server.key \
        --fullchain-file /etc/trojan/server.crt \
        --reloadcmd "systemctl reload trojan 2>/dev/null || true"
    
    chmod 600 /etc/trojan/server.key
    chmod 644 /etc/trojan/server.crt
    
    log_info "Let's Encrypt 证书申请成功"
}

setup_self_signed_certificate() {
    log_info "生成自签名证书..."
    
    mkdir -p /etc/trojan
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/trojan/server.key \
        -out /etc/trojan/server.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${DOMAIN:-localhost}"
    
    chmod 600 /etc/trojan/server.key
    chmod 644 /etc/trojan/server.crt
    
    log_warn "自签名证书已生成，仅建议用于测试环境"
}

setup_existing_certificate() {
    local cert_path key_path
    
    read -r -p "请输入证书文件路径 (fullchain.crt): " cert_path
    read -r -p "请输入私钥文件路径 (private.key): " key_path
    
    if [[ ! -f "$cert_path" ]] || [[ ! -f "$key_path" ]]; then
        log_error "证书文件不存在"
        return 1
    fi
    
    cp "$cert_path" /etc/trojan/server.crt
    cp "$key_path" /etc/trojan/server.key
    
    chmod 600 /etc/trojan/server.key
    chmod 644 /etc/trojan/server.crt
    
    log_info "证书已复制到 /etc/trojan/"
}

# ==================== Systemd 服务 ====================
setup_systemd_services() {
    log_step "配置 Systemd 服务..."
    
    # Trojan 服务
    cat > /etc/systemd/system/trojan.service << EOF
[Unit]
Description=Trojan Proxy Server
Documentation=https://trojan-gfw.github.io/trojan/
After=network.target network-online.target nss-lookup.target caddy.service
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/trojan ${CONFIG_DIR}/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=3s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_info "Systemd 服务配置完成"
}

# ==================== 防火墙配置 ====================
configure_firewall() {
    log_step "配置防火墙..."
    
    # 检测防火墙类型
    if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
        log_info "配置 UFW 防火墙..."
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw reload
    elif command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
        log_info "配置 firewalld 防火墙..."
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --reload
    elif command -v iptables &>/dev/null; then
        log_info "配置 iptables 防火墙..."
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT
        iptables -I INPUT -p tcp --dport 443 -j ACCEPT
        # 尝试保存规则
        if command -v iptables-save &>/dev/null; then
            iptables-save > /etc/iptables.rules 2>/dev/null || true
        fi
    else
        log_warn "未检测到活动的防火墙，跳过配置"
    fi
}

# ==================== 启动服务 ====================
start_services() {
    log_step "启动服务..."
    
    # 启动 Caddy
    systemctl enable caddy
    systemctl start caddy
    
    if systemctl is-active caddy &>/dev/null; then
        log_info "Caddy 启动成功"
    else
        log_error "Caddy 启动失败"
        journalctl -u caddy --no-pager -n 20
    fi
    
    # 启动 Trojan
    systemctl enable trojan
    systemctl start trojan
    
    sleep 2
    
    if systemctl is-active trojan &>/dev/null; then
        log_info "Trojan 启动成功"
    else
        log_error "Trojan 启动失败"
        journalctl -u trojan --no-pager -n 20
    fi
}


# ==================== 信息展示 ====================
show_connection_info() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    部署完成！                                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}=== 服务状态 ===${NC}"
    echo -e "  Trojan: $(systemctl is-active trojan 2>/dev/null || echo 'unknown')"
    echo -e "  Caddy:  $(systemctl is-active caddy 2>/dev/null || echo 'unknown')"
    echo ""
    echo -e "${CYAN}=== 连接信息 ===${NC}"
    echo -e "  服务器地址: ${YELLOW}${DOMAIN}${NC}"
    echo -e "  服务器端口: ${YELLOW}443${NC}"
    echo -e "  密码:       ${YELLOW}${PASSWORD}${NC}"
    echo ""
    echo -e "${CYAN}=== 客户端配置文件 ===${NC}"
    echo -e "  基础配置:   ${YELLOW}${CLIENT_CONFIG_DIR}/client-basic.json${NC}"
    echo -e "  混淆配置:   ${YELLOW}${CLIENT_CONFIG_DIR}/client-obfuscation.json${NC} (推荐)"
    echo -e "  Clash配置:  ${YELLOW}${CLIENT_CONFIG_DIR}/clash-config.yaml${NC}"
    echo -e "  配置说明:   ${YELLOW}${CLIENT_CONFIG_DIR}/README.txt${NC}"
    echo ""
    echo -e "${CYAN}=== 下载客户端配置 ===${NC}"
    echo -e "  ${YELLOW}scp -r root@${DOMAIN}:${CLIENT_CONFIG_DIR} ./trojan-client/${NC}"
    echo ""
    echo -e "${CYAN}=== 服务端配置文件 ===${NC}"
    echo -e "  Trojan 配置: ${CONFIG_DIR}/config.json"
    echo -e "  Caddy 配置:  ${CADDY_CONFIG}"
    echo -e "  SSL 证书:    /etc/trojan/server.crt"
    echo -e "  SSL 私钥:    /etc/trojan/server.key"
    echo ""
    echo -e "${CYAN}=== 常用命令 ===${NC}"
    echo -e "  查看 Trojan 状态: ${YELLOW}systemctl status trojan${NC}"
    echo -e "  查看 Trojan 日志: ${YELLOW}journalctl -u trojan -f${NC}"
    echo -e "  重启 Trojan:      ${YELLOW}systemctl restart trojan${NC}"
    echo -e "  导出客户端配置:   ${YELLOW}$0 --export${NC}"
    echo ""
}

# ==================== 卸载功能 ====================
uninstall_all() {
    log_warn "即将卸载 Trojan 和 Caddy..."
    
    if ! confirm "确定要卸载吗？" "n"; then
        log_info "取消卸载"
        return
    fi
    
    log_step "停止服务..."
    systemctl stop trojan 2>/dev/null || true
    systemctl stop caddy 2>/dev/null || true
    systemctl disable trojan 2>/dev/null || true
    systemctl disable caddy 2>/dev/null || true
    
    log_step "删除文件..."
    rm -f /etc/systemd/system/trojan.service
    rm -rf /etc/trojan
    rm -rf /var/log/trojan
    rm -f /usr/local/bin/trojan
    
    # 可选：卸载 Caddy
    if confirm "是否同时卸载 Caddy？" "n"; then
        case $OS in
            debian|ubuntu|linuxmint|pop)
                apt-get remove -y caddy
                ;;
            centos|rhel|rocky|almalinux|fedora)
                dnf remove -y caddy 2>/dev/null || yum remove -y caddy
                ;;
            alpine)
                apk del caddy
                ;;
            arch|manjaro)
                pacman -R --noconfirm caddy
                ;;
        esac
    fi
    
    systemctl daemon-reload
    
    log_info "卸载完成"
}

# ==================== 状态检查 ====================
check_status() {
    echo ""
    echo -e "${CYAN}=== 服务状态检查 ===${NC}"
    echo ""
    
    echo -e "${BLUE}[Trojan]${NC}"
    if systemctl is-active trojan &>/dev/null; then
        echo -e "  状态: ${GREEN}运行中${NC}"
        echo -e "  PID:  $(systemctl show trojan -p MainPID --value)"
    else
        echo -e "  状态: ${RED}未运行${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}[Caddy]${NC}"
    if systemctl is-active caddy &>/dev/null; then
        echo -e "  状态: ${GREEN}运行中${NC}"
        echo -e "  PID:  $(systemctl show caddy -p MainPID --value)"
    else
        echo -e "  状态: ${RED}未运行${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}[端口监听]${NC}"
    ss -tlnp | grep -E ':443|:80|:8080' | while read line; do
        echo "  $line"
    done
    
    echo ""
    echo -e "${BLUE}[证书信息]${NC}"
    if [[ -f /etc/trojan/server.crt ]]; then
        local expiry=$(openssl x509 -in /etc/trojan/server.crt -noout -enddate 2>/dev/null | cut -d= -f2)
        echo -e "  证书到期: $expiry"
    else
        echo -e "  ${RED}证书文件不存在${NC}"
    fi
    
    echo ""
}

# ==================== 用户输入收集 ====================
collect_user_input() {
    echo ""
    echo -e "${CYAN}=== 配置信息 ===${NC}"
    echo ""
    
    # 域名
    while [[ -z "$DOMAIN" ]]; do
        read -r -p "请输入您的域名 (例: example.com): " DOMAIN
        if [[ -z "$DOMAIN" ]]; then
            log_warn "域名不能为空"
        fi
    done
    
    # 邮箱 (用于 Let's Encrypt)
    read -r -p "请输入邮箱 (用于SSL证书通知, 可选): " EMAIL
    EMAIL=${EMAIL:-"admin@${DOMAIN}"}
    
    # 密码
    read -r -p "请输入连接密码 (留空自动生成): " PASSWORD
    if [[ -z "$PASSWORD" ]]; then
        PASSWORD=$(generate_password 24)
        log_info "已自动生成密码: $PASSWORD"
    fi
    
    # 伪装端口
    read -r -p "请输入伪装后端端口 (默认: 8080): " REMOTE_PORT
    REMOTE_PORT=${REMOTE_PORT:-8080}
    
    echo ""
    echo -e "${CYAN}=== 配置确认 ===${NC}"
    echo -e "  域名:     ${YELLOW}${DOMAIN}${NC}"
    echo -e "  邮箱:     ${YELLOW}${EMAIL}${NC}"
    echo -e "  密码:     ${YELLOW}${PASSWORD}${NC}"
    echo -e "  伪装端口: ${YELLOW}${REMOTE_PORT}${NC}"
    echo ""
    
    if ! confirm "确认以上配置？"; then
        log_info "请重新运行脚本"
        exit 0
    fi
}

# ==================== 主菜单 ====================
show_menu() {
    print_banner
    
    echo -e "${CYAN}请选择操作:${NC}"
    echo ""
    echo "  1) 一键安装 Trojan + Caddy (推荐)"
    echo "  2) 仅安装 Trojan"
    echo "  3) 仅安装 Caddy"
    echo "  4) 查看服务状态"
    echo "  5) 查看/导出客户端配置"
    echo "  6) 重新配置"
    echo "  7) 卸载"
    echo "  0) 退出"
    echo ""
    
    local choice
    read -r -p "请输入选项 [0-7]: " choice
    
    case $choice in
        1)
            full_install
            ;;
        2)
            install_trojan_only
            ;;
        3)
            install_caddy_only
            ;;
        4)
            check_status
            ;;
        5)
            client_config_menu
            ;;
        6)
            reconfigure
            ;;
        7)
            uninstall_all
            ;;
        0)
            log_info "再见！"
            exit 0
            ;;
        *)
            log_warn "无效选项"
            show_menu
            ;;
    esac
}

# ==================== 客户端配置菜单 ====================
client_config_menu() {
    echo ""
    echo -e "${CYAN}=== 客户端配置管理 ===${NC}"
    echo ""
    echo "  1) 查看客户端配置"
    echo "  2) 导出配置压缩包"
    echo "  3) 重新生成配置"
    echo "  4) 返回主菜单"
    echo ""
    
    local choice
    read -r -p "请选择 [1-4]: " choice
    
    case $choice in
        1)
            show_client_config
            ;;
        2)
            export_client_config
            ;;
        3)
            regenerate_client_config
            ;;
        4)
            show_menu
            return
            ;;
        *)
            log_warn "无效选项"
            ;;
    esac
    
    echo ""
    read -r -p "按回车键继续..."
    client_config_menu
}

regenerate_client_config() {
    # 读取现有配置
    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        DOMAIN=$(grep -oP '"remote_addr":\s*"\K[^"]+' "$CONFIG_DIR/config.json" 2>/dev/null || echo "")
        PASSWORD=$(grep -oP '"password":\s*\[\s*"\K[^"]+' "$CONFIG_DIR/config.json" 2>/dev/null || echo "")
    fi
    
    if [[ -z "$DOMAIN" ]] || [[ -z "$PASSWORD" ]]; then
        log_warn "无法读取现有配置，请手动输入"
        read -r -p "请输入域名: " DOMAIN
        read -r -p "请输入密码: " PASSWORD
    fi
    
    configure_obfuscation_options
    generate_client_configs
    log_info "客户端配置已重新生成"
}

# ==================== 安装流程 ====================
full_install() {
    log_step "开始完整安装..."
    
    check_network
    detect_os
    detect_arch
    
    collect_user_input
    configure_obfuscation_options
    
    pkg_update
    install_dependencies
    install_trojan_from_source
    install_caddy
    
    configure_trojan
    configure_caddy
    setup_ssl_certificate
    
    # Trojan 配置中的证书路径在 setup_ssl_certificate() 会落到 /etc/trojan/ 下，
    # configure_trojan() 也已使用该路径作为默认值，这里无需再做替换。
    
    setup_systemd_services
    configure_firewall
    
    # 生成客户端配置
    generate_client_configs
    
    start_services
    
    show_connection_info
}

install_trojan_only() {
    log_step "仅安装 Trojan..."
    
    check_network
    detect_os
    detect_arch
    
    collect_user_input
    configure_obfuscation_options
    
    pkg_update
    install_dependencies
    install_trojan_from_source
    
    configure_trojan
    setup_ssl_certificate
    setup_systemd_services
    configure_firewall
    
    # 生成客户端配置
    generate_client_configs
    
    systemctl enable trojan
    systemctl start trojan
    
    show_connection_info
}

install_caddy_only() {
    log_step "仅安装 Caddy..."
    
    detect_os
    pkg_update
    install_caddy
    
    read -r -p "请输入 Caddy 监听端口 (默认: 8080): " REMOTE_PORT
    REMOTE_PORT=${REMOTE_PORT:-8080}
    
    configure_caddy
    
    systemctl enable caddy
    systemctl start caddy
    
    log_info "Caddy 安装完成"
}

reconfigure() {
    log_step "重新配置..."
    
    collect_user_input
    configure_obfuscation_options
    configure_trojan
    configure_caddy
    generate_client_configs
    
    systemctl restart trojan 2>/dev/null || true
    systemctl restart caddy 2>/dev/null || true
    
    show_connection_info
}

# ==================== 入口点 ====================
main() {
    check_root
    detect_os
    
    # 支持命令行参数
    case "${1:-}" in
        --install|-i)
            full_install
            ;;
        --uninstall|-u)
            uninstall_all
            ;;
        --status|-s)
            check_status
            ;;
        --export|-e)
            export_client_config
            ;;
        --client|-c)
            show_client_config
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --install, -i    一键安装"
            echo "  --uninstall, -u  卸载"
            echo "  --status, -s     查看状态"
            echo "  --export, -e     导出客户端配置"
            echo "  --client, -c     查看客户端配置"
            echo "  --help, -h       显示帮助"
            echo ""
            echo "无参数运行将显示交互式菜单"
            ;;
        *)
            show_menu
            ;;
    esac
}

main "$@"
