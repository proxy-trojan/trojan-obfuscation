#!/bin/bash
# Trojan-Pro One-Click Installer
# Suitable for consumption via curl/wget
# Usage: bash <(curl -sL https://raw.githubusercontent.com/proxy-trojan/trojan-obfuscation/main/install.sh)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Repo Information
REPO_URL="https://github.com/proxy-trojan/trojan-obfuscation/archive/refs/heads/main.zip"
# Note: Update this URL if the branch is different

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root.${NC}"
        exit 1
    fi
}

install_deps() {
    echo -e "${GREEN}Installing downloader dependencies...${NC}"
    if command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq wget unzip curl >/dev/null
    elif command -v yum &>/dev/null; then
        yum install -y wget unzip curl >/dev/null
    elif command -v apk &>/dev/null; then
        apk add wget unzip curl >/dev/null
    fi
}

main() {
    check_root

    # Scenario 1: Running locally from within the repo
    if [[ -f "scripts/deploy_caddy_trojan.sh" ]]; then
        chmod +x scripts/deploy_caddy_trojan.sh
        bash scripts/deploy_caddy_trojan.sh
        exit 0
    fi

    # Scenario 2: Remote execution (curl | bash)
    install_deps
    
    WORKDIR="/usr/local/src/trojan-install-$(date +%s)"
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
    
    echo -e "${GREEN}Downloading Trojan-Pro from GitHub...${NC}"
    
    if wget -qO repo.zip "$REPO_URL"; then
        :
    else
        echo -e "${RED}Download failed. Please check your network or the repository URL.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Extracting...${NC}"
    unzip -q repo.zip
    
    # Enter the extracted directory (usually trojan-pro-main)
    DIR_NAME=$(ls -d */ | head -n 1)
    if [[ -z "$DIR_NAME" ]]; then
        echo -e "${RED}Extraction failed or empty archive.${NC}"
        exit 1
    fi
    
    cd "$DIR_NAME"
    
    if [[ ! -f "scripts/deploy_caddy_trojan.sh" ]]; then
        echo -e "${RED}Deployment script not found in the downloaded archive.${NC}"
        echo "Looking in: $(pwd)"
        exit 1
    fi
    
    echo -e "${GREEN}Starting deployment script...${NC}"
    chmod +x scripts/deploy_caddy_trojan.sh
    bash scripts/deploy_caddy_trojan.sh
}

main "$@"
