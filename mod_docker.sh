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

header "[8] 安装 Docker 环境"

if command -v docker &>/dev/null; then
    warn "Docker 已安装，当前版本: $(docker --version)"
    exit 0
fi

info "正在通过 LinuxMirrors 安装 Docker..."
bash <(curl -sSL https://linuxmirrors.cn/docker.sh)

if command -v docker &>/dev/null; then
    systemctl enable docker &>/dev/null
    systemctl start docker &>/dev/null
    success "Docker 安装成功: $(docker --version)"
else
    error "Docker 安装未成功，请手动检查"
    exit 1
fi
