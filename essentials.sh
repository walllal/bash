#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; PLAIN='\033[0m'; BOLD='\033[1m'
function info()    { echo -e "${BLUE}[INFO]${PLAIN}  $1"; }
function success() { echo -e "${GREEN}[OK]${PLAIN}    $1"; }
function warn()    { echo -e "${YELLOW}[WARN]${PLAIN}  $1"; }
function error()   { echo -e "${RED}[ERROR]${PLAIN} $1"; }
STATE_DIR="/etc/server-init/state"; mkdir -p "$STATE_DIR"

PACKAGES=(
    build-essential curl wget git vim nano
    unzip zip rsync net-tools dnsutils nethogs
    htop iotop lsof ncdu tree tmux
    ca-certificates gnupg apt-transport-https
    sudo jq bc
)

function do_install() {
    echo -e "\n${PURPLE}${BOLD}  安装基础软件包${PLAIN}"
    echo -e "-------------------------------------------------------------"
    apt update -y
    apt install -y "${PACKAGES[@]}"
    echo "${PACKAGES[*]}" > "$STATE_DIR/essentials_packages.txt"
    success "基础工具安装完成"
}

function do_reset() {
    echo -e "\n${RED}${BOLD}  [重置] 卸载基础软件包${PLAIN}"
    echo -e "-------------------------------------------------------------"
    warn "即将卸载: ${PACKAGES[*]}"
    read -rp "确认卸载? (y/n): " c; [[ "$c" != "y" ]] && return
    apt remove -y "${PACKAGES[@]}" && apt autoremove -y
    rm -f "$STATE_DIR/essentials_packages.txt"
    success "基础软件包已卸载"
}

[[ "$1" == "--reset" ]] && do_reset || do_install
