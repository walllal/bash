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

header "[4] 配置 TCP BBR 拥塞控制"

KERNEL_MAJOR=$(uname -r | cut -d. -f1)
KERNEL_MINOR=$(uname -r | cut -d. -f2)
if [[ "$KERNEL_MAJOR" -lt 4 ]] || { [[ "$KERNEL_MAJOR" -eq 4 ]] && [[ "$KERNEL_MINOR" -lt 9 ]]; }; then
    error "内核版本 $(uname -r) 过低，BBR 需要 4.9+，请先升级内核"
    exit 1
fi

CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
if [[ "$CURRENT_CC" == "bbr" ]]; then
    warn "BBR 当前已在运行，无需重复配置"
    info "当前拥塞算法: $CURRENT_CC | 队列算法: $(sysctl -n net.core.default_qdisc)"
    exit 0
fi

info "正在开启 BBR (当前算法: $CURRENT_CC)..."

grep -q "^net.core.default_qdisc" /etc/sysctl.conf || \
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
grep -q "^net.ipv4.tcp_congestion_control" /etc/sysctl.conf || \
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

sysctl -p &>/dev/null

NEW_CC=$(sysctl -n net.ipv4.tcp_congestion_control)
if [[ "$NEW_CC" == "bbr" ]]; then
    success "TCP BBR 已成功开启"
    info "当前拥塞算法: $NEW_CC | 队列算法: $(sysctl -n net.core.default_qdisc)"
else
    error "BBR 开启失败，当前算法仍为: $NEW_CC"
    exit 1
fi
