#!/bin/bash
#
# Trojan + Caddy Deployment Script (Bilingual: English/Chinese)
# Trojan + Caddy 一键部署脚本 (双语：中/英)
#
# Supported Platforms:
# - Debian / Ubuntu / Linux Mint / Kali
# - CentOS / RHEL / Fedora / Alma / Rocky
# - Arch Linux / Manjaro
# - OpenSUSE
# - Alpine Linux
#

set -e

# ==================== Global Configuration ====================
INSTALL_DIR="/usr/local/trojan"
CONFIG_DIR="/etc/trojan"
LOG_DIR="/var/log/trojan"
WEB_DIR="/var/www/html"
REPO_URL="https://github.com/proxy-trojan/trojan-obfuscation"
REPO_BRANCH="feature_1.0_no_obfus_and_no_rules"


# Colors & Formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ==================== Language Strings / 语言字符串 ====================
setup_languages() {
    # Default to English
    LANG_CUR="en"
    
    # EN Dictionary
    MSG_en_BANNER_TITLE="Trojan + Caddy Deployment Script"
    MSG_en_BANNER_SUB="Secure, Fast, and Stealthy Proxy Solution"
    MSG_en_ROOT_REQUIRED="Error: This script must be run as root."
    MSG_en_OS_DETECTED="Detected OS:"
    MSG_en_NET_CHECK="Checking network connection..."
    MSG_en_NET_FAIL="Network check failed. Please check your connection."
    MSG_en_PKG_UPDATE="Updating package lists..."
    MSG_en_INSTALL_DEPS="Installing dependencies..."
    MSG_en_INSTALL_TROJAN="Compiling and installing Trojan..."
    MSG_en_INSTALL_CADDY="Installing Caddy web server..."
    MSG_en_ENTER_DOMAIN="Please enter your domain (e.g., example.com):"
    MSG_en_ENTER_EMAIL="Please enter your email (for SSL alerts, optional):"
    MSG_en_ENTER_PWD="Please enter connection password (leave empty to generate):"
    MSG_en_DOMAIN_EMPTY="Domain cannot be empty."
    MSG_en_CONFIRM_CFG="Please confirm configuration:"
    MSG_en_DOMAIN="Domain:"
    MSG_en_EMAIL="Email:"
    MSG_en_PWD="Password:"
    MSG_en_YES="y"
    MSG_en_NO="n"
    MSG_en_CONFIRM_PROMPT="Is this correct?"
    MSG_en_INSTALL_START="Starting installation... This may take a while."
    MSG_en_SSL_SETUP="Setting up SSL certificate..."
    MSG_en_SSL_ACME="Using acme.sh to obtain Let's Encrypt certificate..."
    MSG_en_SSL_FAIL="SSL Certificate failed. Check domain resolution."
    MSG_en_CONFIG_GEN="Generating configurations..."
    MSG_en_SERVICE_START="Starting services..."
    MSG_en_SUCCESS_TITLE="Deployment Successful!"
    MSG_en_CONN_INFO="Connection Information:"
    MSG_en_CLIENT_CFG="Client Config:"
    MSG_en_NON_COMPLIANT="Non-compliant traffic (Web) will return: 503 Service Overload"
    MSG_en_SERVICE_MGR="Service Manager:"
    MSG_en_PKG_MGR="Package Manager:"
    MSG_en_INSTALL_MODE_PROMPT="Select installation mode:"
    MSG_en_MODE_HOST="1) Host (Native Install)"
    MSG_en_MODE_DOCKER="2) Docker (Containerized)"
    MSG_en_DOCKER_INSTALL="Installing Docker and Docker Compose..."
    MSG_en_DOCKER_COMPOSE_GEN="Generating docker-compose.yml..."
    MSG_en_DOCKER_START="Starting Docker containers..."
    MSG_en_DOCKER_SUCCESS="Docker deployment successful!"
    MSG_en_PRESS_ENTER="Press Enter to continue..."
    MSG_en_MENU_INSTALL="Install / Reinstall"
    MSG_en_MENU_STATUS="Check Status"
    MSG_en_MENU_CONFIG="View Config"
    MSG_en_MENU_LOGS="View Logs"
    MSG_en_MENU_RENEW="Renew Certificate"
    MSG_en_MENU_UNINSTALL="Uninstall"
    MSG_en_MENU_EXIT="Exit"
    MSG_en_STATUS_RUNNING="Running"
    MSG_en_STATUS_STOPPED="Stopped"
    MSG_en_STATUS_UNKNOWN="Unknown"
    MSG_en_UNINSTALL_CONFIRM="Are you sure you want to uninstall? This will delete config and data."
    MSG_en_UNINSTALL_DONE="Uninstallation complete."
    MSG_en_PORT_OCCUPIED="Error: Port %s is occupied by %s. Please release it first."
    MSG_en_CERT_RENEW_START="Starting certificate renewal..."
    MSG_en_CERT_RENEW_SUCCESS="Certificate renewed successfully!"
    
    # CN Dictionary

    MSG_cn_BANNER_TITLE="Trojan + Caddy 一键部署脚本"
    MSG_cn_BANNER_SUB="安全、高速、隐蔽的代理解决方案"
    MSG_cn_ROOT_REQUIRED="错误：此脚本需要 root 权限运行。"
    MSG_cn_OS_DETECTED="检测到系统："
    MSG_cn_NET_CHECK="正在检查网络连接..."
    MSG_cn_NET_FAIL="网络连接失败，请检查网络设置。"
    MSG_cn_PKG_UPDATE="正在更新软件包列表..."
    MSG_cn_INSTALL_DEPS="正在安装依赖..."
    MSG_cn_INSTALL_TROJAN="正在编译安装 Trojan..."
    MSG_cn_INSTALL_CADDY="正在安装 Caddy Web 服务器..."
    MSG_cn_ENTER_DOMAIN="请输入您的域名 (例如: example.com):"
    MSG_cn_ENTER_EMAIL="请输入您的邮箱 (用于SSL提醒，可选):"
    MSG_cn_ENTER_PWD="请输入连接密码 (留空自动生成):"
    MSG_cn_DOMAIN_EMPTY="域名不能为空。"
    MSG_cn_CONFIRM_CFG="请确认以下配置："
    MSG_cn_DOMAIN="域名："
    MSG_cn_EMAIL="邮箱："
    MSG_cn_PWD="密码："
    MSG_cn_YES="y"
    MSG_cn_NO="n"
    MSG_cn_CONFIRM_PROMPT="确认正确吗？"
    MSG_cn_INSTALL_START="开始安装... 这可能需要一些时间。"
    MSG_cn_SSL_SETUP="正在配置 SSL 证书..."
    MSG_cn_SSL_ACME="使用 acme.sh 申请 Let's Encrypt 证书..."
    MSG_cn_SSL_FAIL="SSL 证书申请失败，请检查域名解析。"
    MSG_cn_CONFIG_GEN="正在生成配置文件..."
    MSG_cn_SERVICE_START="正在启动服务..."
    MSG_cn_SUCCESS_TITLE="部署成功！"
    MSG_cn_CONN_INFO="连接信息："
    MSG_cn_CLIENT_CFG="客户端配置："
    MSG_cn_NON_COMPLIANT="不符合的流量 (Web) 将提示：503 Service Overload (服务过载)"
    MSG_cn_SERVICE_MGR="服务管理器："
    MSG_cn_PKG_MGR="包管理器："
    MSG_cn_INSTALL_MODE_PROMPT="请选择安装模式："
    MSG_cn_MODE_HOST="1) 主机模式 (本机直接安装)"
    MSG_cn_MODE_DOCKER="2) Docker 模式 (容器化部署)"
    MSG_cn_DOCKER_INSTALL="正在安装 Docker 和 Docker Compose..."
    MSG_cn_DOCKER_COMPOSE_GEN="正在生成 docker-compose.yml..."
    MSG_cn_DOCKER_START="正在启动 Docker 容器..."
    MSG_cn_DOCKER_SUCCESS="Docker 部署成功！"
    MSG_cn_PRESS_ENTER="按回车键继续..."
    MSG_cn_MENU_INSTALL="安装 / 重装"
    MSG_cn_MENU_STATUS="服务状态检查"
    MSG_cn_MENU_CONFIG="查看配置信息"
    MSG_cn_MENU_LOGS="查看运行日志"
    MSG_cn_MENU_RENEW="手动续期证书"
    MSG_cn_MENU_UNINSTALL="卸载服务"
    MSG_cn_MENU_EXIT="退出脚本"
    MSG_cn_STATUS_RUNNING="运行中"
    MSG_cn_STATUS_STOPPED="已停止"
    MSG_cn_STATUS_UNKNOWN="未知"
    MSG_cn_UNINSTALL_CONFIRM="确定要卸载吗？这将删除所有配置和数据。"
    MSG_cn_UNINSTALL_DONE="卸载完成。"
    MSG_cn_PORT_OCCUPIED="错误：端口 %s 被程序 %s 占用。请先释放端口。"
    MSG_cn_CERT_RENEW_START="开始续期证书..."
    MSG_cn_CERT_RENEW_SUCCESS="证书续期成功！"
}

