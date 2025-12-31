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
CONFIG_DIR="/etc/trojan"
BACKUP_DIR="/etc/trojan/backups"
WEB_DIR="/var/www/html"
REPO_URL="https://github.com/proxy-trojan/trojan-obfuscation"
REPO_BRANCH="feature_1.0_no_obfus_and_no_rules"
RELEASE_API_URL="https://api.github.com/repos/proxy-trojan/trojan-obfuscation/releases/latest"
CORE_INSTALL_MODE=""  # "download" or "compile"
SCRIPT_VERSION="2.2"

# Command-line arguments
CLI_DOMAIN=""
CLI_EMAIL=""
CLI_PASSWORD=""
CLI_MODE=""           # "host" or "docker"
CLI_CORE_MODE=""      # "download" or "compile"
CLI_AUTO=false        # Non-interactive mode
CLI_ACTION=""         # install, status, uninstall, update, backup, restore
CLI_CERT_TYPE=""      # "domain" or "ip"
CLI_ACME_CA=""        # "letsencrypt", "zerossl", "buypass"
CLI_NOTIFY_HOOK=""    # acme.sh notify hook: "telegram", "slack", "dingtalk", "mailgun", etc.
CLI_NOTIFY_MODE=""    # 0=disabled, 1=error only, 2=renew+error, 3=always
CLI_NOTIFY_TOKEN=""   # Hook-specific token/key
CLI_NOTIFY_CHAT=""    # Hook-specific chat/channel ID

# Certificate configuration
CERT_TYPE="domain"    # "domain" or "ip"
ACME_CA="letsencrypt" # Default CA
ACME_MAX_RETRY=3      # Max retry attempts for certificate

