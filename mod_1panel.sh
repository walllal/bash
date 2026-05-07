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

BASE_URL="https://raw.githubusercontent.com/walllal/bash/refs/heads/main"

header "[9] 安装 1Panel 面板"

if ! command -v docker &>/dev/null; then
    warn "前置依赖 Docker 未找到，即将先安装 Docker..."
    bash <(curl -sL "${BASE_URL}/mod_docker.sh") || {
        error "Docker 安装失败，无法继续安装 1Panel"
        exit 1
    }
fi

info "启动 1Panel 官方安装脚本..."
bash <(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)