# Helper to get string
t() {
    local key="MSG_${LANG_CUR}_$1"
    eval echo \$$key
}

# ==================== Global Helper Functions ====================
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Spinner function for long running tasks
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║          Trojan + Caddy Deployment Script v2.1               ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "$(t ROOT_REQUIRED)"
        exit 1
    fi
}

check_port() {
    local port=$1
    if command -v lsof &>/dev/null; then
        if lsof -i :$port >/dev/null; then
            local pid=$(lsof -t -i :$port)
            local name=$(ps -p $pid -o comm=)
            log_error "$(printf "$(t PORT_OCCUPIED)" "$port" "$name")"
            return 1
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            log_error "$(printf "$(t PORT_OCCUPIED)" "$port" "Unknown")"
            return 1
        fi
    elif command -v ss &>/dev/null; then
        if ss -tuln | grep -q ":$port "; then
            log_error "$(printf "$(t PORT_OCCUPIED)" "$port" "Unknown")"
            return 1
        fi
    fi
    return 0
}

pause() {
    echo ""
    read -r -p "$(t PRESS_ENTER)"
}

# ==================== Language Selection ====================
select_language() {
    if [[ -n "$LANG_CUR_SET" ]]; then return; fi
    clear
    echo "========================================================"
    echo " Please select your language / 请选择语言 "
    echo "========================================================"
    echo " 1) English"
    echo " 2) 简体中文 (Chinese)"
    echo ""
    read -r -p "Select [1-2] (Default: 2): " lang_choice
    lang_choice=${lang_choice:-2}
    
    case $lang_choice in
        1) LANG_CUR="en" ;;
        2) LANG_CUR="cn" ;;
        *) LANG_CUR="cn" ;;
    esac
    export LANG_CUR
    export LANG_CUR_SET=1
}