# Notification configuration (using acme.sh built-in hooks)
NOTIFY_HOOK=""        # acme.sh notify hook name
NOTIFY_TOKEN=""
NOTIFY_CHAT=""
NOTIFY_SOURCE=""      # For hooks that need source/key
NOTIFY_LEVEL=2        # 0: disabled, 1: error only, 2: error + renew, 3: all


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
    MSG_en_CDN_WARN="Warning: Domain resolves to IP %s, but local IP is %s. You are likely using CDN/Cloudflare Proxy. Trojan TCP REQUIRES DNS-Only (Direct) mode."
    MSG_en_CDN_CONFIRM="This configuration WILL NOT WORK with Cloudflare Orange Cloud. Continue anyway?"
    MSG_en_FIREWALL_CHECK="Checking firewall settings..."
    MSG_en_FIREWALL_OPEN="Opening ports 80 and 443..."
    MSG_en_CONN_CHECK="Performing local connectivity check..."
    MSG_en_CONN_OK="Connection Test: OK (Local handshake successful)"
    MSG_en_CONN_FAIL="Connection Test: FAILED (Local handshake failed)"
    MSG_en_CORE_MODE_PROMPT="Select Trojan core installation method:"
    MSG_en_CORE_MODE_DOWNLOAD="1) Download pre-compiled binary (Recommended, fast)"
    MSG_en_CORE_MODE_COMPILE="2) Compile from source (Slower, for custom builds)"
    MSG_en_CORE_DOWNLOADING="Downloading pre-compiled Trojan core..."
    MSG_en_CORE_DOWNLOAD_SUCCESS="Pre-compiled core downloaded successfully!"
    MSG_en_CORE_DOWNLOAD_FAIL="Failed to download pre-compiled core. Falling back to compilation..."
    MSG_en_CORE_NO_RELEASE="No release found. Will compile from source."
    MSG_en_CORE_VERIFYING="Verifying download integrity..."
    MSG_en_CORE_VERIFY_FAIL="Checksum verification failed!"
    MSG_en_DETECTING_ARCH="Detecting system architecture..."
    MSG_en_INSTALL_MODE="Installation Mode:"
    MSG_en_CORE_METHOD="Core Method:"
    MSG_en_MODE_HOST_DOWNLOAD="Host (Download pre-compiled)"
    MSG_en_MODE_HOST_COMPILE="Host (Compile from source)"
    MSG_en_MODE_DOCKER_CONTAINER="Docker (Containerized)"
    MSG_en_QUICK_INSTALL="⚡ Fast install, no compilation needed"
    MSG_en_CUSTOM_BUILD="🔧 Custom build from source code"
    MSG_en_SERVER_INFO="Server Information"
    MSG_en_TROJAN_LINK="Trojan Link (Copy to import)"
    MSG_en_COPY_HINT="💡 Copy the link above to import into your client"
    MSG_en_USEFUL_CMDS="Useful Commands"
    MSG_en_CMD_STATUS="Check status"
    MSG_en_CMD_LOGS="View logs"
    MSG_en_CMD_RESTART="Restart service"
    MSG_en_STEP_DEPS="Installing dependencies"
    MSG_en_STEP_TROJAN="Installing Trojan core"
    MSG_en_STEP_CADDY="Installing Caddy"
    MSG_en_STEP_SSL="Setting up SSL certificate"
    MSG_en_STEP_CONFIG="Generating configuration"
    MSG_en_STEP_SERVICE="Starting services"
    MSG_en_STEP_BBR="Enabling BBR optimization"
    MSG_en_STEP_VERIFY="Verifying installation"
    MSG_en_BBR_ALREADY="BBR is already enabled"
    MSG_en_BBR_ENABLED="BBR enabled successfully"
    MSG_en_BBR_FAILED="Failed to enable BBR (kernel may not support it)"
    MSG_en_HEALTH_CHECK="Running health check..."
    MSG_en_HEALTH_OK="Health check passed!"
    MSG_en_HEALTH_FAIL="Health check failed"
    MSG_en_MENU_UPDATE="Update Trojan Core"
    MSG_en_MENU_BACKUP="Backup Configuration"
    MSG_en_MENU_RESTORE="Restore Configuration"
    MSG_en_MENU_USERS="Manage Users/Passwords"
    MSG_en_UPDATE_CHECK="Checking for updates..."
    MSG_en_UPDATE_AVAILABLE="New version available:"
    MSG_en_UPDATE_CURRENT="Current version:"
    MSG_en_UPDATE_LATEST="Already at latest version"
    MSG_en_UPDATE_CONFIRM="Do you want to update?"
    MSG_en_UPDATE_SUCCESS="Update completed successfully!"
    MSG_en_BACKUP_CREATED="Backup created:"
    MSG_en_BACKUP_LIST="Available backups:"
    MSG_en_RESTORE_SELECT="Select backup to restore:"
    MSG_en_RESTORE_SUCCESS="Configuration restored successfully!"
    MSG_en_USERS_CURRENT="Current passwords:"
    MSG_en_USERS_ADD="Add password"
    MSG_en_USERS_REMOVE="Remove password"
    MSG_en_USERS_BACK="Back to main menu"

    # Certificate options
    MSG_en_CERT_TYPE_PROMPT="Select certificate type:"
    MSG_en_CERT_TYPE_DOMAIN="1) Domain certificate (Let's Encrypt/ZeroSSL)"
    MSG_en_CERT_TYPE_IP="2) IP certificate (Let's Encrypt short-lived, 6 days)"
    MSG_en_CERT_CA_PROMPT="Select Certificate Authority:"
    MSG_en_CERT_CA_LE="1) Let's Encrypt (Recommended, widely trusted)"
    MSG_en_CERT_CA_ZEROSSL="2) ZeroSSL (Alternative, requires EAB)"
    MSG_en_CERT_CA_BUYPASS="3) Buypass (Norwegian CA, trusted)"
    MSG_en_CERT_RETRY="Certificate request failed. Retrying (%d/%d)..."
    MSG_en_CERT_RETRY_CA="Trying alternative CA: %s"
    MSG_en_CERT_ALL_FAILED="All certificate attempts failed. Please check:"
    MSG_en_CERT_CHECK_DNS="  1. Domain DNS resolves to this server's IP"
    MSG_en_CERT_CHECK_PORT="  2. Ports 80/443 are open and not occupied"
    MSG_en_CERT_CHECK_RATE="  3. Not hitting rate limits (try again later)"
    MSG_en_CERT_SELF_SIGNED="Requesting Let's Encrypt IP certificate (short-lived)..."
    MSG_en_CERT_SELF_SIGNED_WARN="Note: IP certificates are valid for 6 days, auto-renew 1 day before expiry"
    MSG_en_CERT_SELF_SIGNED_OK="IP certificate obtained successfully!"
    MSG_en_ENTER_IP="Please enter your server IP address:"
    MSG_en_IP_INVALID="Invalid IP address format."

    # Notification options
    MSG_en_NOTIFY_PROMPT="Configure deployment notifications? (Optional)"
    MSG_en_NOTIFY_NONE="1) No notifications"
    MSG_en_NOTIFY_TELEGRAM="2) Telegram notification"
    MSG_en_NOTIFY_WEBHOOK="3) Custom Webhook"
    MSG_en_NOTIFY_TG_TOKEN="Enter Telegram Bot Token (from @BotFather):"
    MSG_en_NOTIFY_TG_CHAT="Enter Telegram Chat ID (your user or group ID):"
    MSG_en_NOTIFY_WEBHOOK_URL="Enter Webhook URL:"
    MSG_en_NOTIFY_TEST="Testing notification..."
    MSG_en_NOTIFY_TEST_OK="Notification test successful!"
    MSG_en_NOTIFY_TEST_FAIL="Notification test failed. Continue anyway?"
    MSG_en_NOTIFY_SEND_SUCCESS="Deployment success notification sent!"
    MSG_en_NOTIFY_SEND_FAIL="Failed to send notification (non-critical)"

    # ACME progress messages
    MSG_en_ACME_REGISTER="Registering account with %s..."
    MSG_en_ACME_ISSUE="Requesting certificate from %s..."
    MSG_en_ACME_VERIFY="Domain verification in progress..."
    MSG_en_ACME_INSTALL="Installing certificate..."
    MSG_en_ACME_SUCCESS="Certificate obtained successfully from %s!"
    MSG_en_ACME_DNS_CHECK="Checking DNS resolution..."
    MSG_en_ACME_DNS_OK="DNS resolves correctly to this server"
    MSG_en_ACME_DNS_FAIL="DNS does not resolve to this server. Abort or continue?"
    MSG_en_ACME_PORT_CHECK="Checking port availability..."
    MSG_en_ACME_PORT_OK="Ports 80/443 available"
    MSG_en_ACME_STANDALONE="Using standalone mode for verification..."
    MSG_en_ACME_NOTIFY_CONFIGURED="ACME notification hook configured successfully"
    MSG_en_ACME_NOTIFY_PROMPT="Configure ACME certificate notifications? (acme.sh built-in)"
    MSG_en_ACME_NOTIFY_NONE="1) No notifications"
    MSG_en_ACME_NOTIFY_TELEGRAM="2) Telegram"
    MSG_en_ACME_NOTIFY_DINGTALK="3) DingTalk (钉钉)"
    MSG_en_ACME_NOTIFY_FEISHU="4) Feishu (飞书)"
    MSG_en_ACME_NOTIFY_SLACK="5) Slack"
    MSG_en_ACME_NOTIFY_BARK="6) Bark (iOS)"
    MSG_en_ACME_NOTIFY_SERVERCHAN="7) ServerChan"
    MSG_en_ACME_NOTIFY_LEVEL="Notification level (1=error, 2=error+renew, 3=all):"

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
    MSG_cn_CDN_WARN="警告：域名解析IP (%s) 与本机公网IP (%s) 不一致。您可能开启了 CDN (Cloudflare) 代理。Trojan TCP 必须使用 DNS-Only (直连) 模式，否则无法连接。"
    MSG_cn_CDN_CONFIRM="此配置在 Cloudflare 开启代理 (橙色云朵) 状态下 **将无法工作**。是否继续？"
    MSG_cn_FIREWALL_CHECK="正在检查防火墙设置..."
    MSG_cn_FIREWALL_OPEN="正在开放 80 和 443 端口..."
    MSG_cn_CONN_CHECK="正在执行本地连接检查..."
    MSG_cn_CONN_OK="连接测试：正常 (本地握手成功)"
    MSG_cn_CONN_FAIL="连接测试：失败 (本地握手失败)"
    MSG_cn_CORE_MODE_PROMPT="请选择 Trojan 核心安装方式："
    MSG_cn_CORE_MODE_DOWNLOAD="1) 下载预编译核心 (推荐，速度快，免编译)"
    MSG_cn_CORE_MODE_COMPILE="2) 从源码编译 (较慢，适合自定义构建)"
    MSG_cn_CORE_DOWNLOADING="正在下载预编译的 Trojan 核心..."
    MSG_cn_CORE_DOWNLOAD_SUCCESS="预编译核心下载成功！"
    MSG_cn_CORE_DOWNLOAD_FAIL="预编译核心下载失败，将自动切换到源码编译..."
    MSG_cn_CORE_NO_RELEASE="未找到可用的发行版本，将从源码编译。"
    MSG_cn_CORE_VERIFYING="正在验证下载文件完整性..."
    MSG_cn_CORE_VERIFY_FAIL="文件校验失败！"
    MSG_cn_DETECTING_ARCH="正在检测系统架构..."
    MSG_cn_INSTALL_MODE="安装模式："
    MSG_cn_CORE_METHOD="核心方式："
    MSG_cn_MODE_HOST_DOWNLOAD="主机模式 (下载预编译)"
    MSG_cn_MODE_HOST_COMPILE="主机模式 (源码编译)"
    MSG_cn_MODE_DOCKER_CONTAINER="Docker 容器化部署"
    MSG_cn_QUICK_INSTALL="⚡ 快速安装，无需编译"
    MSG_cn_CUSTOM_BUILD="🔧 从源码自定义构建"
    MSG_cn_SERVER_INFO="服务器信息"
    MSG_cn_TROJAN_LINK="Trojan 链接 (复制导入)"
    MSG_cn_COPY_HINT="💡 复制上方链接导入到客户端即可使用"
    MSG_cn_USEFUL_CMDS="常用命令"
    MSG_cn_CMD_STATUS="查看状态"
    MSG_cn_CMD_LOGS="查看日志"
    MSG_cn_CMD_RESTART="重启服务"
    MSG_cn_STEP_DEPS="安装依赖"
    MSG_cn_STEP_TROJAN="安装 Trojan 核心"
    MSG_cn_STEP_CADDY="安装 Caddy"
    MSG_cn_STEP_SSL="配置 SSL 证书"
    MSG_cn_STEP_CONFIG="生成配置文件"
    MSG_cn_STEP_SERVICE="启动服务"
    MSG_cn_STEP_BBR="启用 BBR 优化"
    MSG_cn_STEP_VERIFY="验证安装"
    MSG_cn_BBR_ALREADY="BBR 已启用"
    MSG_cn_BBR_ENABLED="BBR 启用成功"
    MSG_cn_BBR_FAILED="BBR 启用失败 (内核可能不支持)"
    MSG_cn_HEALTH_CHECK="正在运行健康检查..."
    MSG_cn_HEALTH_OK="健康检查通过！"
    MSG_cn_HEALTH_FAIL="健康检查失败"
    MSG_cn_MENU_UPDATE="更新 Trojan 核心"
    MSG_cn_MENU_BACKUP="备份配置"
    MSG_cn_MENU_RESTORE="恢复配置"
    MSG_cn_MENU_USERS="管理用户/密码"
    MSG_cn_UPDATE_CHECK="正在检查更新..."
    MSG_cn_UPDATE_AVAILABLE="可用新版本："
    MSG_cn_UPDATE_CURRENT="当前版本："
    MSG_cn_UPDATE_LATEST="已是最新版本"
    MSG_cn_UPDATE_CONFIRM="是否更新？"
    MSG_cn_UPDATE_SUCCESS="更新完成！"
    MSG_cn_BACKUP_CREATED="备份已创建："
    MSG_cn_BACKUP_LIST="可用备份列表："
    MSG_cn_RESTORE_SELECT="选择要恢复的备份："
    MSG_cn_RESTORE_SUCCESS="配置恢复成功！"
    MSG_cn_USERS_CURRENT="当前密码列表："
    MSG_cn_USERS_ADD="添加密码"
    MSG_cn_USERS_REMOVE="删除密码"
    MSG_cn_USERS_BACK="返回主菜单"

    # Certificate options / 证书选项
    MSG_cn_CERT_TYPE_PROMPT="请选择证书类型："
    MSG_cn_CERT_TYPE_DOMAIN="1) 域名证书 (Let's Encrypt/ZeroSSL 签发)"
    MSG_cn_CERT_TYPE_IP="2) IP 证书 (Let's Encrypt 短期证书，6天有效期)"
    MSG_cn_CERT_CA_PROMPT="请选择证书颁发机构 (CA)："
    MSG_cn_CERT_CA_LE="1) Let's Encrypt (推荐，广泛信任)"
    MSG_cn_CERT_CA_ZEROSSL="2) ZeroSSL (备选，需要 EAB 注册)"
    MSG_cn_CERT_CA_BUYPASS="3) Buypass (挪威 CA，受信任)"
    MSG_cn_CERT_RETRY="证书申请失败，正在重试 (%d/%d)..."
    MSG_cn_CERT_RETRY_CA="正在尝试备用 CA：%s"
    MSG_cn_CERT_ALL_FAILED="所有证书申请尝试均失败，请检查："
    MSG_cn_CERT_CHECK_DNS="  1. 域名 DNS 是否正确解析到本服务器 IP"
    MSG_cn_CERT_CHECK_PORT="  2. 80/443 端口是否开放且未被占用"
    MSG_cn_CERT_CHECK_RATE="  3. 是否触发了频率限制（稍后再试）"
    MSG_cn_CERT_SELF_SIGNED="正在申请 Let's Encrypt IP 短期证书..."
    MSG_cn_CERT_SELF_SIGNED_WARN="提示：IP 证书有效期6天，到期前1天自动续期"
    MSG_cn_CERT_SELF_SIGNED_OK="IP 证书申请成功！"
    MSG_cn_ENTER_IP="请输入服务器 IP 地址："
    MSG_cn_IP_INVALID="IP 地址格式无效。"

    # Notification options / 通知选项
    MSG_cn_NOTIFY_PROMPT="是否配置部署通知？（可选）"
    MSG_cn_NOTIFY_NONE="1) 不启用通知"
    MSG_cn_NOTIFY_TELEGRAM="2) Telegram 通知"
    MSG_cn_NOTIFY_WEBHOOK="3) 自定义 Webhook"
    MSG_cn_NOTIFY_TG_TOKEN="请输入 Telegram Bot Token（从 @BotFather 获取）："
    MSG_cn_NOTIFY_TG_CHAT="请输入 Telegram Chat ID（您的用户 ID 或群组 ID）："
    MSG_cn_NOTIFY_WEBHOOK_URL="请输入 Webhook URL："
    MSG_cn_NOTIFY_TEST="正在测试通知..."
    MSG_cn_NOTIFY_TEST_OK="通知测试成功！"
    MSG_cn_NOTIFY_TEST_FAIL="通知测试失败，是否继续？"
    MSG_cn_NOTIFY_SEND_SUCCESS="部署成功通知已发送！"
    MSG_cn_NOTIFY_SEND_FAIL="通知发送失败（非关键错误）"

    # ACME progress messages / ACME 进度消息
    MSG_cn_ACME_REGISTER="正在向 %s 注册账户..."
    MSG_cn_ACME_ISSUE="正在从 %s 申请证书..."
    MSG_cn_ACME_VERIFY="正在进行域名验证..."
    MSG_cn_ACME_INSTALL="正在安装证书..."
    MSG_cn_ACME_SUCCESS="成功从 %s 获取证书！"
    MSG_cn_ACME_DNS_CHECK="正在检查 DNS 解析..."
    MSG_cn_ACME_DNS_OK="DNS 正确解析到本服务器"
    MSG_cn_ACME_DNS_FAIL="DNS 未解析到本服务器，是否中止或继续？"
    MSG_cn_ACME_PORT_CHECK="正在检查端口可用性..."
    MSG_cn_ACME_PORT_OK="80/443 端口可用"
    MSG_cn_ACME_STANDALONE="使用 standalone 模式进行验证..."
    MSG_cn_ACME_NOTIFY_CONFIGURED="ACME 通知钩子配置成功"
    MSG_cn_ACME_NOTIFY_PROMPT="是否配置 ACME 证书通知？（acme.sh 内置）"
    MSG_cn_ACME_NOTIFY_NONE="1) 不启用通知"
    MSG_cn_ACME_NOTIFY_TELEGRAM="2) Telegram"
    MSG_cn_ACME_NOTIFY_DINGTALK="3) 钉钉"
    MSG_cn_ACME_NOTIFY_FEISHU="4) 飞书"
    MSG_cn_ACME_NOTIFY_SLACK="5) Slack"
    MSG_cn_ACME_NOTIFY_BARK="6) Bark (iOS)"
    MSG_cn_ACME_NOTIFY_SERVERCHAN="7) Server酱"
    MSG_cn_ACME_NOTIFY_LEVEL="通知级别（1=仅错误，2=错误+续期，3=全部）："
}

# Helper to get string
t() {
    local key="MSG_${LANG_CUR}_$1"
    eval echo \$$key
}

# Generate Trojan URL
generate_trojan_url() {
    local password=$1
    local domain=$2
    # Safe to assume alphanumeric password specific to this script's generation
    echo "trojan://${password}@${domain}:443?security=tls&type=tcp&headerType=none&sni=${domain}#${domain}"
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

# ==================== Progress Display ====================
TOTAL_STEPS=0
CURRENT_STEP=0
STEP_NAMES=()

# Initialize progress tracking
init_progress() {
    TOTAL_STEPS=$1
    CURRENT_STEP=0
    shift
    STEP_NAMES=("$@")
}

# Show current step with progress bar
show_step() {
    local step_num=$1
    local status=$2  # "start", "done", "fail"
    local step_name="${STEP_NAMES[$((step_num-1))]}"

    CURRENT_STEP=$step_num
    local progress=$((step_num * 100 / TOTAL_STEPS))
    local filled=$((progress / 5))
    local empty=$((20 - filled))

    # Build progress bar
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="▓"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    case $status in
        start)
            echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}[${step_num}/${TOTAL_STEPS}]${NC} ${BOLD}${step_name}${NC}..."
            echo -e "${CYAN}[${bar}] ${progress}%${NC}"
            ;;
        done)
            echo -e "\r${GREEN}[${step_num}/${TOTAL_STEPS}]${NC} ${step_name} ${GREEN}✓${NC}"
            ;;
        fail)
            echo -e "\r${RED}[${step_num}/${TOTAL_STEPS}]${NC} ${step_name} ${RED}✗${NC}"
            ;;
    esac
}

