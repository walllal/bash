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

header "[7] 内核网络参数优化"

SYSCTL_CONF="/etc/sysctl.d/99-server-optimize.conf"

if [[ -f "$SYSCTL_CONF" ]]; then
    warn "优化配置文件已存在: $SYSCTL_CONF"
    read -rp "是否覆盖重新配置? (y/n): " overwrite
    [[ "$overwrite" != "y" ]] && exit 0
fi

info "正在写入内核优化参数..."

cat > "$SYSCTL_CONF" << 'EOF'
# ============================================================
#  服务器内核参数优化
# ============================================================

# --- 网络性能 ---
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 250000
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 8192
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_max_tw_buckets = 20000
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 3

# --- 安全防护 ---
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# --- 文件描述符 ---
fs.file-max = 1000000
fs.nr_open = 1000000

# --- 内存管理 ---
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF

sysctl --system &>/dev/null
success "内核参数优化完成，配置文件: $SYSCTL_CONF"