# ==================== Platform Abstract Layer ====================
detect_os() {
    OS_TYPE="unknown"
    PM="unknown" # Package Manager
    SM="unknown" # Service Manager

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_TYPE=$ID
        VERSION_ID=${VERSION_ID:-""}
    elif [[ -f /etc/redhat-release ]]; then
        OS_TYPE="rhel"
    elif [[ -f /etc/alpine-release ]]; then
        OS_TYPE="alpine"
    fi

    # Detect Package Manager
    if command -v apt-get &>/dev/null; then
        PM="apt"
    elif command -v dnf &>/dev/null; then
        PM="dnf"
    elif command -v yum &>/dev/null; then
        PM="yum"
    elif command -v pacman &>/dev/null; then
        PM="pacman"
    elif command -v zypper &>/dev/null; then
        PM="zypper"
    elif command -v apk &>/dev/null; then
        PM="apk"
    fi

    # Detect Service Manager
    if command -v systemctl &>/dev/null && systemd-notify --booted &>/dev/null; then
        SM="systemd"
    elif [[ -f /sbin/openrc-run ]] || [[ -f /etc/init.d/functions.sh ]]; then
        SM="openrc"
    elif [[ -f /etc/init.d/rcS ]]; then
        SM="sysvinit"
    else
        # Fallback detection
        case $OS_TYPE in
            alpine) SM="openrc" ;;
            *) SM="systemd" ;; # Assume systemd for most modern linux
        esac
    fi
}

# Wrapper for package installation
pkg_update() {
    log_info "$(t PKG_UPDATE)"
    case $PM in
        apt) apt-get update -qq ;;
        dnf) dnf check-update -q || true ;;
        yum) yum check-update -q || true ;;
        pacman) pacman -Sy --noconfirm &>/dev/null ;;
        zypper) zypper refresh -q ;;
        apk) apk update -q ;;
    esac
}

pkg_install() {
    local packages="$@"
    case $PM in
        apt) DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $packages ;;
        dnf) dnf install -y -q $packages ;;
        yum) yum install -y -q $packages ;;
        pacman) pacman -S --noconfirm --needed $packages &>/dev/null ;;
        zypper) zypper install -y -q $packages ;;
        apk) apk add -q $packages ;;
        *) log_error "Package manager not supported"; exit 1 ;;
    esac
}