# Quick progress update (single line)
progress_update() {
    local message=$1
    echo -e "    ${PURPLE}→${NC} ${message}"
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║       Trojan + Caddy Deployment Script v${SCRIPT_VERSION}            ║"
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

check_domain_ip() {
    local domain=$1
    local ip=""
    local local_ip=""
    
    # Get Public IP
    local_ip=$(curl -s4 ifconfig.co || curl -s4 ip.sb)
    
    if command -v dig &>/dev/null; then
        ip=$(dig +short "$domain" | tail -n 1)
    elif command -v nslookup &>/dev/null; then
        ip=$(nslookup "$domain" | grep 'Address:' | tail -n 1 | awk '{print $2}')
    elif command -v getent &>/dev/null; then
        ip=$(getent hosts "$domain" | awk '{print $1}')
    fi
    
    if [[ -n "$ip" ]] && [[ -n "$local_ip" ]]; then
       if [[ "$ip" != "$local_ip" ]]; then
            log_warn "$(printf "$(t CDN_WARN)" "$ip" "$local_ip")"
            read -r -p "$(t CDN_CONFIRM) [y/N] " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                exit 1
            fi
            return 1
       fi
    fi
    return 0
}

# ==================== Notification Functions ====================
# Configure notification interactively (using acme.sh built-in hooks)
configure_notification() {
    if [[ "$CLI_AUTO" == true ]]; then
        # Use CLI parameters if provided
        if [[ -n "$CLI_NOTIFY_HOOK" ]]; then
            NOTIFY_HOOK="$CLI_NOTIFY_HOOK"
            NOTIFY_TOKEN="$CLI_NOTIFY_TOKEN"
            NOTIFY_CHAT="$CLI_NOTIFY_CHAT"
            NOTIFY_LEVEL="${CLI_NOTIFY_MODE:-2}"
        fi
        return 0
    fi

    echo ""
    echo -e "${CYAN}$(t ACME_NOTIFY_PROMPT)${NC}"
    echo -e "${GREEN}$(t ACME_NOTIFY_NONE)${NC}"
    echo -e "${BLUE}$(t ACME_NOTIFY_TELEGRAM)${NC}"
    echo -e "${YELLOW}$(t ACME_NOTIFY_DINGTALK)${NC}"
    echo -e "${PURPLE}$(t ACME_NOTIFY_FEISHU)${NC}"
    echo -e "${CYAN}$(t ACME_NOTIFY_SLACK)${NC}"
    echo -e "${GREEN}$(t ACME_NOTIFY_BARK)${NC}"
    echo -e "${BLUE}$(t ACME_NOTIFY_SERVERCHAN)${NC}"
    echo ""
    read -r -p "Select [1-7] (1): " notify_choice
    notify_choice=${notify_choice:-1}

    case $notify_choice in
        1)
            NOTIFY_HOOK=""
            ;;
        2)
            NOTIFY_HOOK="telegram"
            echo ""
            read -r -p "$(t NOTIFY_TG_TOKEN) " NOTIFY_TOKEN
            read -r -p "$(t NOTIFY_TG_CHAT) " NOTIFY_CHAT
            read -r -p "$(t ACME_NOTIFY_LEVEL) " NOTIFY_LEVEL
            NOTIFY_LEVEL=${NOTIFY_LEVEL:-2}
            ;;
        3)
            NOTIFY_HOOK="dingtalk"
            echo ""
            echo -e "${YELLOW}Enter DingTalk Webhook URL:${NC}"
            read -r -p "> " NOTIFY_TOKEN
            read -r -p "$(t ACME_NOTIFY_LEVEL) " NOTIFY_LEVEL
            NOTIFY_LEVEL=${NOTIFY_LEVEL:-2}
            ;;
        4)
            NOTIFY_HOOK="feishu"
            echo ""
            echo -e "${YELLOW}Enter Feishu Webhook URL:${NC}"
            read -r -p "> " NOTIFY_TOKEN
            read -r -p "$(t ACME_NOTIFY_LEVEL) " NOTIFY_LEVEL
            NOTIFY_LEVEL=${NOTIFY_LEVEL:-2}
            ;;
        5)
            NOTIFY_HOOK="slack"
            echo ""
            echo -e "${YELLOW}Enter Slack Webhook URL:${NC}"
            read -r -p "> " NOTIFY_TOKEN
            read -r -p "$(t ACME_NOTIFY_LEVEL) " NOTIFY_LEVEL
            NOTIFY_LEVEL=${NOTIFY_LEVEL:-2}
            ;;
        6)
            NOTIFY_HOOK="bark"
            echo ""
            echo -e "${YELLOW}Enter Bark Device Key:${NC}"
            read -r -p "> " NOTIFY_TOKEN
            read -r -p "$(t ACME_NOTIFY_LEVEL) " NOTIFY_LEVEL
            NOTIFY_LEVEL=${NOTIFY_LEVEL:-2}
            ;;
        7)
            NOTIFY_HOOK="serverchan"
            echo ""
            echo -e "${YELLOW}Enter ServerChan SCKEY:${NC}"
            read -r -p "> " NOTIFY_TOKEN
            read -r -p "$(t ACME_NOTIFY_LEVEL) " NOTIFY_LEVEL
            NOTIFY_LEVEL=${NOTIFY_LEVEL:-2}
            ;;
        *)
            NOTIFY_HOOK=""
            ;;
    esac

    if [[ -n "$NOTIFY_HOOK" ]]; then
        log_info "ACME notify hook: $NOTIFY_HOOK (level: $NOTIFY_LEVEL)"
    fi
}

# ==================== Certificate Type Selection ====================
# Validate IP address format
validate_ip() {
    local ip=$1
    local valid_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ $ip =~ $valid_regex ]]; then
        # Check each octet
        IFS='.' read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Select certificate type (domain or IP)
select_cert_type() {
    if [[ -n "$CLI_CERT_TYPE" ]]; then
        CERT_TYPE="$CLI_CERT_TYPE"
        return 0
    fi

    if [[ "$CLI_AUTO" == true ]]; then
        CERT_TYPE="domain"
        return 0
    fi

    echo ""
    echo -e "${CYAN}$(t CERT_TYPE_PROMPT)${NC}"
    echo -e "${GREEN}$(t CERT_TYPE_DOMAIN)${NC}"
    echo -e "${YELLOW}$(t CERT_TYPE_IP)${NC}"
    echo ""
    read -r -p "Select [1-2] (1): " cert_choice
    cert_choice=${cert_choice:-1}

    case $cert_choice in
        1) CERT_TYPE="domain" ;;
        2) CERT_TYPE="ip" ;;
        *) CERT_TYPE="domain" ;;
    esac
}

# Select CA for domain certificates
select_acme_ca() {
    if [[ -n "$CLI_ACME_CA" ]]; then
        ACME_CA="$CLI_ACME_CA"
        return 0
    fi

    if [[ "$CLI_AUTO" == true ]]; then
        ACME_CA="letsencrypt"
        return 0
    fi

    echo ""
    echo -e "${CYAN}$(t CERT_CA_PROMPT)${NC}"
    echo -e "${GREEN}$(t CERT_CA_LE)${NC}"
    echo -e "${BLUE}$(t CERT_CA_ZEROSSL)${NC}"
    echo -e "${PURPLE}$(t CERT_CA_BUYPASS)${NC}"
    echo ""
    read -r -p "Select [1-3] (1): " ca_choice
    ca_choice=${ca_choice:-1}

    case $ca_choice in
        1) ACME_CA="letsencrypt" ;;
        2) ACME_CA="zerossl" ;;
        3) ACME_CA="buypass" ;;
        *) ACME_CA="letsencrypt" ;;
    esac
}

# Request ACME IP certificate from Let's Encrypt (short-lived)
request_ip_certificate() {
    local ip=$1
    log_info "$(t CERT_SELF_SIGNED)"
    log_info "$(t CERT_SELF_SIGNED_WARN)"

    mkdir -p /etc/trojan

    # Install acme.sh if not present
    local acme_sh=~/.acme.sh/acme.sh
    if [[ ! -f "$acme_sh" ]]; then
        progress_update "Installing acme.sh..."
        curl -sS https://get.acme.sh | sh -s email="${EMAIL:-admin@localhost}"
        source ~/.bashrc 2>/dev/null || true
    fi

    if [[ ! -f "$acme_sh" ]]; then
        acme_sh="$HOME/.acme.sh/acme.sh"
    fi

    # Register account with Let's Encrypt
    progress_update "Registering account with Let's Encrypt..."
    $acme_sh --register-account -m "${EMAIL:-admin@localhost}" --server letsencrypt 2>/dev/null || true

    # Request IP certificate with short-lived profile
    # 6 days validity, auto-renew 1 day before expiry
    progress_update "Requesting IP certificate (standalone mode)..."

    local cert_obtained=false
    local retry=0
    local max_retry=3

    while [[ $retry -lt $max_retry ]]; do
        ((retry++)) || true

        if $acme_sh --issue --server letsencrypt \
            -d "$ip" \
            --standalone \
            --keylength ec-256 \
            --certificate-profile shortlived \
            --days 6 2>&1; then
            cert_obtained=true
            break
        fi

        # Check if cert already exists
        if [[ -f "$HOME/.acme.sh/${ip}_ecc/${ip}.key" ]] && [[ -f "$HOME/.acme.sh/${ip}_ecc/fullchain.cer" ]]; then
            log_info "Certificate already exists. Using existing certificate."
            cert_obtained=true
            break
        fi

        if [[ $retry -lt $max_retry ]]; then
            log_warn "Certificate request failed. Retrying ($retry/$max_retry)..."
            sleep 5
        fi
    done

    if [[ "$cert_obtained" != true ]]; then
        log_error "Failed to obtain IP certificate from Let's Encrypt"
        log_warn "Please check:"
        log_warn "  1. Port 80 is open and not occupied"
        log_warn "  2. IP address is publicly accessible"
        log_warn "  3. Not hitting rate limits"
        return 1
    fi

    # Set auto-renew to 1 day before expiry (for 6-day certificate)
    progress_update "Configuring auto-renewal (1 day before expiry)..."
    $acme_sh --set-cert-renew-days 1 -d "$ip" --ecc 2>/dev/null || true

    # Determine reload command
    local reload_cmd=""
    if [[ -f "docker-compose.yml" ]]; then
        reload_cmd="docker restart trojan 2>/dev/null || true"
    else
        case $SM in
            systemd) reload_cmd="systemctl is-active --quiet trojan && systemctl reload trojan || true" ;;
            openrc) reload_cmd="rc-service trojan status >/dev/null 2>&1 && rc-service trojan reload || true" ;;
            *) reload_cmd="pkill -HUP trojan || true" ;;
        esac
    fi

    # Install certificate
    progress_update "Installing certificate..."
    $acme_sh --install-cert -d "$ip" --ecc \
        --key-file /etc/trojan/server.key \
        --fullchain-file /etc/trojan/server.crt \
        --reloadcmd "$reload_cmd"

    if [[ -f /etc/trojan/server.crt ]] && [[ -f /etc/trojan/server.key ]]; then
        chmod 644 /etc/trojan/server.crt
        chmod 600 /etc/trojan/server.key
        log_info "$(t CERT_SELF_SIGNED_OK)"
        return 0
    else
        log_error "Failed to install IP certificate"
        return 1
    fi
}

