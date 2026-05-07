#!/bin/bash
[[ $EUID -ne 0 ]] && echo -e "\033[0;31m[ERROR]\033[0m 必须使用 root 用户运行！" && exit 1
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; PLAIN='\033[0m'; BOLD='\033[1m'
function print_line() { echo -e "${BLUE}-------------------------------------------------------------${PLAIN}"; }
function info()    { echo -e "${BLUE}[INFO]${PLAIN}    $1"; }
function success() { echo -e "${GREEN}[OK]${PLAIN}      $1"; }
function warn()    { echo -e "${YELLOW}[WARN]${PLAIN}    $1"; }
function error()   { echo -e "${RED}[ERROR]${PLAIN}   $1"; }
function header()  { echo -e ""; print_line; echo -e "${PURPLE}${BOLD}  $1${PLAIN}"; print_line; }

header "[2] 安装基础软件包"
info "正在更新软件包列表..."
apt update -y

PACKAGES=(
    build-essential
    curl wget net-tools dnsutils nethogs
    git vim nano unzip zip rsync
    htop iotop lsof ncdu tree tmux
    ca-certificates gnupg apt-transport-https
    sudo jq bc
)

info "正在安装软件包: ${PACKAGES[*]}"
apt install -y "${PACKAGES[@]}"
success "基础系统工具安装完成"