# Service Management Wrappers
svc_start() {
    local service=$1
    case $SM in
        systemd) systemctl start $service ;;
        openrc) rc-service $service start ;;
        sysvinit) service $service start ;;
    esac
}

svc_enable() {
    local service=$1
    case $SM in
        systemd) systemctl enable $service ;;
        openrc) rc-update add $service default ;;
        sysvinit) update-rc.d $service defaults ;;
    esac
}

svc_restart() {
    local service=$1
    case $SM in
        systemd) systemctl restart $service ;;
        openrc) rc-service $service restart ;;
        sysvinit) service $service restart ;;
    esac
}

svc_stop() {
    local service=$1
    case $SM in
        systemd) systemctl stop $service 2>/dev/null || true ;;
        openrc) rc-service $service stop 2>/dev/null || true ;;
        sysvinit) service $service stop 2>/dev/null || true ;;
    esac
}

svc_status() {
    local service=$1
    local output=""
    local status_code=0
    
    case $SM in
        systemd) 
            systemctl is-active $service >/dev/null 2>&1 
            status_code=$?
            ;;
        openrc) 
            rc-service $service status >/dev/null 2>&1
            status_code=$?
            ;;
        *)
            pgrep -f "$service" >/dev/null 2>&1
            status_code=$?
            ;;
    esac
    
    if [[ $status_code -eq 0 ]]; then
        echo -e "${GREEN}$(t STATUS_RUNNING)${NC}"
    else
        echo -e "${RED}$(t STATUS_STOPPED)${NC}"
    fi
}

# ==================== Dependencies ====================
install_dependencies() {
    log_info "$(t INSTALL_DEPS)"
    pkg_update
    
    case $PM in
        apt)
            pkg_install build-essential cmake libboost-system-dev libboost-program-options-dev \
                        libssl-dev default-libmysqlclient-dev git curl wget socat lsof
            ;;
        dnf|yum)
            pkg_install epel-release || true
            pkg_install gcc gcc-c++ make cmake boost-devel openssl-devel \
                        mariadb-devel git curl wget socat lsof
            ;;
        pacman)
            pkg_install base-devel cmake boost openssl mariadb-libs git curl wget socat
            ;;
        zypper)
            pkg_install -t pattern devel_basis
            pkg_install cmake boost-devel libopenssl-devel mariadb-devel git curl wget socat
            ;;
        apk)
            pkg_install build-base cmake boost-dev openssl-dev mariadb-dev \
                        git curl wget linux-headers socat
            ;;
    esac
}

# ==================== Install Caddy ====================
install_caddy() {
    log_info "$(t INSTALL_CADDY)"
    if command -v caddy &>/dev/null; then
        return
    fi
    
    # Official Caddy installation instructions per distro
    case $OS_TYPE in
        debian|ubuntu|linuxmint|pop|kali)
            pkg_install debian-keyring debian-archive-keyring apt-transport-https curl
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null || true
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
            apt-get update -qq
            pkg_install caddy
            ;;
        centos|rhel|almalinux|rocky|fedora)
            if [[ "$PM" == "dnf" ]]; then
                dnf install -y 'dnf-command(copr)' || true
                dnf copr enable -y @caddy/caddy || true
                dnf install -y caddy
            else
                yum install -y yum-plugin-copr || true
                yum copr enable -y @caddy/caddy || true
                yum install -y caddy
            fi
            ;;
        arch|manjaro)
            pkg_install caddy
            ;;
        alpine)
            pkg_install caddy
            ;;
        *)
            # Universal install script (Webi)
            curl -sS https://webi.sh/caddy | sh
            source ~/.profile || true
            ;;
    esac
}

# ==================== Install Trojan ====================
install_trojan() {
    log_info "$(t INSTALL_TROJAN)"
    
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root
    project_root="$(cd "$script_dir/.." && pwd)"
    
    local build_script="$project_root/scripts/build-trojan-core.sh"
    
    if [[ ! -x "$build_script" ]]; then
        log_error "Build script not found at $build_script. Please run from repo."
        exit 1
    fi
    
    ( cd "$project_root" && "$build_script" --build-type Release ) &
    spinner $!
    
    install -m 0755 "$project_root/dist/trojan" /usr/local/bin/trojan
}