# Pre-check before ACME certificate request
acme_pre_check() {
    local domain=$1
    local all_ok=true

    # Check DNS resolution
    progress_update "$(t ACME_DNS_CHECK)"
    local resolved_ip=""
    local local_ip=""

    local_ip=$(curl -s4 ifconfig.co 2>/dev/null || curl -s4 ip.sb 2>/dev/null)

    if command -v dig &>/dev/null; then
        resolved_ip=$(dig +short "$domain" | tail -n 1)
    elif command -v nslookup &>/dev/null; then
        resolved_ip=$(nslookup "$domain" 2>/dev/null | grep 'Address:' | tail -n 1 | awk '{print $2}')
    elif command -v getent &>/dev/null; then
        resolved_ip=$(getent hosts "$domain" | awk '{print $1}')
    fi

    if [[ -n "$resolved_ip" ]] && [[ "$resolved_ip" == "$local_ip" ]]; then
        progress_update "$(t ACME_DNS_OK) ($resolved_ip)"
    elif [[ -n "$resolved_ip" ]]; then
        log_warn "Domain resolves to $resolved_ip, but server IP is $local_ip"
        if [[ "$CLI_AUTO" != true ]]; then
            echo -e "${YELLOW}$(t ACME_DNS_FAIL)${NC}"
            read -r -p "[A]bort / [C]ontinue: " dns_action
            if [[ "$dns_action" =~ ^[Aa]$ ]]; then
                return 1
            fi
        fi
    else
        log_warn "Could not resolve domain DNS"
    fi

    # Check port availability
    progress_update "$(t ACME_PORT_CHECK)"
    local port_ok=true

    for port in 80 443; do
        if ss -tuln 2>/dev/null | grep -q ":${port} " || netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            # Check if it's our own services
            local proc=$(lsof -i :$port 2>/dev/null | grep LISTEN | awk '{print $1}' | head -1)
            if [[ -n "$proc" ]] && [[ "$proc" != "caddy" ]] && [[ "$proc" != "trojan" ]]; then
                log_warn "Port $port is occupied by $proc"
                port_ok=false
            fi
        fi
    done

    if [[ "$port_ok" == true ]]; then
        progress_update "$(t ACME_PORT_OK)"
    fi

    return 0
}

configure_firewall() {
    log_info "$(t FIREWALL_CHECK)"
    log_info "$(t FIREWALL_OPEN)"
    
    if command -v ufw &>/dev/null; then
        if ufw status | grep -q "Status: active"; then
             ufw allow 80/tcp
             ufw allow 443/tcp
             ufw reload
        fi
    elif command -v firewall-cmd &>/dev/null; then
        if systemctl is-active firewalld &>/dev/null; then
            firewall-cmd --permanent --add-port=80/tcp
            firewall-cmd --permanent --add-port=443/tcp
            firewall-cmd --reload
        fi
    elif command -v iptables &>/dev/null; then
         # Basic iptables check/add if not present
         if ! iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null; then
             iptables -I INPUT -p tcp --dport 80 -j ACCEPT
         fi
         if ! iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null; then
             iptables -I INPUT -p tcp --dport 443 -j ACCEPT
         fi
         # Should save iptables but that distro specific (netfilter-persistent etc)
         # Just leave as runtime open mostly for now
    fi
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

svc_disable() {
    local service=$1
    case $SM in
        systemd) systemctl disable $service 2>/dev/null || true ;;
        openrc) rc-update del $service default 2>/dev/null || true ;;
        sysvinit) update-rc.d -f $service remove 2>/dev/null || true ;;
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

# ==================== Core Installation Mode Selection ====================
select_core_install_mode() {
    echo ""
    echo -e "${CYAN}$(t CORE_MODE_PROMPT)${NC}"
    echo -e "${GREEN}$(t CORE_MODE_DOWNLOAD)${NC}"
    echo -e "${BLUE}$(t CORE_MODE_COMPILE)${NC}"
    echo ""
    read -r -p "Select [1-2] (1): " mode_choice
    mode_choice=${mode_choice:-1}

    case $mode_choice in
        1) CORE_INSTALL_MODE="download" ;;
        2) CORE_INSTALL_MODE="compile" ;;
        *) CORE_INSTALL_MODE="download" ;;
    esac
}

# Detect system architecture and map to release naming
detect_release_arch() {
    log_info "$(t DETECTING_ARCH)"
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')

    # Map architecture to release naming convention
    case "$arch" in
        x86_64|amd64)
            RELEASE_ARCH="x86_64"
            ;;
        aarch64|arm64)
            if [[ "$os" == "darwin" ]]; then
                RELEASE_ARCH="arm64"
            else
                RELEASE_ARCH="aarch64"
            fi
            ;;
        *)
            log_warn "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    # Map OS to release naming convention
    case "$os" in
        linux)
            RELEASE_OS="linux"
            RELEASE_EXT="tar.gz"
            ;;
        darwin)
            RELEASE_OS="macos"
            RELEASE_EXT="tar.gz"
            ;;
        *)
            log_warn "Unsupported OS: $os"
            return 1
            ;;
    esac

    log_info "System: ${RELEASE_OS}-${RELEASE_ARCH}"
    return 0
}

