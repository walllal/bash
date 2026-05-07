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

header "[6] 配置服务器主机名"
echo -e "当前主机名: ${GREEN}$(hostname)${PLAIN}"
read -rp "请输入新主机名 (直接回车跳过): " new_hostname

if [[ -z "$new_hostname" ]]; then
    warn "已跳过主机名配置"; exit 0
fi

if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
    error "主机名格式无效，只允许字母、数字和连字符，且不能以连字符开头/结尾"
    exit 1
fi

hostnamectl set-hostname "$new_hostname"

if grep -q "^127.0.1.1" /etc/hosts; then
    sed -i "s/^127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
else
    echo -e "127.0.1.1\t$new_hostname" >> /etc/hosts
fi

success "主机名已更新为: $new_hostname"