# ==================== SSL Setup ====================
setup_ssl() {
    log_info "$(t SSL_SETUP)"
    
    svc_stop caddy
    svc_stop trojan
    
    if [[ ! -f ~/.acme.sh/acme.sh ]]; then
        curl -sS https://get.acme.sh | sh -s email="$EMAIL"
        source ~/.bashrc 2>/dev/null || true
    fi
    
    local acme_sh=~/.acme.sh/acme.sh
    
    $acme_sh --issue -d "$DOMAIN" --standalone --keylength ec-256 || {
        log_error "$(t SSL_FAIL)"
        exit 1
    }
    
    mkdir -p /etc/trojan
    
    local reload_cmd=""
    
    if [[ -f "docker-compose.yml" ]]; then
        reload_cmd="docker restart trojan 2>/dev/null || true"
    else
        case $SM in
            systemd) reload_cmd="systemctl reload trojan 2>/dev/null || true" ;;
            openrc) reload_cmd="rc-service trojan reload 2>/dev/null || true" ;;
            *) reload_cmd="pkill -HUP trojan || true" ;;
        esac
    fi

    $acme_sh --install-cert -d "$DOMAIN" --ecc \
        --key-file /etc/trojan/server.key \
        --fullchain-file /etc/trojan/server.crt \
        --reloadcmd "$reload_cmd"
        
    chmod 644 /etc/trojan/server.crt
    chmod 600 /etc/trojan/server.key
}

# ==================== Trojan/Caddy Config ====================
configure_caddy_overload() {
    local caddy_conf="/etc/caddy/Caddyfile"
    mkdir -p /etc/caddy
    mkdir -p /var/log/caddy
    
    cat > "$caddy_conf" << EOF
:8080 {
    respond "Service Overload" 503
    log {
        output file /var/log/caddy/access.log
    }
}
EOF
}