# Download pre-compiled Trojan core from GitHub Releases
download_precompiled_core() {
    log_info "$(t CORE_DOWNLOADING)"

    # Detect architecture
    if ! detect_release_arch; then
        log_warn "$(t CORE_DOWNLOAD_FAIL)"
        return 1
    fi

    # Get latest release info from GitHub API
    local release_info
    release_info=$(curl -sL "$RELEASE_API_URL" 2>/dev/null)

    if [[ -z "$release_info" ]] || echo "$release_info" | grep -q "Not Found"; then
        log_warn "$(t CORE_NO_RELEASE)"
        return 1
    fi

    # Extract version tag
    local version
    version=$(echo "$release_info" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)

    if [[ -z "$version" ]]; then
        log_warn "$(t CORE_NO_RELEASE)"
        return 1
    fi

    log_info "Latest release: $version"

    # Construct download URL
    local filename="trojan-${version}-${RELEASE_OS}-${RELEASE_ARCH}.${RELEASE_EXT}"
    local download_url="${REPO_URL}/releases/download/${version}/${filename}"
    local sha256_url="${download_url}.sha256"

    # Create temp directory
    local tmp_dir=$(mktemp -d)

    # Download binary
    log_info "Downloading: $filename"
    if ! curl -sL -o "$tmp_dir/$filename" "$download_url"; then
        log_warn "$(t CORE_DOWNLOAD_FAIL)"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Download and verify checksum
    log_info "$(t CORE_VERIFYING)"
    if curl -sL -o "$tmp_dir/${filename}.sha256" "$sha256_url" 2>/dev/null; then
        cd "$tmp_dir"
        if command -v sha256sum &>/dev/null; then
            if ! sha256sum -c "${filename}.sha256" &>/dev/null; then
                log_warn "$(t CORE_VERIFY_FAIL)"
                cd - >/dev/null
                rm -rf "$tmp_dir"
                return 1
            fi
        elif command -v shasum &>/dev/null; then
            if ! shasum -a 256 -c "${filename}.sha256" &>/dev/null; then
                log_warn "$(t CORE_VERIFY_FAIL)"
                cd - >/dev/null
                rm -rf "$tmp_dir"
                return 1
            fi
        fi
        cd - >/dev/null
    else
        log_warn "Checksum file not available, skipping verification"
    fi

    # Extract and install
    log_info "Extracting..."
    cd "$tmp_dir"
    tar -xzf "$filename"

    # Find the extracted binary (naming: trojan-VERSION-OS-ARCH)
    local binary_name="trojan-${version}-${RELEASE_OS}-${RELEASE_ARCH}"
    if [[ -f "$binary_name" ]]; then
        install -m 0755 "$binary_name" /usr/local/bin/trojan
    elif [[ -f "trojan" ]]; then
        install -m 0755 "trojan" /usr/local/bin/trojan
    else
        # Try to find any trojan binary
        local found_binary=$(find . -maxdepth 1 -name "trojan*" -type f ! -name "*.sha256" ! -name "*.tar.gz" | head -1)
        if [[ -n "$found_binary" ]]; then
            install -m 0755 "$found_binary" /usr/local/bin/trojan
        else
            log_warn "$(t CORE_DOWNLOAD_FAIL)"
            cd - >/dev/null
            rm -rf "$tmp_dir"
            return 1
        fi
    fi
    cd - >/dev/null

    # Cleanup temp directory
    rm -rf "$tmp_dir"

    # Verify installation
    if [[ -x /usr/local/bin/trojan ]]; then
        log_info "$(t CORE_DOWNLOAD_SUCCESS)"
        # trojan outputs version to stderr with [FATAL] prefix, extract version number
        local version_output
        version_output=$(/usr/local/bin/trojan -v 2>&1 | grep -oE 'trojan [0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
        if [[ -n "$version_output" ]]; then
            log_info "Installed: $version_output"
        else
            log_info "Installed: $version"
        fi
        return 0
    else
        log_warn "$(t CORE_DOWNLOAD_FAIL)"
        return 1
    fi
}

# Install minimal dependencies for pre-compiled binary (no build tools needed)
install_minimal_dependencies() {
    log_info "$(t INSTALL_DEPS) (minimal)"
    pkg_update

    case $PM in
        apt)
            pkg_install curl wget socat lsof ca-certificates
            ;;
        dnf|yum)
            pkg_install curl wget socat lsof ca-certificates
            ;;
        pacman)
            pkg_install curl wget socat
            ;;
        zypper)
            pkg_install curl wget socat
            ;;
        apk)
            pkg_install curl wget socat ca-certificates
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

    mkdir -p /etc/trojan /var/log/trojan

    # Based on user selection, either download or compile
    if [[ "$CORE_INSTALL_MODE" == "download" ]]; then
        # Try to download pre-compiled binary first
        if download_precompiled_core; then
            return 0
        fi
        # If download fails, fall back to compilation
        log_warn "$(t CORE_DOWNLOAD_FAIL)"
        log_info "Falling back to source compilation..."
    fi

    # Compile from source
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

    # Handle IP certificate (ACME short-lived)
    if [[ "$CERT_TYPE" == "ip" ]]; then
        request_ip_certificate "$DOMAIN"
        return $?
    fi

    # Domain certificate via ACME
    local acme_sh=~/.acme.sh/acme.sh

    if [[ ! -f ~/.acme.sh/acme.sh ]]; then
        progress_update "Installing acme.sh..."
        curl -sS https://get.acme.sh | sh -s email="$EMAIL"
        source ~/.bashrc 2>/dev/null || true
    fi

    if [[ ! -f "$acme_sh" ]]; then
        acme_sh="$HOME/.acme.sh/acme.sh"
    fi

    # Configure acme.sh notify hook if enabled
    if [[ -n "$NOTIFY_HOOK" ]]; then
        progress_update "Configuring acme.sh notification hook: $NOTIFY_HOOK"

        # Set notify hook based on type
        case "$NOTIFY_HOOK" in
            telegram)
                # TELEGRAM_BOT_APITOKEN and TELEGRAM_BOT_CHATID should be set
                if [[ -n "$NOTIFY_TOKEN" ]] && [[ -n "$NOTIFY_CHAT" ]]; then
                    export TELEGRAM_BOT_APITOKEN="$NOTIFY_TOKEN"
                    export TELEGRAM_BOT_CHATID="$NOTIFY_CHAT"
                    $acme_sh --set-notify --notify-hook telegram --notify-level "$NOTIFY_LEVEL" 2>/dev/null || true
                fi
                ;;
            slack)
                # SLACK_WEBHOOK_URL should be set
                if [[ -n "$NOTIFY_TOKEN" ]]; then
                    export SLACK_WEBHOOK_URL="$NOTIFY_TOKEN"
                    $acme_sh --set-notify --notify-hook slack --notify-level "$NOTIFY_LEVEL" 2>/dev/null || true
                fi
                ;;
            dingtalk)
                # DINGTALK_WEBHOOK should be set
                if [[ -n "$NOTIFY_TOKEN" ]]; then
                    export DINGTALK_WEBHOOK="$NOTIFY_TOKEN"
                    $acme_sh --set-notify --notify-hook dingtalk --notify-level "$NOTIFY_LEVEL" 2>/dev/null || true
                fi
                ;;
            feishu)
                # FEISHU_WEBHOOK should be set
                if [[ -n "$NOTIFY_TOKEN" ]]; then
                    export FEISHU_WEBHOOK="$NOTIFY_TOKEN"
                    $acme_sh --set-notify --notify-hook feishu --notify-level "$NOTIFY_LEVEL" 2>/dev/null || true
                fi
                ;;
            bark)
                # BARK_API_URL and BARK_DEVICE_KEY should be set
                if [[ -n "$NOTIFY_TOKEN" ]]; then
                    export BARK_API_URL="${NOTIFY_SOURCE:-https://api.day.app}"
                    export BARK_DEVICE_KEY="$NOTIFY_TOKEN"
                    $acme_sh --set-notify --notify-hook bark --notify-level "$NOTIFY_LEVEL" 2>/dev/null || true
                fi
                ;;
            serverchan)
                # SERVERCHAN_SCKEY should be set
                if [[ -n "$NOTIFY_TOKEN" ]]; then
                    export SERVERCHAN_SCKEY="$NOTIFY_TOKEN"
                    $acme_sh --set-notify --notify-hook serverchan --notify-level "$NOTIFY_LEVEL" 2>/dev/null || true
                fi
                ;;
            pushover)
                # PUSHOVER_TOKEN and PUSHOVER_USER should be set
                if [[ -n "$NOTIFY_TOKEN" ]] && [[ -n "$NOTIFY_CHAT" ]]; then
                    export PUSHOVER_TOKEN="$NOTIFY_TOKEN"
                    export PUSHOVER_USER="$NOTIFY_CHAT"
                    $acme_sh --set-notify --notify-hook pushover --notify-level "$NOTIFY_LEVEL" 2>/dev/null || true
                fi
                ;;
            mailgun)
                # MAILGUN_API_KEY, MAILGUN_TO, MAILGUN_FROM, MAILGUN_REGION should be set
                if [[ -n "$NOTIFY_TOKEN" ]] && [[ -n "$NOTIFY_CHAT" ]]; then
                    export MAILGUN_API_KEY="$NOTIFY_TOKEN"
                    export MAILGUN_TO="$NOTIFY_CHAT"
                    export MAILGUN_FROM="${NOTIFY_SOURCE:-acme@$DOMAIN}"
                    $acme_sh --set-notify --notify-hook mailgun --notify-level "$NOTIFY_LEVEL" 2>/dev/null || true
                fi
                ;;
            sendgrid)
                # SENDGRID_API_KEY, SENDGRID_TO, SENDGRID_FROM should be set
                if [[ -n "$NOTIFY_TOKEN" ]] && [[ -n "$NOTIFY_CHAT" ]]; then
                    export SENDGRID_API_KEY="$NOTIFY_TOKEN"
                    export SENDGRID_TO="$NOTIFY_CHAT"
                    export SENDGRID_FROM="${NOTIFY_SOURCE:-acme@$DOMAIN}"
                    $acme_sh --set-notify --notify-hook sendgrid --notify-level "$NOTIFY_LEVEL" 2>/dev/null || true
                fi
                ;;
            *)
                # Generic webhook - user provides full URL
                if [[ -n "$NOTIFY_TOKEN" ]]; then
                    export WEBHOOK_URL="$NOTIFY_TOKEN"
                    $acme_sh --set-notify --notify-hook "$NOTIFY_HOOK" --notify-level "$NOTIFY_LEVEL" 2>/dev/null || true
                fi
                ;;
        esac
        log_info "$(t ACME_NOTIFY_CONFIGURED)"
    fi

    # Pre-check DNS and ports
    acme_pre_check "$DOMAIN"

    # Define CA list for fallback
    local ca_list=("$ACME_CA")
    # Add fallback CAs
    case "$ACME_CA" in
        letsencrypt) ca_list+=("buypass" "zerossl") ;;
        zerossl) ca_list+=("letsencrypt" "buypass") ;;
        buypass) ca_list+=("letsencrypt" "zerossl") ;;
    esac

    local cert_obtained=false
    local attempt=0

    for ca in "${ca_list[@]}"; do
        if [[ "$cert_obtained" == true ]]; then
            break
        fi

        ((attempt++)) || true
        progress_update "$(printf "$(t ACME_ISSUE)" "$ca")"

        # Set CA server
        local server_url=""
        case "$ca" in
            letsencrypt) server_url="letsencrypt" ;;
            zerossl) server_url="zerossl" ;;
            buypass) server_url="https://api.buypass.com/acme/directory" ;;
        esac

        # Register account
        progress_update "$(printf "$(t ACME_REGISTER)" "$ca")"
        $acme_sh --set-default-ca --server "$server_url" 2>/dev/null || true
        $acme_sh --register-account -m "$EMAIL" --server "$server_url" 2>/dev/null || true

        # Try to issue certificate with retry
        local retry=0
        while [[ $retry -lt $ACME_MAX_RETRY ]]; do
            ((retry++)) || true

            progress_update "$(t ACME_STANDALONE)"

            if $acme_sh --issue -d "$DOMAIN" --standalone --keylength ec-256 --server "$server_url" 2>&1; then
                cert_obtained=true
                progress_update "$(printf "$(t ACME_SUCCESS)" "$ca")"
                break
            fi

            # Check if cert already exists
            if [[ -f "$HOME/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key" ]] && [[ -f "$HOME/.acme.sh/${DOMAIN}_ecc/fullchain.cer" ]]; then
                log_info "Certificate already exists. Using existing certificate."
                cert_obtained=true
                break
            fi

            if [[ $retry -lt $ACME_MAX_RETRY ]]; then
                log_warn "$(printf "$(t CERT_RETRY)" "$retry" "$ACME_MAX_RETRY")"
                sleep 5
            fi
        done

        if [[ "$cert_obtained" != true ]] && [[ "$ca" != "${ca_list[-1]}" ]]; then
            local next_ca="${ca_list[$attempt]}"
            log_warn "$(printf "$(t CERT_RETRY_CA)" "$next_ca")"
        fi
    done

    if [[ "$cert_obtained" != true ]]; then
        log_error "$(t CERT_ALL_FAILED)"
        echo -e "${YELLOW}$(t CERT_CHECK_DNS)${NC}"
        echo -e "${YELLOW}$(t CERT_CHECK_PORT)${NC}"
        echo -e "${YELLOW}$(t CERT_CHECK_RATE)${NC}"
        exit 1
    fi

    # Install certificate
    mkdir -p /etc/trojan

    local reload_cmd=""
    if [[ -f "docker-compose.yml" ]]; then
        reload_cmd="docker restart trojan 2>/dev/null || true"
    else
        case $SM in
            systemd) reload_cmd="systemctl is-active --quiet trojan && systemctl reload trojan || true" ;;
            openrc) reload_cmd="rc-service trojan status >/dev/null 2>&1 && rc-service trojan reload || true" ;;
            *) reload_cmd="pkill -HUP trojan || true" ;;
        esac
    fi

    progress_update "$(t ACME_INSTALL)"
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
    # Save metadata for script usage
    echo "$PASSWORD" > /etc/trojan/.password
    chmod 600 /etc/trojan/.password
    
    # Ensure config allows read for service
    chmod 644 "$trojan_conf"
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

    # Select certificate type first (domain or IP)
    select_cert_type

    # Use CLI arguments if provided, otherwise prompt interactively
    if [[ "$CERT_TYPE" == "ip" ]]; then
        # IP certificate mode
        if [[ -n "$CLI_DOMAIN" ]]; then
            DOMAIN="$CLI_DOMAIN"
        else
            # Auto-detect server IP
            local detected_ip=$(curl -s4 ifconfig.co 2>/dev/null || curl -s4 ip.sb 2>/dev/null)
            echo ""
            if [[ -n "$detected_ip" ]]; then
                echo -e "Detected IP: ${GREEN}$detected_ip${NC}"
                read -r -p "$(t ENTER_IP) [$detected_ip]: " DOMAIN
                DOMAIN=${DOMAIN:-$detected_ip}
            else
                while [[ -z "$DOMAIN" ]]; do
                    read -r -p "$(t ENTER_IP) " DOMAIN
                    if ! validate_ip "$DOMAIN"; then
                        log_warn "$(t IP_INVALID)"
                        DOMAIN=""
                    fi
                done
            fi
        fi
        # Validate IP
        if ! validate_ip "$DOMAIN"; then
            log_error "$(t IP_INVALID)"
            return 1
        fi
    else
        # Domain certificate mode
        if [[ -n "$CLI_DOMAIN" ]]; then
            DOMAIN="$CLI_DOMAIN"
        else
            echo ""
            while [[ -z "$DOMAIN" ]]; do
                read -r -p "$(t ENTER_DOMAIN) " DOMAIN
                if [[ -z "$DOMAIN" ]]; then log_warn "$(t DOMAIN_EMPTY)"; fi
            done
        fi

        # Check domain IP (skip in auto mode or just warn)
        if [[ "$CLI_AUTO" != true ]]; then
            check_domain_ip "$DOMAIN"
        fi

        # Select CA for domain certificates
        select_acme_ca
    fi

    # Save domain for future use
    mkdir -p /etc/trojan
    echo "$DOMAIN" > /etc/trojan/.domain
    chmod 644 /etc/trojan/.domain

    # Email (only needed for domain certificates)
    if [[ "$CERT_TYPE" == "domain" ]]; then
        if [[ -n "$CLI_EMAIL" ]]; then
            EMAIL="$CLI_EMAIL"
        elif [[ "$CLI_AUTO" == true ]]; then
            EMAIL="admin@${DOMAIN}"
        else
            read -r -p "$(t ENTER_EMAIL) " EMAIL
            EMAIL=${EMAIL:-"admin@${DOMAIN}"}
        fi
    else
        EMAIL="admin@localhost"
    fi

    # Password
    if [[ -n "$CLI_PASSWORD" ]]; then
        PASSWORD="$CLI_PASSWORD"
    elif [[ "$CLI_AUTO" == true ]]; then
        # Auto mode: generate password
        if command -v openssl &>/dev/null; then
            PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
        else
            PASSWORD="trojan_$(date +%s)"
        fi
    else
        # Interactive mode: prompt user
        read -r -p "$(t ENTER_PWD) " PASSWORD
        if [[ -z "$PASSWORD" ]]; then
            if command -v openssl &>/dev/null; then
                PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
            else
                PASSWORD="trojan_$(date +%s)"
            fi
        fi
    fi

    # Installation mode
    if [[ -n "$CLI_MODE" ]]; then
        case "$CLI_MODE" in
            host) INSTALL_MODE="1" ;;
            docker) INSTALL_MODE="2" ;;
        esac
    elif [[ "$CLI_AUTO" == true ]]; then
        INSTALL_MODE="1"  # Default to host mode in auto
    else
        echo ""
        echo "$(t INSTALL_MODE_PROMPT)"
        echo -e "${GREEN}$(t MODE_HOST)${NC}"
        echo -e "${BLUE}$(t MODE_DOCKER)${NC}"
        read -r -p "Select [1-2] (1): " INSTALL_MODE
        INSTALL_MODE=${INSTALL_MODE:-1}
    fi

    # Core installation mode (for host mode only)
    if [[ "$INSTALL_MODE" == "1" ]]; then
        if [[ -n "$CLI_CORE_MODE" ]]; then
            CORE_INSTALL_MODE="$CLI_CORE_MODE"
        elif [[ "$CLI_AUTO" == true ]]; then
            CORE_INSTALL_MODE="download"  # Default to download in auto
        else
            select_core_install_mode
        fi
    fi

    # Configure notifications (optional)
    configure_notification

    # Show confirmation (skip in auto mode)
    if [[ "$CLI_AUTO" != true ]]; then
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                    $(t CONFIRM_CFG)                          ║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
        if [[ "$CERT_TYPE" == "ip" ]]; then
            echo -e "${CYAN}║${NC}  IP:         ${YELLOW}$DOMAIN${NC} (ACME short-lived)"
        else
            echo -e "${CYAN}║${NC}  $(t DOMAIN)      ${YELLOW}$DOMAIN${NC}"
            echo -e "${CYAN}║${NC}  $(t EMAIL)      ${YELLOW}$EMAIL${NC}"
            echo -e "${CYAN}║${NC}  CA:         ${YELLOW}$ACME_CA${NC}"
        fi
        echo -e "${CYAN}║${NC}  $(t PWD)      ${GREEN}$PASSWORD${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
        if [[ "$INSTALL_MODE" == "2" ]]; then
            echo -e "${CYAN}║${NC}  $(t INSTALL_MODE) ${BLUE}$(t MODE_DOCKER_CONTAINER)${NC}"
        else
            if [[ "$CORE_INSTALL_MODE" == "download" ]]; then
                echo -e "${CYAN}║${NC}  $(t INSTALL_MODE) ${GREEN}$(t MODE_HOST_DOWNLOAD)${NC}"
                echo -e "${CYAN}║${NC}               $(t QUICK_INSTALL)"
            else
                echo -e "${CYAN}║${NC}  $(t INSTALL_MODE) ${PURPLE}$(t MODE_HOST_COMPILE)${NC}"
                echo -e "${CYAN}║${NC}               $(t CUSTOM_BUILD)"
            fi
        fi
        if [[ "$NOTIFY_ENABLED" == true ]]; then
            echo -e "${CYAN}║${NC}  Notify:     ${GREEN}$NOTIFY_TYPE${NC}"
        fi
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        read -r -p "$(t CONFIRM_PROMPT) [Y/n] " confirm
        confirm=${confirm:-y}
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    configure_firewall

    # Initialize progress tracking
    if [[ "$INSTALL_MODE" == "2" ]]; then
        init_progress 6 "$(t STEP_DEPS)" "$(t STEP_TROJAN)" "$(t STEP_SSL)" "$(t STEP_CONFIG)" "$(t STEP_SERVICE)" "$(t STEP_VERIFY)"
    else
        init_progress 7 "$(t STEP_DEPS)" "$(t STEP_TROJAN)" "$(t STEP_CADDY)" "$(t STEP_SSL)" "$(t STEP_CONFIG)" "$(t STEP_BBR)" "$(t STEP_VERIFY)"
    fi

    log_info "$(t INSTALL_START)"

    if [[ "$INSTALL_MODE" == "2" ]]; then
        # Docker Mode
        show_step 1 start
        install_dependencies
        show_step 1 done

        show_step 2 start
        install_docker
        show_step 2 done

        show_step 3 start
        setup_ssl
        show_step 3 done

        show_step 4 start
        TROJAN_REMOTE_ADDR="127.0.0.1"
        configure_caddy_overload
        configure_trojan
        show_step 4 done

        show_step 5 start
        setup_docker_compose
        start_docker
        show_step 5 done

        show_step 6 start
        sleep 2  # Wait for services to start
        do_health_check || true  # Don't exit on health check failure
        show_step 6 done
    else
        # Host Mode
        show_step 1 start
        if [[ "$CORE_INSTALL_MODE" == "download" ]]; then
            install_minimal_dependencies
        else
            install_dependencies
        fi
        show_step 1 done

        show_step 2 start
        install_trojan
        show_step 2 done

        show_step 3 start
        install_caddy
        show_step 3 done

        show_step 4 start
        setup_ssl
        show_step 4 done

        show_step 5 start
        configure_caddy_overload
        configure_trojan
        setup_services_host
        show_step 5 done

        show_step 6 start
        enable_bbr || true  # BBR is optional, don't exit on failure
        show_step 6 done

        show_step 7 start
        sleep 2  # Wait for services to start
        do_health_check || true  # Don't exit on health check failure
        show_step 7 done
    fi

    # Auto backup after successful install
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/trojan_backup_initial.tar.gz"
    tar -czf "$backup_file" -C / etc/trojan/config.json etc/trojan/.domain etc/trojan/.password 2>/dev/null || true

    clear
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║           ✅  $(t SUCCESS_TITLE)                             ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━ $(t SERVER_INFO) ━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  🌐 Host:     ${YELLOW}$DOMAIN${NC}"
    echo -e "  🔌 Port:     ${YELLOW}443${NC}"
    echo -e "  🔑 Password: ${GREEN}$PASSWORD${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━ $(t TROJAN_LINK) ━━━━━━━━━━━━━━━━${NC}"
    echo ""
    TROJAN_URL=$(generate_trojan_url "$PASSWORD" "$DOMAIN")
    echo -e "  ${YELLOW}${TROJAN_URL}${NC}"
    echo ""
    echo -e "  $(t COPY_HINT)"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━ $(t USEFUL_CMDS) ━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  📊 $(t CMD_STATUS):   ${PURPLE}systemctl status trojan${NC}"
    echo -e "  📋 $(t CMD_LOGS):     ${PURPLE}journalctl -u trojan -f${NC}"
    echo -e "  🔄 $(t CMD_RESTART):  ${PURPLE}systemctl restart trojan${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  $(t NON_COMPLIANT)"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

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
    
    echo "------------------------------"
    echo "$(t CONN_CHECK)"
    if command -v openssl &>/dev/null; then
        # We try to connect to localhost 443 
        # Note: If docker, localhost might work if bound to host.
        # Use timeout to prevent hanging if Caddy accepts but waits (default 3s)
        local timeout_cmd=""
        if command -v timeout &>/dev/null; then timeout_cmd="timeout 3"; fi
        
        local check_out
        check_out=$(echo "Q" | $timeout_cmd openssl s_client -connect 127.0.0.1:443 -servername "$DOMAIN" 2>&1)
        local check_ret=$?
        
        if [[ $check_ret -eq 0 ]]; then
             echo -e "${GREEN}$(t CONN_OK)${NC}"
        else
             echo -e "${RED}$(t CONN_FAIL)${NC}"
             echo -e "Debug Info:"
             echo "$check_out" | grep -iE "error|errno|fail|refused|timeout" | head -n 3
             
             echo -e "\nPort 443 Status:"
             if command -v ss &>/dev/null; then ss -tuln | grep :443;
             elif command -v netstat &>/dev/null; then netstat -tuln | grep :443; fi
             
             echo -e "\nCertificate Check:"
             ls -lh /etc/trojan/server.crt /etc/trojan/server.key 2>/dev/null
        fi
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
             if [[ -f "/etc/trojan/.domain" ]]; then
                 DOMAIN=$(cat /etc/trojan/.domain)
             elif [[ -f "/etc/trojan/config.json" ]]; then
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
    echo ""
    echo "Trojan Config Information:"
    echo "----------------------------------------"
    
    local domain=""
    local password=""
    
    # Try to read from metadata files first
    if [[ -f "/etc/trojan/.domain" ]]; then
        domain=$(cat /etc/trojan/.domain)
    fi
    
    if [[ -f "/etc/trojan/.password" ]]; then
        password=$(cat /etc/trojan/.password)
    fi
    
    # Fallback to config.json parsing if metadata missing
    if [[ -z "$password" ]] && [[ -f "/etc/trojan/config.json" ]]; then
        # Crude extraction for "password": [ "value" ]
        password=$(grep -A 1 '"password"' /etc/trojan/config.json | tail -n 1 | cut -d'"' -f2)
    fi
    
    if [[ -z "$domain" ]]; then
        echo -e "${RED}Domain not found (deployment might be incomplete).${NC}"
    else
        echo -e "Domain:   ${GREEN}${domain}${NC}"
    fi
    
    if [[ -z "$password" ]]; then
         echo -e "${RED}Password not found.${NC}"
    else
        echo -e "Password: ${GREEN}${password}${NC}"
    fi
    
    echo -e "Port:     ${GREEN}443${NC}"
    
    if [[ -n "$domain" ]] && [[ -n "$password" ]]; then
        echo ""
        echo -e "${YELLOW}Trojan URL:${NC}"
        generate_trojan_url "$password" "$domain"
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
        detect_os

        log_info "Stopping services..."

        if [[ -f "docker-compose.yml" ]]; then
            if docker compose version &>/dev/null; then docker compose down; else docker-compose down; fi
            rm -f docker-compose.yml
        else
            # Stop services first
            svc_stop trojan
            svc_stop caddy

            # Disable services
            svc_disable trojan
            svc_disable caddy

            # Remove systemd service files
            if [[ "$SM" == "systemd" ]]; then
                rm -f /etc/systemd/system/trojan.service
                systemctl daemon-reload
            elif [[ "$SM" == "openrc" ]]; then
                rm -f /etc/init.d/trojan
            fi
        fi

        # Force kill any remaining trojan processes
        log_info "Killing remaining processes..."
        pkill -9 -f "/usr/local/bin/trojan" 2>/dev/null || true
        pkill -9 -x "trojan" 2>/dev/null || true

        # Remove binary
        log_info "Removing binary..."
        rm -f /usr/local/bin/trojan

        # Remove config directories
        log_info "Removing configuration..."
        rm -rf /etc/trojan
        rm -rf /etc/caddy

        # Remove log directory
        log_info "Removing logs..."
        rm -rf /var/log/trojan

        # Remove acme.sh certs for the domain (optional)
        if [[ -f /etc/trojan/.domain ]]; then
            local domain=$(cat /etc/trojan/.domain 2>/dev/null)
            if [[ -n "$domain" ]] && [[ -d ~/.acme.sh/${domain}_ecc ]]; then
                read -r -p "Remove SSL certificates for ${domain}? [y/N]: " rm_cert
                if [[ "$rm_cert" =~ ^[Yy]$ ]]; then
                    ~/.acme.sh/acme.sh --remove -d "$domain" --ecc 2>/dev/null || true
                    rm -rf ~/.acme.sh/${domain}_ecc
                fi
            fi
        fi

        # Verify cleanup
        echo ""
        if pgrep -x "trojan" >/dev/null 2>&1; then
            log_warn "Warning: trojan process still running!"
            log_info "Try: kill -9 \$(pgrep -x trojan)"
        else
            log_info "✓ All trojan processes terminated"
        fi

        if [[ -f /usr/local/bin/trojan ]]; then
            log_warn "Warning: Binary still exists!"
        else
            log_info "✓ Binary removed"
        fi

        if [[ -d /etc/trojan ]]; then
            log_warn "Warning: Config directory still exists!"
        else
            log_info "✓ Config removed"
        fi

        echo ""
        echo -e "${GREEN}$(t UNINSTALL_DONE)${NC}"
    fi
    pause
}

# ==================== BBR Optimization ====================
enable_bbr() {
    log_info "$(t STEP_BBR)"

    # Check if BBR is already enabled
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then
        progress_update "$(t BBR_ALREADY)"
        return 0
    fi

    # Check kernel version (BBR requires >= 4.9)
    local kernel_version=$(uname -r | cut -d. -f1-2)
    local major=$(echo "$kernel_version" | cut -d. -f1)
    local minor=$(echo "$kernel_version" | cut -d. -f2)

    if [[ $major -lt 4 ]] || { [[ $major -eq 4 ]] && [[ $minor -lt 9 ]]; }; then
        log_warn "$(t BBR_FAILED) (kernel $kernel_version < 4.9)"
        return 1
    fi

    # Check if BBR module is available
    if ! modprobe tcp_bbr 2>/dev/null; then
        log_warn "$(t BBR_FAILED)"
        return 1
    fi

    # Enable BBR
    cat >> /etc/sysctl.conf << EOF

# BBR congestion control (added by trojan deploy script)
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl -p &>/dev/null

    # Verify
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then
        progress_update "$(t BBR_ENABLED)"
        return 0
    else
        log_warn "$(t BBR_FAILED)"
        return 1
    fi
}

# ==================== Health Check ====================
do_health_check() {
    log_info "$(t HEALTH_CHECK)"
    local all_ok=true

    # Read domain
    local domain=""
    if [[ -f "/etc/trojan/.domain" ]]; then
        domain=$(cat /etc/trojan/.domain)
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━ Health Check ━━━━━━━━━━━━━━━━${NC}"

    # 1. Check Trojan process
    echo -n "  Trojan process: "
    if pgrep -x "trojan" >/dev/null 2>&1 || pgrep -f "/usr/local/bin/trojan" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Not running${NC}"
        all_ok=false
    fi

    # 2. Check Caddy process
    echo -n "  Caddy process:  "
    if pgrep -x "caddy" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Not running${NC}"
        all_ok=false
    fi

    # 3. Check port 443
    echo -n "  Port 443:       "
    if ss -tuln 2>/dev/null | grep -q ":443 " || netstat -tuln 2>/dev/null | grep -q ":443 "; then
        echo -e "${GREEN}✓ Listening${NC}"
    else
        echo -e "${RED}✗ Not listening${NC}"
        all_ok=false
    fi

    # 4. Check port 8080 (Caddy backend)
    echo -n "  Port 8080:      "
    if ss -tuln 2>/dev/null | grep -q ":8080 " || netstat -tuln 2>/dev/null | grep -q ":8080 "; then
        echo -e "${GREEN}✓ Listening${NC}"
    else
        echo -e "${RED}✗ Not listening${NC}"
        all_ok=false
    fi

    # 5. Check SSL certificate
    echo -n "  SSL cert:       "
    if [[ -f "/etc/trojan/server.crt" ]] && [[ -f "/etc/trojan/server.key" ]]; then
        # Check expiry
        local expiry=$(openssl x509 -enddate -noout -in /etc/trojan/server.crt 2>/dev/null | cut -d= -f2)
        if [[ -n "$expiry" ]]; then
            local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null)
            local now_epoch=$(date +%s)
            local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
            if [[ $days_left -gt 7 ]]; then
                echo -e "${GREEN}✓ Valid ($days_left days left)${NC}"
            elif [[ $days_left -gt 0 ]]; then
                echo -e "${YELLOW}⚠ Expiring soon ($days_left days)${NC}"
            else
                echo -e "${RED}✗ Expired${NC}"
                all_ok=false
            fi
        else
            echo -e "${GREEN}✓ Present${NC}"
        fi
    else
        echo -e "${RED}✗ Missing${NC}"
        all_ok=false
    fi

    # 6. Check config file
    echo -n "  Config file:    "
    if [[ -f "/etc/trojan/config.json" ]]; then
        echo -e "${GREEN}✓ Present${NC}"
    else
        echo -e "${RED}✗ Missing${NC}"
        all_ok=false
    fi

    # 7. TLS handshake test
    echo -n "  TLS handshake:  "
    if [[ -n "$domain" ]] && command -v openssl &>/dev/null; then
        local timeout_cmd=""
        if command -v timeout &>/dev/null; then timeout_cmd="timeout 5"; fi

        if echo "Q" | $timeout_cmd openssl s_client -connect 127.0.0.1:443 -servername "$domain" 2>&1 | grep -q "CONNECTED"; then
            echo -e "${GREEN}✓ OK${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
            all_ok=false
        fi
    else
        echo -e "${YELLOW}⚠ Skipped${NC}"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [[ "$all_ok" == true ]]; then
        echo -e "${GREEN}$(t HEALTH_OK)${NC}"
        return 0
    else
        echo -e "${RED}$(t HEALTH_FAIL)${NC}"
        return 1
    fi
}