configure_trojan() {
    # Auto-detect CPU cores for thread configuration
    local CPU_CORES=4
    if command -v nproc &>/dev/null; then
        CPU_CORES=$(nproc)
    elif [[ "$(uname)" == "Darwin" ]]; then
        CPU_CORES=$(sysctl -n hw.ncpu)
    fi

    local trojan_conf="/etc/trojan/config.json"
    mkdir -p /etc/trojan
    mkdir -p /var/log/trojan
    
    # Determine remote address (Host vs Docker)
    # If Docker, we use host network mode, so localhost binds work.
    # However, allow override.
    local remote_addr="${TROJAN_REMOTE_ADDR:-127.0.0.1}"
    
    cat > "$trojan_conf" << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "${remote_addr}",
    "remote_port": 8080,
    "password": [
        "${PASSWORD}"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/etc/trojan/server.crt",
        "key": "/etc/trojan/server.key",
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
    "threads": ${CPU_CORES},
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF
}

setup_services_host() {
    log_info "$(t SERVICE_START)"

    if [[ "$SM" == "systemd" ]]; then
         cat > /etc/systemd/system/trojan.service << EOF
[Unit]
Description=Trojan Proxy Server
After=network.target network-online.target nss-lookup.target caddy.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/trojan /etc/trojan/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=3s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload

    elif [[ "$SM" == "openrc" ]]; then
        cat > /etc/init.d/trojan << EOF
#!/sbin/openrc-run

name="Trojan Proxy Server"
command="/usr/local/bin/trojan"
command_args="/etc/trojan/config.json"
pidfile="/run/trojan.pid"
command_background=true

depend() {
	need net
	after caddy
}
EOF
        chmod +x /etc/init.d/trojan
    fi

    svc_enable caddy
    svc_enable trojan
    svc_restart caddy
    svc_restart trojan
}

# ==================== Docker Support ====================
install_docker() {
    log_info "$(t DOCKER_INSTALL)"
    
    if command -v docker &>/dev/null && command -v docker-compose &>/dev/null; then
        return
    fi
    
    curl -fsSL https://get.docker.com | sh
    
    # Try installing docker-compose plugin or standalone if needed
    if ! docker compose version &>/dev/null; then
        pkg_install docker-compose-plugin &>/dev/null || pkg_install docker-compose &>/dev/null || true
    fi
    
    svc_start docker
    svc_enable docker
}

setup_docker_compose() {
    log_info "$(t DOCKER_COMPOSE_GEN)"
    
    cat > docker-compose.yml << EOF
services:
  trojan:
    build: .
    container_name: trojan
    restart: always
    network_mode: "host"
    volumes:
      - /etc/trojan:/config
      - /etc/trojan:/etc/trojan
    command: ["trojan", "/config/config.json"]

  caddy:
    image: caddy:alpine
    container_name: caddy
    restart: always
    network_mode: "host"
    volumes:
      - /etc/caddy/Caddyfile:/etc/caddy/Caddyfile
      - /var/www/html:${WEB_DIR}
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
EOF
}

start_docker() {
    log_info "$(t DOCKER_START)"
    
    if docker compose version &>/dev/null; then
        docker compose up -d --build
    else
        docker-compose up -d --build
    fi
    
    log_info "$(t DOCKER_SUCCESS)"
}

# ==================== Actions ====================
do_install() {
    # Pre-checks
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        log_warn "$(t NET_FAIL)"
    fi
    
    # Check Ports
    check_port 80 || return
    check_port 443 || return
    
    detect_os
    
    echo ""
    while [[ -z "$DOMAIN" ]]; do
        read -r -p "$(t ENTER_DOMAIN) " DOMAIN
        if [[ -z "$DOMAIN" ]]; then log_warn "$(t DOMAIN_EMPTY)"; fi
    done
    
    read -r -p "$(t ENTER_EMAIL) " EMAIL
    EMAIL=${EMAIL:-"admin@${DOMAIN}"}
    
    read -r -p "$(t ENTER_PWD) " PASSWORD
    if [[ -z "$PASSWORD" ]]; then
        if command -v openssl &>/dev/null; then
            PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
        else
            PASSWORD="trojan_$(date +%s)"
        fi
    fi
    
    echo ""
    echo "$(t INSTALL_MODE_PROMPT)"
    echo -e "${GREEN}$(t MODE_HOST)${NC}"
    echo -e "${BLUE}$(t MODE_DOCKER)${NC}"
    read -r -p "Select [1-2] (1): " INSTALL_MODE
    INSTALL_MODE=${INSTALL_MODE:-1}
    
    echo ""
    echo "$(t CONFIRM_CFG)"
    echo -e "  $(t DOMAIN) ${CYAN}$DOMAIN${NC}"
    echo -e "  $(t EMAIL) ${CYAN}$EMAIL${NC}"
    echo -e "  $(t PWD) ${CYAN}$PASSWORD${NC}"
    echo -e "  Mode: ${CYAN}$([ "$INSTALL_MODE" == "2" ] && echo "Docker" || echo "Host")${NC}"
    
    read -r -p "$(t CONFIRM_PROMPT) [Y/n] " confirm
    confirm=${confirm:-y}
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi
    
    log_info "$(t INSTALL_START)"
    
    if [[ "$INSTALL_MODE" == "2" ]]; then
        # Docker Mode
        install_dependencies
        install_docker
        setup_ssl
        TROJAN_REMOTE_ADDR="127.0.0.1" 
        configure_caddy_overload
        configure_trojan
        setup_docker_compose
        start_docker
    else
        # Host Mode
        install_dependencies
        install_trojan
        install_caddy
        setup_ssl
        configure_caddy_overload
        configure_trojan
        setup_services_host
    fi
    
    clear
    echo -e "╔══════════════════════════════════════════════════════════════╗"
    echo -e "║                 $(t SUCCESS_TITLE)                           ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "$(t CONN_INFO)"
    echo -e "  Host:     ${GREEN}$DOMAIN${NC}"
    echo -e "  Port:     ${GREEN}443${NC}"
    echo -e "  Password: ${GREEN}$PASSWORD${NC}"
    echo ""
    echo "$(t NON_COMPLIANT)"
    
    pause
}

do_status() {
    echo ""
    echo "=============================="
    echo " Service Status"
    echo "=============================="
    
    if command -v docker &>/dev/null && [[ -f "docker-compose.yml" ]]; then
        echo -e "Mode: ${BLUE}Docker${NC}"
        echo "------------------------------"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "trojan|caddy"
    else
        echo -e "Mode: ${GREEN}Host${NC}"
        echo "------------------------------"
        detect_os
        echo -n "Trojan: "; svc_status trojan
        echo -n "Caddy:  "; svc_status caddy
    fi
    pause
}



do_renew_cert() {
    log_info "$(t CERT_RENEW_START)"
    
    if [[ -f ~/.acme.sh/acme.sh ]]; then
        local acme_sh=~/.acme.sh/acme.sh
        
        # Determine reload command
        detect_os
        local reload_cmd=""
         if [[ -f "docker-compose.yml" ]]; then
            reload_cmd="docker restart trojan 2>/dev/null || true"
        else
            case $SM in
                systemd) reload_cmd="systemctl reload trojan 2>/dev/null || true" ;;
                openrc) reload_cmd="rc-service trojan reload 2>/dev/null || true" ;;
                *) reload_cmd="pkill -HUP trojan || true" ;;
            esac
        fi
        
        # Read domain from config if possible
        if [[ -z "$DOMAIN" ]]; then
             if [[ -f "/etc/trojan/config.json" ]]; then
                 # Very rough extraction, might be better to ask user or save it separately
                 # For now, ask user
                 echo ""
                 read -r -p "$(t ENTER_DOMAIN) " DOMAIN
             else
                 log_error "Config not found. Please install first."
                 pause
                 return
             fi
        fi

        $acme_sh --renew -d "$DOMAIN" --force --ecc --reloadcmd "$reload_cmd"
        
        if [[ $? -eq 0 ]]; then
            log_info "$(t CERT_RENEW_SUCCESS)"
        else
            log_error "Certificate renewal failed."
        fi
    else
        log_error "acme.sh not found."
    fi
    pause
}