# ==================== Update Core ====================
do_update_core() {
    log_info "$(t UPDATE_CHECK)"

    # Get current version
    local current_version="unknown"
    if command -v /usr/local/bin/trojan &>/dev/null; then
        current_version=$(/usr/local/bin/trojan --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    fi

    # Get latest version
    local release_info
    release_info=$(curl -sL "$RELEASE_API_URL" 2>/dev/null)

    if [[ -z "$release_info" ]] || echo "$release_info" | grep -q "Not Found"; then
        log_error "Failed to check for updates"
        pause
        return 1
    fi

    local latest_version
    latest_version=$(echo "$release_info" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')

    echo ""
    echo -e "$(t UPDATE_CURRENT) ${YELLOW}$current_version${NC}"
    echo -e "$(t UPDATE_AVAILABLE) ${GREEN}$latest_version${NC}"
    echo ""

    if [[ "$current_version" == "$latest_version" ]]; then
        log_info "$(t UPDATE_LATEST)"
        pause
        return 0
    fi

    if [[ "$CLI_AUTO" != true ]]; then
        read -r -p "$(t UPDATE_CONFIRM) [Y/n] " confirm
        confirm=${confirm:-y}
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    # Backup current binary
    if [[ -f /usr/local/bin/trojan ]]; then
        cp /usr/local/bin/trojan /usr/local/bin/trojan.bak
    fi

    # Stop service
    detect_os
    svc_stop trojan

    # Download new version
    CORE_INSTALL_MODE="download"
    if download_precompiled_core; then
        log_info "$(t UPDATE_SUCCESS)"
        svc_start trojan
        rm -f /usr/local/bin/trojan.bak
    else
        # Restore backup
        if [[ -f /usr/local/bin/trojan.bak ]]; then
            mv /usr/local/bin/trojan.bak /usr/local/bin/trojan
        fi
        log_error "Update failed, restored previous version"
        svc_start trojan
    fi

    pause
}

# ==================== Backup Configuration ====================
do_backup() {
    mkdir -p "$BACKUP_DIR"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/trojan_backup_$timestamp.tar.gz"

    log_info "Creating backup..."

    # Create backup
    tar -czf "$backup_file" \
        -C / \
        etc/trojan/config.json \
        etc/trojan/.domain \
        etc/trojan/.password \
        etc/trojan/server.crt \
        etc/trojan/server.key \
        etc/caddy/Caddyfile \
        2>/dev/null || true

    if [[ -f "$backup_file" ]]; then
        local size=$(du -h "$backup_file" | cut -f1)
        echo ""
        echo -e "${GREEN}$(t BACKUP_CREATED)${NC}"
        echo -e "  File: ${YELLOW}$backup_file${NC}"
        echo -e "  Size: ${YELLOW}$size${NC}"

        # List recent backups
        echo ""
        echo -e "${CYAN}$(t BACKUP_LIST)${NC}"
        ls -lht "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -5 | while read line; do
            echo "  $line"
        done
    else
        log_error "Backup failed"
    fi

    pause
}

do_restore() {
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A $BACKUP_DIR/*.tar.gz 2>/dev/null)" ]]; then
        log_error "No backups found in $BACKUP_DIR"
        pause
        return 1
    fi

    echo ""
    echo -e "${CYAN}$(t BACKUP_LIST)${NC}"

    local backups=()
    local i=1
    for f in $(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null); do
        backups+=("$f")
        local size=$(du -h "$f" | cut -f1)
        local date=$(basename "$f" | grep -oE '[0-9]{8}_[0-9]{6}')
        echo -e "  ${CYAN}$i)${NC} $date ($size)"
        ((i++)) || true
    done

    echo ""
    read -r -p "$(t RESTORE_SELECT) [1-$((i-1))]: " choice

    if [[ -z "$choice" ]] || [[ $choice -lt 1 ]] || [[ $choice -gt $((i-1)) ]]; then
        log_error "Invalid selection"
        pause
        return 1
    fi

    local selected_backup="${backups[$((choice-1))]}"

    # Stop services
    detect_os
    svc_stop trojan
    svc_stop caddy

    # Restore
    log_info "Restoring from $selected_backup..."
    tar -xzf "$selected_backup" -C / 2>/dev/null

    # Restart services
    svc_start caddy
    svc_start trojan

    echo -e "${GREEN}$(t RESTORE_SUCCESS)${NC}"
    pause
}

# ==================== Multi-user/Password Management ====================
do_manage_users() {
    while true; do
        clear
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━ $(t MENU_USERS) ━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Read current passwords from config
        local config_file="/etc/trojan/config.json"
        if [[ ! -f "$config_file" ]]; then
            log_error "Config file not found. Please install first."
            pause
            return
        fi

        # Extract passwords array
        echo -e "${YELLOW}$(t USERS_CURRENT)${NC}"
        local passwords=$(grep -A 100 '"password"' "$config_file" | grep -oE '"[^"]+' | grep -v "password" | tr -d '"' | head -20)
        local i=1
        while IFS= read -r pwd; do
            if [[ -n "$pwd" ]] && [[ "$pwd" != "[" ]] && [[ "$pwd" != "]" ]]; then
                echo -e "  ${CYAN}$i)${NC} $pwd"
                ((i++)) || true
            fi
        done <<< "$passwords"

        echo ""
        echo -e "${CYAN}a)${NC} $(t USERS_ADD)"
        echo -e "${CYAN}r)${NC} $(t USERS_REMOVE)"
        echo -e "${CYAN}b)${NC} $(t USERS_BACK)"
        echo ""
        read -r -p "Select: " action

        case "$action" in
            a|A)
                echo ""
                read -r -p "Enter new password (leave empty to generate): " new_pwd
                if [[ -z "$new_pwd" ]]; then
                    if command -v openssl &>/dev/null; then
                        new_pwd=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
                    else
                        new_pwd="user_$(date +%s)"
                    fi
                fi

                # Add password to config using jq if available, otherwise sed
                if command -v jq &>/dev/null; then
                    local tmp_file=$(mktemp)
                    jq ".password += [\"$new_pwd\"]" "$config_file" > "$tmp_file"
                    mv "$tmp_file" "$config_file"
                    chmod 644 "$config_file"
                else
                    # Fallback: manual JSON manipulation using printf for newline
                    local newline=$'\n'
                    sed -i.bak "s/\"password\": \[/\"password\": [${newline}        \"$new_pwd\",/" "$config_file"
                fi

                # Also update .password file with all passwords
                grep -A 100 '"password"' "$config_file" | grep -oE '"[^"]+' | grep -v "password" | tr -d '"' | head -20 > /etc/trojan/.password

                echo -e "${GREEN}Password added: $new_pwd${NC}"

                # Reload service
                detect_os
                svc_restart trojan
                sleep 1
                ;;
            r|R)
                echo ""
                read -r -p "Enter password number to remove: " num
                if [[ -n "$num" ]] && [[ $num -ge 1 ]]; then
                    local pwd_to_remove=$(echo "$passwords" | sed -n "${num}p")
                    if [[ -n "$pwd_to_remove" ]]; then
                        if command -v jq &>/dev/null; then
                            local tmp_file=$(mktemp)
                            jq "del(.password[] | select(. == \"$pwd_to_remove\"))" "$config_file" > "$tmp_file"
                            mv "$tmp_file" "$config_file"
                            chmod 644 "$config_file"
                        else
                            sed -i.bak "/\"$pwd_to_remove\"/d" "$config_file"
                        fi

                        # Update .password file
                        grep -A 100 '"password"' "$config_file" | grep -oE '"[^"]+' | grep -v "password" | tr -d '"' | head -20 > /etc/trojan/.password

                        echo -e "${GREEN}Password removed${NC}"

                        # Reload service
                        detect_os
                        svc_restart trojan
                        sleep 1
                    fi
                fi
                ;;
            b|B)
                return
                ;;
        esac
    done
}

# ==================== Command-line Argument Parsing ====================
show_usage() {
    echo "Usage: $0 [OPTIONS] [ACTION]"
    echo ""
    echo "Actions:"
    echo "  install       Install Trojan + Caddy"
    echo "  status        Check service status"
    echo "  uninstall     Remove installation"
    echo "  update        Update Trojan core"
    echo "  backup        Backup configuration"
    echo "  restore       Restore configuration"
    echo "  users         Manage users/passwords"
    echo ""
    echo "Options:"
    echo "  -d, --domain DOMAIN       Domain name (required for install)"
    echo "  -e, --email EMAIL         Email for SSL certificate"
    echo "  -p, --password PASSWORD   Connection password (auto-generated if not set)"
    echo "  -m, --mode MODE           Installation mode: host or docker (default: host)"
    echo "  -c, --core MODE           Core install method: download or compile (default: download)"
    echo "  -l, --lang LANG           Language: en or cn (default: cn)"
    echo "  -y, --auto                Non-interactive mode (requires --domain)"
    echo "  --cert-type TYPE          Certificate type: domain or ip (default: domain)"
    echo "  --acme-ca CA              ACME CA: letsencrypt, zerossl, buypass (default: letsencrypt)"
    echo ""
    echo "ACME Notification Options (acme.sh built-in hooks):"
    echo "  --notify-hook HOOK        Notification hook: telegram, dingtalk, feishu, slack, bark, serverchan, mailgun, sendgrid"
    echo "  --notify-level LEVEL      Notification level: 1=error, 2=error+renew, 3=all (default: 2)"
    echo "  --notify-token TOKEN      Hook-specific token/key/webhook URL"
    echo "  --notify-chat ID          Hook-specific chat/channel ID (for telegram, pushover)"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Interactive installation"
    echo "  $0"
    echo ""
    echo "  # Non-interactive installation with domain"
    echo "  $0 install --domain example.com --email admin@example.com --auto"
    echo ""
    echo "  # Installation with IP certificate (Let's Encrypt short-lived)"
    echo "  $0 install --cert-type ip --domain 1.2.3.4 --auto"
    echo ""
    echo "  # Installation with Telegram notification (acme.sh built-in)"
    echo "  $0 install --domain example.com --notify-hook telegram --notify-token BOT_TOKEN --notify-chat CHAT_ID --auto"
    echo ""
    echo "  # Installation with DingTalk notification"
    echo "  $0 install --domain example.com --notify-hook dingtalk --notify-token 'https://oapi.dingtalk.com/robot/send?access_token=xxx' --auto"
    echo ""
    echo "  # Installation with Slack notification"
    echo "  $0 install --domain example.com --notify-hook slack --notify-token 'https://hooks.slack.com/services/xxx' --auto"
    echo ""
    echo "  # Update core only"
    echo "  $0 update"
    echo ""
    echo "  # Backup configuration"
    echo "  $0 backup"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--domain)
                CLI_DOMAIN="$2"
                shift 2
                ;;
            -e|--email)
                CLI_EMAIL="$2"
                shift 2
                ;;
            -p|--password)
                CLI_PASSWORD="$2"
                shift 2
                ;;
            -m|--mode)
                case "$2" in
                    host|1) CLI_MODE="host" ;;
                    docker|2) CLI_MODE="docker" ;;
                    *) log_error "Invalid mode: $2"; exit 1 ;;
                esac
                shift 2
                ;;
            -c|--core)
                case "$2" in
                    download|1) CLI_CORE_MODE="download" ;;
                    compile|2) CLI_CORE_MODE="compile" ;;
                    *) log_error "Invalid core mode: $2"; exit 1 ;;
                esac
                shift 2
                ;;
            -l|--lang)
                case "$2" in
                    en|1) LANG_CUR="en"; LANG_CUR_SET=1 ;;
                    cn|zh|2) LANG_CUR="cn"; LANG_CUR_SET=1 ;;
                    *) log_error "Invalid language: $2"; exit 1 ;;
                esac
                shift 2
                ;;
            -y|--auto|--yes)
                CLI_AUTO=true
                shift
                ;;
            --cert-type)
                case "$2" in
                    domain|1) CLI_CERT_TYPE="domain" ;;
                    ip|2) CLI_CERT_TYPE="ip" ;;
                    *) log_error "Invalid cert type: $2"; exit 1 ;;
                esac
                shift 2
                ;;
            --acme-ca)
                case "$2" in
                    letsencrypt|le) CLI_ACME_CA="letsencrypt" ;;
                    zerossl|zs) CLI_ACME_CA="zerossl" ;;
                    buypass|bp) CLI_ACME_CA="buypass" ;;
                    *) log_error "Invalid CA: $2"; exit 1 ;;
                esac
                shift 2
                ;;
            --notify-hook)
                CLI_NOTIFY_HOOK="$2"
                shift 2
                ;;
            --notify-level)
                CLI_NOTIFY_MODE="$2"
                shift 2
                ;;
            --notify-token)
                CLI_NOTIFY_TOKEN="$2"
                shift 2
                ;;
            --notify-chat)
                CLI_NOTIFY_CHAT="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            install|status|uninstall|update|backup|restore|users)
                CLI_ACTION="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Validate auto mode requirements
    if [[ "$CLI_AUTO" == true ]] && [[ "$CLI_ACTION" == "install" ]] && [[ -z "$CLI_DOMAIN" ]]; then
        log_error "Non-interactive mode requires --domain"
        exit 1
    fi
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
    echo -e "${CYAN}6.${NC} $(t MENU_UPDATE)"
    echo -e "${CYAN}7.${NC} $(t MENU_USERS)"
    echo -e "${CYAN}8.${NC} $(t MENU_BACKUP)"
    echo -e "${CYAN}9.${NC} $(t MENU_RESTORE)"
    echo -e "${CYAN}u.${NC} $(t MENU_UNINSTALL)"
    echo -e "${CYAN}0.${NC} $(t MENU_EXIT)"

    echo -e "\n${BLUE}Tip: Run via one-click:${NC} ${YELLOW}bash <(curl -sL ${REPO_URL/github.com/raw.githubusercontent.com}/$REPO_BRANCH/install.sh)${NC}"
    echo -e "${BLUE}CLI mode:${NC} ${YELLOW}$0 --help${NC}"
    echo ""
    read -r -p "Select [0-9,u]: " choice

    case $choice in
        1) do_install ;;
        2) do_status ;;
        3) do_config ;;
        4) do_logs ;;
        5) do_renew_cert ;;
        6) do_update_core ;;
        7) do_manage_users ;;
        8) do_backup ;;
        9) do_restore ;;
        u|U) do_uninstall ;;
        0) exit 0 ;;
        *) echo "Invalid choice"; sleep 1 ;;
    esac
}

main() {
    check_root
    setup_languages

    # Parse command-line arguments
    parse_arguments "$@"

    # If language not set via CLI, ask interactively (unless auto mode)
    if [[ "$CLI_AUTO" != true ]]; then
        select_language
    else
        # Default to Chinese in auto mode if not set
        LANG_CUR=${LANG_CUR:-cn}
    fi

    # Handle CLI action if specified
    if [[ -n "$CLI_ACTION" ]]; then
        case "$CLI_ACTION" in
            install)
                do_install
                ;;
            status)
                do_status
                ;;
            uninstall)
                do_uninstall
                ;;
            update)
                do_update_core
                ;;
            backup)
                do_backup
                ;;
            restore)
                do_restore
                ;;
            users)
                do_manage_users
                ;;
            *)
                log_error "Unknown action: $CLI_ACTION"
                exit 1
                ;;
        esac
        exit 0
    fi

    # Interactive mode
    while true; do
        show_menu
    done
}

main "$@"