do_config() {
    if [[ -f "/etc/trojan/config.json" ]]; then
        echo ""
        echo "Trojan Config (/etc/trojan/config.json):"
        echo "----------------------------------------"
        grep -E '"local_port"|"password"|"cert"|"remote_port"' /etc/trojan/config.json
    else
        log_error "Config not found."
    fi
    pause
}

do_logs() {
    echo "1) Trojan"
    echo "2) Caddy"
    read -r -p "Select Service: " svc
    
    case $svc in
        1) 
            if [[ -f "docker-compose.yml" ]]; then docker logs -f trojan --tail 50
            else tail -f /var/log/trojan/trojan.log 2>/dev/null || journalctl -u trojan -f -n 50; fi 
            ;;
        2) 
            if [[ -f "docker-compose.yml" ]]; then docker logs -f caddy --tail 50
            else tail -f /var/log/caddy/access.log 2>/dev/null || journalctl -u caddy -f -n 50; fi 
            ;;
    esac
}

do_uninstall() {
    echo -e "${RED}$(t UNINSTALL_CONFIRM)${NC}"
    read -r -p "Confirm? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        if [[ -f "docker-compose.yml" ]]; then
             if docker compose version &>/dev/null; then docker compose down; else docker-compose down; fi
             rm -f docker-compose.yml
        else
             svc_stop trojan
             svc_stop caddy
             svc_enable trojan # disable
             svc_enable caddy  # disable
             # We don't remove binaries to be safe, just config/services
        fi
        
        rm -rf /etc/trojan
        rm -rf /etc/caddy
        echo "$(t UNINSTALL_DONE)"
    fi
    pause
}

# ==================== Main Menu ====================
show_menu() {
    clear
    print_banner
    echo -e "${CYAN}1.${NC} $(t MENU_INSTALL)"
    echo -e "${CYAN}2.${NC} $(t MENU_STATUS)"
    echo -e "${CYAN}3.${NC} $(t MENU_CONFIG)"
    echo -e "${CYAN}4.${NC} $(t MENU_LOGS)"
    echo -e "${CYAN}5.${NC} $(t MENU_RENEW)"
    echo -e "${CYAN}6.${NC} $(t MENU_UNINSTALL)"
    echo -e "${CYAN}0.${NC} $(t MENU_EXIT)"
    
    echo -e "\n${BLUE}Tip: Run via one-click:${NC} ${YELLOW}bash <(curl -sL ${REPO_URL/github.com/raw.githubusercontent.com}/$REPO_BRANCH/install.sh)${NC}"
    echo ""
    read -r -p "Select [0-6]: " choice
    
    case $choice in
        1) do_install ;;
        2) do_status ;;
        3) do_config ;;
        4) do_logs ;;
        5) do_renew_cert ;;
        6) do_uninstall ;;
        0) exit 0 ;;
        *) echo "Invalid choice"; sleep 1 ;;
    esac
}

main() {
    check_root
    setup_languages
    select_language
    
    while true; do
        show_menu
    done
}

main "$@"
