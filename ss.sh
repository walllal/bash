#!/bin/bash

# ==============================================================
#  Linux Server Initialization Script (Ultimate Edition v8)
#  Author: Optimized Edition
#  System: Debian / Ubuntu
# ==============================================================

# --- 错误捕获 ---
trap 'error "脚本在第 $LINENO 行发生错误，退出码: $?"' ERR

# --- 颜色与样式定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
PLAIN='\033[0m'
BOLD='\033[1m'

# --- 辅助函数 ---
function print_line() { echo -e "${BLUE}-------------------------------------------------------------${PLAIN}"; }
function info()    { echo -e "${BLUE}[INFO]${PLAIN}    $1"; }
function success() { echo -e "${GREEN}[OK]${PLAIN}      $1"; }
function warn()    { echo -e "${YELLOW}[WARN]${PLAIN}    $1"; }
function error()   { echo -e "${RED}[ERROR]${PLAIN}   $1"; }
function header()  {
    echo -e ""
    print_line
    echo -e "${PURPLE}${BOLD}  $1${PLAIN}"
    print_line
}

# --- 权限检查 ---
[[ $EUID -ne 0 ]] && error "必须使用 root 用户运行此脚本！" && exit 1

# --- 系统兼容性检查 ---
if [[ ! -f /etc/debian_version ]]; then
    error "此脚本仅支持 Debian / Ubuntu 系统！"
    exit 1
fi

# ==============================================================
#  状态管理 & 脚本缓存
# ==============================================================

# 状态目录：保存每个模块执行前的原始配置，供回退使用
STATE_DIR="/etc/server-init/state"
# 脚本缓存目录：外部脚本下载后缓存到本地，避免重复下载
CACHE_DIR="/etc/server-init/cache"
# 缓存有效期（秒），默认 7 天
CACHE_TTL=$((7 * 24 * 3600))

mkdir -p "$STATE_DIR" "$CACHE_DIR"

# ---------------------------------------------------------------
# 缓存下载函数
# 说明：
#   对于【第三方安装脚本】(linuxmirrors / docker / 1panel)
#   这类脚本必须从网络获取，因为它们需要根据你当前系统环境
#   动态生成安装命令，本地无法预置。但我们可以缓存到本地，
#   避免每次都重新下载，同时支持查看内容后再执行。
#
#   对于【自有脚本】(swap.sh) 同样缓存，逻辑一致。
#
# 用法: fetch_script <URL> <本地缓存文件名>
#   返回缓存文件的完整路径（通过 echo）
# ---------------------------------------------------------------
function fetch_script() {
    local url="$1"
    local cache_name="$2"
    local cache_file="$CACHE_DIR/$cache_name"
    local now
    now=$(date +%s)

    # 检查缓存是否存在且未过期
    if [[ -f "$cache_file" ]]; then
        local file_mtime
        file_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
        local age=$(( now - file_mtime ))
        if [[ $age -lt $CACHE_TTL ]]; then
            info "使用本地缓存脚本 ($(( age / 3600 ))小时前下载): $cache_file"
            echo "$cache_file"
            return 0
        else
            info "缓存已过期 ($(( age / 3600 ))小时)，重新下载..."
        fi
    fi

    # 下载脚本
    info "正在下载脚本: $url"
    if curl -sSL "$url" -o "$cache_file" --connect-timeout 15 --max-time 60; then
        chmod +x "$cache_file"
        success "下载完成，已缓存至: $cache_file"
        echo "$cache_file"
        return 0
    else
        error "下载失败: $url"
        rm -f "$cache_file"
        return 1
    fi
}

# 查看脚本内容（执行前可选预览）
function preview_script() {
    local script_file="$1"
    local script_name="$2"
    echo ""
    warn "即将执行外部脚本: ${script_name}"
    warn "脚本路径: ${script_file}"
    read -rp "是否在执行前查看脚本内容? (y/n): " view_it
    if [[ "$view_it" == "y" ]]; then
        echo ""
        echo -e "${CYAN}===== 脚本内容 (前50行) =====${PLAIN}"
        head -50 "$script_file"
        echo -e "${CYAN}===== 内容结束 =====${PLAIN}"
        echo ""
        read -rp "确认执行? (y/n): " run_it
        [[ "$run_it" != "y" ]] && warn "已取消执行" && return 1
    fi
    return 0
}

# 清理所有缓存
function clear_cache() {
    if [[ -d "$CACHE_DIR" ]]; then
        rm -f "$CACHE_DIR"/*.sh
        success "脚本缓存已清空: $CACHE_DIR"
    fi
}

# --- 环境预检：确保 curl 可用 ---
if ! command -v curl &>/dev/null; then
    warn "未检测到 curl，正在安装..."
    apt update -qq && apt install -y -qq curl
fi

# ==============================================================
#  系统信息展示
# ==============================================================
function show_sysinfo() {
    local os kernel ip mem_used mem_total disk_used disk_total cpu_model cpu_cores
    os=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
    kernel=$(uname -r)
    ip=$(curl -s4m5 ifconfig.me 2>/dev/null || curl -s4m5 ip.sb 2>/dev/null || echo "获取失败")
    mem_used=$(free -m | awk '/Mem/{print $3}')
    mem_total=$(free -m | awk '/Mem/{print $2}')
    disk_used=$(df -h / | awk 'NR==2{print $3}')
    disk_total=$(df -h / | awk 'NR==2{print $2}')
    cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //')
    cpu_cores=$(nproc)

    echo -e ""
    echo -e " ${CYAN}主机名:${PLAIN} $(hostname)"
    echo -e " ${CYAN}系统:  ${PLAIN} $os"
    echo -e " ${CYAN}内核:  ${PLAIN} $kernel"
    echo -e " ${CYAN}CPU:   ${PLAIN} $cpu_model (${cpu_cores} 核)"
    echo -e " ${CYAN}公网IP:${PLAIN} $ip"
    echo -e " ${CYAN}内存:  ${PLAIN} ${mem_used}MB / ${mem_total}MB"
    echo -e " ${CYAN}磁盘:  ${PLAIN} ${disk_used} / ${disk_total} (根分区)"
    echo -e " ${CYAN}时间:  ${PLAIN} $(date '+%Y-%m-%d %H:%M:%S %Z')"
}

# ==============================================================
#  核心功能模块
# ==============================================================

# ---------------------------------------------------------------
# [1] 配置软件源
# ---------------------------------------------------------------
function task_source() {
    header "[1] 配置系统软件源"

    # --- 保存原始状态 ---
    if [[ ! -f "$STATE_DIR/sources.saved" ]]; then
        if [[ -f /etc/apt/sources.list ]]; then
            cp /etc/apt/sources.list "$STATE_DIR/sources.list.orig"
        fi
        if [[ -d /etc/apt/sources.list.d ]]; then
            tar -czf "$STATE_DIR/sources.list.d.orig.tar.gz" \
                -C /etc/apt sources.list.d 2>/dev/null || true
        fi
        touch "$STATE_DIR/sources.saved"
        info "已保存原始软件源配置"
    fi

    echo -e "请选择服务器网络环境："
    echo -e "  ${GREEN}1.${PLAIN} 国内服务器 (清华/中科大/阿里等镜像)"
    echo -e "  ${GREEN}2.${PLAIN} 海外服务器 (官方源/全球CDN)"
    echo -e "  ${GREEN}3.${PLAIN} 跳过"
    read -rp "请输入选择 [1-3]: " choice

    local SCRIPT_FILE
    case "$choice" in
        1)
            SCRIPT_FILE=$(fetch_script "https://linuxmirrors.cn/main.sh" "linuxmirrors.sh") || return 1
            preview_script "$SCRIPT_FILE" "LinuxMirrors 换源脚本" || return 0
            bash "$SCRIPT_FILE"
            ;;
        2)
            SCRIPT_FILE=$(fetch_script "https://linuxmirrors.cn/main.sh" "linuxmirrors.sh") || return 1
            preview_script "$SCRIPT_FILE" "LinuxMirrors 换源脚本 (海外)" || return 0
            bash "$SCRIPT_FILE" --abroad
            ;;
        *)
            warn "已跳过软件源配置"
            ;;
    esac
}

function reset_source() {
    header "[重置] 恢复原始软件源"

    if [[ ! -f "$STATE_DIR/sources.saved" ]]; then
        warn "未找到软件源备份，可能从未执行过换源操作"
        return
    fi

    warn "即将恢复原始 sources.list，当前软件源配置将丢失"
    read -rp "确认恢复? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    if [[ -f "$STATE_DIR/sources.list.orig" ]]; then
        cp "$STATE_DIR/sources.list.orig" /etc/apt/sources.list
        success "已恢复 /etc/apt/sources.list"
    fi

    if [[ -f "$STATE_DIR/sources.list.d.orig.tar.gz" ]]; then
        rm -rf /etc/apt/sources.list.d
        tar -xzf "$STATE_DIR/sources.list.d.orig.tar.gz" -C /etc/apt 2>/dev/null
        success "已恢复 /etc/apt/sources.list.d/"
    fi

    apt update -y
    rm -f "$STATE_DIR/sources.saved" "$STATE_DIR/sources.list.orig" \
          "$STATE_DIR/sources.list.d.orig.tar.gz"
    success "软件源已恢复至原始状态"
}

# ---------------------------------------------------------------
# [2] 安装基础软件包
# ---------------------------------------------------------------
function task_essentials() {
    header "[2] 安装基础软件包"
    info "正在更新软件包列表..."
    apt update -y

    local PACKAGES=(
        build-essential
        curl wget net-tools dnsutils nethogs
        git vim nano unzip zip rsync
        htop iotop lsof ncdu tree tmux
        ca-certificates gnupg apt-transport-https
        sudo jq bc
    )

    # 记录本次安装的包，供回退使用
    echo "${PACKAGES[*]}" > "$STATE_DIR/essentials_packages.txt"

    info "正在安装软件包: ${PACKAGES[*]}"
    apt install -y "${PACKAGES[@]}"
    success "基础系统工具安装完成"
}

function reset_essentials() {
    header "[重置] 卸载基础软件包"

    if [[ ! -f "$STATE_DIR/essentials_packages.txt" ]]; then
        warn "未找到安装记录，无法自动卸载"
        return
    fi

    local PACKAGES
    read -ra PACKAGES < "$STATE_DIR/essentials_packages.txt"

    warn "即将卸载以下软件包:"
    echo "  ${PACKAGES[*]}"
    warn "注意：如果其他程序依赖这些包，可能会造成问题！"
    read -rp "确认卸载? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    apt remove -y "${PACKAGES[@]}"
    apt autoremove -y
    rm -f "$STATE_DIR/essentials_packages.txt"
    success "基础软件包已卸载"
}

# ---------------------------------------------------------------
# [3] 配置系统时区
# ---------------------------------------------------------------
function task_timezone() {
    header "[3] 配置系统时区"

    # 保存原始时区
    if [[ ! -f "$STATE_DIR/original_timezone" ]]; then
        timedatectl show -p Timezone --value > "$STATE_DIR/original_timezone"
        info "已保存原始时区: $(cat $STATE_DIR/original_timezone)"
    fi

    echo -e "当前系统时间: $(date)"
    echo ""
    echo -e "请选择目标时区："
    echo -e "  ${GREEN}1.${PLAIN}  UTC                 (通用协调时间)"
    echo -e "  ${GREEN}2.${PLAIN}  Asia/Shanghai        (中国/北京)"
    echo -e "  ${GREEN}3.${PLAIN}  Asia/Hong_Kong       (香港)"
    echo -e "  ${GREEN}4.${PLAIN}  Asia/Tokyo           (日本)"
    echo -e "  ${GREEN}5.${PLAIN}  Asia/Singapore       (新加坡)"
    echo -e "  ${GREEN}6.${PLAIN}  America/Los_Angeles  (美西/洛杉矶)"
    echo -e "  ${GREEN}7.${PLAIN}  America/New_York     (美东/纽约)"
    echo -e "  ${GREEN}8.${PLAIN}  Europe/London        (英国/伦敦)"
    echo -e "  ${GREEN}9.${PLAIN}  Europe/Berlin        (德国/柏林)"
    echo -e "  ${GREEN}10.${PLAIN} 手动输入 (自定义)"

    read -rp "请输入选项编号 [1-10] (默认 2): " tz_opt
    [[ -z "$tz_opt" ]] && tz_opt="2"

    case "$tz_opt" in
        1)  MY_TZ="UTC" ;;
        2)  MY_TZ="Asia/Shanghai" ;;
        3)  MY_TZ="Asia/Hong_Kong" ;;
        4)  MY_TZ="Asia/Tokyo" ;;
        5)  MY_TZ="Asia/Singapore" ;;
        6)  MY_TZ="America/Los_Angeles" ;;
        7)  MY_TZ="America/New_York" ;;
        8)  MY_TZ="Europe/London" ;;
        9)  MY_TZ="Europe/Berlin" ;;
        10) read -rp "请输入时区代码 (如 Asia/Taipei): " MY_TZ ;;
        *)  warn "无效输入，默认使用 Asia/Shanghai"; MY_TZ="Asia/Shanghai" ;;
    esac

    if [[ -z "$MY_TZ" ]]; then
        error "时区不能为空，已跳过"
        return 1
    fi

    if ! timedatectl list-timezones | grep -qx "$MY_TZ"; then
        error "时区 '$MY_TZ' 无效，请检查输入"
        return 1
    fi

    timedatectl set-timezone "$MY_TZ"
    timedatectl set-ntp true
    success "时区已更新为: $MY_TZ"
    info "NTP 同步状态: $(timedatectl show -p NTPSynchronized --value)"
    info "更新后时间: $(date)"
}

function reset_timezone() {
    header "[重置] 恢复原始时区"

    if [[ ! -f "$STATE_DIR/original_timezone" ]]; then
        warn "未找到原始时区记录，将恢复为 UTC"
        local orig_tz="UTC"
    else
        local orig_tz
        orig_tz=$(cat "$STATE_DIR/original_timezone")
    fi

    warn "即将恢复时区为: $orig_tz"
    read -rp "确认恢复? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    timedatectl set-timezone "$orig_tz"
    rm -f "$STATE_DIR/original_timezone"
    success "时区已恢复为: $orig_tz"
    info "当前时间: $(date)"
}

# ---------------------------------------------------------------
# [4] 开启 TCP BBR
# ---------------------------------------------------------------
function task_bbr() {
    header "[4] 配置 TCP BBR 拥塞控制"

    local KERNEL_MAJOR KERNEL_MINOR
    KERNEL_MAJOR=$(uname -r | cut -d. -f1)
    KERNEL_MINOR=$(uname -r | cut -d. -f2)
    if [[ "$KERNEL_MAJOR" -lt 4 ]] || { [[ "$KERNEL_MAJOR" -eq 4 ]] && [[ "$KERNEL_MINOR" -lt 9 ]]; }; then
        error "内核版本 $(uname -r) 过低，BBR 需要 4.9+，请先升级内核"
        return 1
    fi

    local CURRENT_CC
    CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    if [[ "$CURRENT_CC" == "bbr" ]]; then
        warn "BBR 当前已在运行，无需重复配置"
        info "当前拥塞算法: $CURRENT_CC | 队列算法: $(sysctl -n net.core.default_qdisc)"
        return
    fi

    # 保存原始拥塞算法
    if [[ ! -f "$STATE_DIR/original_cc" ]]; then
        sysctl -n net.ipv4.tcp_congestion_control > "$STATE_DIR/original_cc"
        sysctl -n net.core.default_qdisc > "$STATE_DIR/original_qdisc"
        info "已保存原始算法: CC=$(cat $STATE_DIR/original_cc) QDISC=$(cat $STATE_DIR/original_qdisc)"
    fi

    info "正在开启 BBR (当前算法: $CURRENT_CC)..."

    grep -q "^net.core.default_qdisc" /etc/sysctl.conf || \
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    grep -q "^net.ipv4.tcp_congestion_control" /etc/sysctl.conf || \
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

    sysctl -p &>/dev/null

    local NEW_CC
    NEW_CC=$(sysctl -n net.ipv4.tcp_congestion_control)
    if [[ "$NEW_CC" == "bbr" ]]; then
        success "TCP BBR 已成功开启"
        info "当前拥塞算法: $NEW_CC | 队列算法: $(sysctl -n net.core.default_qdisc)"
    else
        error "BBR 开启失败，当前算法仍为: $NEW_CC"
        return 1
    fi
}

function reset_bbr() {
    header "[重置] 关闭 TCP BBR"

    if [[ ! -f "$STATE_DIR/original_cc" ]]; then
        warn "未找到原始算法记录，将恢复为 cubic"
        local orig_cc="cubic"
        local orig_qdisc="pfifo_fast"
    else
        local orig_cc
        local orig_qdisc
        orig_cc=$(cat "$STATE_DIR/original_cc")
        orig_qdisc=$(cat "$STATE_DIR/original_qdisc")
    fi

    warn "即将恢复拥塞算法为: $orig_cc，队列算法为: $orig_qdisc"
    read -rp "确认恢复? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    # 从 sysctl.conf 中移除 BBR 相关配置
    sed -i '/^net.core.default_qdisc=fq/d' /etc/sysctl.conf
    sed -i '/^net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf

    # 写入原始算法
    echo "net.core.default_qdisc=$orig_qdisc" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=$orig_cc" >> /etc/sysctl.conf

    sysctl -p &>/dev/null
    rm -f "$STATE_DIR/original_cc" "$STATE_DIR/original_qdisc"
    success "已恢复: 拥塞算法=$orig_cc，队列算法=$orig_qdisc"
}

# ---------------------------------------------------------------
# [5] 配置 Swap
# ---------------------------------------------------------------
function task_swap() {
    header "[5] 配置 Swap 交换空间"

    local current_swap
    current_swap=$(free -h | awk '/Swap/{print $2}')
    info "当前 Swap 大小: $current_swap"
    swapon --show

    # 保存当前 Swap 状态
    if [[ ! -f "$STATE_DIR/swap_state.txt" ]]; then
        free -m | awk '/Swap/{print $2}' > "$STATE_DIR/swap_state.txt"
        swapon --show --noheadings > "$STATE_DIR/swap_devices.txt" 2>/dev/null || true
        info "已记录当前 Swap 状态"
    fi

    local SCRIPT_FILE
    SCRIPT_FILE=$(fetch_script \
        "https://raw.githubusercontent.com/walllal/bash/refs/heads/main/swap.sh" \
        "swap.sh") || return 1
    preview_script "$SCRIPT_FILE" "Swap 管理脚本" || return 0
    bash "$SCRIPT_FILE"
}

function reset_swap() {
    header "[重置] 关闭并删除 Swap"

    warn "即将关闭所有 Swap 并删除 /swapfile"
    read -rp "确认? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    # 关闭所有 Swap
    swapoff -a 2>/dev/null || true

    # 删除 swapfile
    if [[ -f /swapfile ]]; then
        rm -f /swapfile
        success "已删除 /swapfile"
    fi

    # 清理 /etc/fstab 中的 swap 条目
    sed -i '/swapfile/d' /etc/fstab
    sed -i '/swap/d' /etc/fstab

    rm -f "$STATE_DIR/swap_state.txt" "$STATE_DIR/swap_devices.txt"
    success "Swap 已完全关闭并清除"
    free -h | grep Swap
}

# ---------------------------------------------------------------
# [6] 配置主机名
# ---------------------------------------------------------------
function task_hostname() {
    header "[6] 配置服务器主机名"

    local current_hostname
    current_hostname=$(hostname)
    echo -e "当前主机名: ${GREEN}${current_hostname}${PLAIN}"

    # 保存原始主机名
    if [[ ! -f "$STATE_DIR/original_hostname" ]]; then
        echo "$current_hostname" > "$STATE_DIR/original_hostname"
        grep "^127.0.1.1" /etc/hosts > "$STATE_DIR/original_hosts_line.txt" 2>/dev/null || true
        info "已保存原始主机名: $current_hostname"
    fi

    read -rp "请输入新主机名 (直接回车跳过): " new_hostname

    if [[ -z "$new_hostname" ]]; then
        warn "已跳过主机名配置"
        return
    fi

    if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
        error "主机名格式无效，只允许字母、数字和连字符，且不能以连字符开头/结尾"
        return 1
    fi

    hostnamectl set-hostname "$new_hostname"

    if grep -q "^127.0.1.1" /etc/hosts; then
        sed -i "s/^127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
    else
        echo -e "127.0.1.1\t$new_hostname" >> /etc/hosts
    fi

    success "主机名已更新为: $new_hostname"
}

function reset_hostname() {
    header "[重置] 恢复原始主机名"

    if [[ ! -f "$STATE_DIR/original_hostname" ]]; then
        warn "未找到原始主机名记录"
        return
    fi

    local orig_hostname
    orig_hostname=$(cat "$STATE_DIR/original_hostname")

    warn "即将恢复主机名为: $orig_hostname"
    read -rp "确认恢复? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    hostnamectl set-hostname "$orig_hostname"

    # 恢复 /etc/hosts 中的 127.0.1.1 行
    if grep -q "^127.0.1.1" /etc/hosts; then
        sed -i "s/^127.0.1.1.*/127.0.1.1\t$orig_hostname/" /etc/hosts
    fi

    rm -f "$STATE_DIR/original_hostname" "$STATE_DIR/original_hosts_line.txt"
    success "主机名已恢复为: $orig_hostname"
}

# ---------------------------------------------------------------
# [7] 内核网络参数优化
# ---------------------------------------------------------------
function task_sysctl() {
    header "[7] 内核网络参数优化"

    local SYSCTL_CONF="/etc/sysctl.d/99-server-optimize.conf"

    if [[ -f "$SYSCTL_CONF" ]]; then
        warn "优化配置文件已存在: $SYSCTL_CONF"
        read -rp "是否覆盖重新配置? (y/n): " overwrite
        [[ "$overwrite" != "y" ]] && return
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
    touch "$STATE_DIR/sysctl_optimized"
    success "内核参数优化完成，配置文件: $SYSCTL_CONF"
}

function reset_sysctl() {
    header "[重置] 移除内核参数优化"

    local SYSCTL_CONF="/etc/sysctl.d/99-server-optimize.conf"

    if [[ ! -f "$SYSCTL_CONF" ]]; then
        warn "优化配置文件不存在，无需重置"
        return
    fi

    warn "即将删除优化配置文件: $SYSCTL_CONF"
    warn "内核参数将在重启后恢复为系统默认值"
    read -rp "确认? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    rm -f "$SYSCTL_CONF"
    # 立即应用（加载其余配置，去掉已删除的）
    sysctl --system &>/dev/null
    rm -f "$STATE_DIR/sysctl_optimized"
    success "内核优化配置已移除，重启后完全恢复默认值"
}

# ---------------------------------------------------------------
# [8] 安装 Docker
# ---------------------------------------------------------------
function task_docker() {
    header "[8] 安装 Docker 环境"

    if command -v docker &>/dev/null; then
        warn "Docker 已安装，当前版本: $(docker --version)"
        return
    fi

    local SCRIPT_FILE
    SCRIPT_FILE=$(fetch_script "https://linuxmirrors.cn/docker.sh" "docker-install.sh") || return 1
    preview_script "$SCRIPT_FILE" "Docker 安装脚本 (LinuxMirrors)" || return 0
    bash "$SCRIPT_FILE"

    if command -v docker &>/dev/null; then
        systemctl enable docker &>/dev/null
        systemctl start docker &>/dev/null
        touch "$STATE_DIR/docker_installed"
        success "Docker 安装成功: $(docker --version)"
    else
        error "Docker 安装未成功，请手动检查"
        return 1
    fi
}

function reset_docker() {
    header "[重置] 卸载 Docker"

    if ! command -v docker &>/dev/null; then
        warn "Docker 未安装，无需卸载"
        return
    fi

    warn "即将完全卸载 Docker 及相关组件"
    warn "⚠️  所有容器、镜像、卷数据将永久丢失！"
    read -rp "确认卸载? 请输入 'yes' 确认: " confirm
    [[ "$confirm" != "yes" ]] && warn "已取消" && return

    systemctl stop docker dockerd containerd 2>/dev/null || true
    systemctl disable docker 2>/dev/null || true

    apt remove -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>/dev/null || \
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    apt autoremove -y

    # 询问是否删除数据目录
    read -rp "是否同时删除 /var/lib/docker 数据目录? (y/n): " del_data
    if [[ "$del_data" == "y" ]]; then
        rm -rf /var/lib/docker /var/lib/containerd
        success "Docker 数据目录已删除"
    fi

    rm -f "$STATE_DIR/docker_installed"
    success "Docker 已卸载"
}

# ---------------------------------------------------------------
# [9] 安装 1Panel
# ---------------------------------------------------------------
function task_1panel() {
    header "[9] 安装 1Panel 面板"

    if ! command -v docker &>/dev/null; then
        warn "前置依赖 Docker 未找到，即将先安装 Docker..."
        task_docker || { error "Docker 安装失败，无法继续安装 1Panel"; return 1; }
    fi

    local SCRIPT_FILE
    SCRIPT_FILE=$(fetch_script \
        "https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh" \
        "1panel-install.sh") || return 1
    preview_script "$SCRIPT_FILE" "1Panel 官方安装脚本" || return 0
    bash "$SCRIPT_FILE"
    touch "$STATE_DIR/1panel_installed"
}

function reset_1panel() {
    header "[重置] 卸载 1Panel"

    if ! command -v 1pctl &>/dev/null; then
        warn "1Panel 未安装或已卸载"
        return
    fi

    warn "即将卸载 1Panel 面板"
    warn "⚠️  面板数据和已安装的应用将被移除！"
    read -rp "确认卸载? 请输入 'yes' 确认: " confirm
    [[ "$confirm" != "yes" ]] && warn "已取消" && return

    if command -v 1pctl &>/dev/null; then
        1pctl uninstall 2>/dev/null || true
    fi

    # 清理残留
    systemctl stop 1panel 2>/dev/null || true
    systemctl disable 1panel 2>/dev/null || true
    rm -rf /opt/1panel /usr/local/bin/1pctl /etc/systemd/system/1panel.service
    systemctl daemon-reload

    rm -f "$STATE_DIR/1panel_installed"
    success "1Panel 已卸载"
}

# ---------------------------------------------------------------
# [10] 创建普通用户 + sudo 权限
# ---------------------------------------------------------------
function task_create_user() {
    header "[10] 创建普通用户"

    echo -e "当前系统用户列表 (UID 1000+):"
    awk -F: '$3 >= 1000 && $3 < 65534 {print "  "$1" (uid="$3")"}' /etc/passwd
    echo ""

    read -rp "请输入新用户名: " new_user

    if [[ -z "$new_user" ]]; then
        error "用户名不能为空"
        return 1
    fi

    if [[ ! "$new_user" =~ ^[a-z][a-z0-9_-]{0,30}$ ]]; then
        error "用户名格式无效，只允许小写字母开头，包含小写字母/数字/下划线/连字符，长度不超过31位"
        return 1
    fi

    if id "$new_user" &>/dev/null; then
        warn "用户 '$new_user' 已存在"
        read -rp "是否继续为该用户配置 sudo 和 SSH 密钥? (y/n): " cont
        [[ "$cont" != "y" ]] && return
    else
        useradd -m -s /bin/bash "$new_user"
        # 记录创建的用户名，供回退使用
        echo "$new_user" >> "$STATE_DIR/created_users.txt"
        success "用户 '$new_user' 已创建，家目录: /home/$new_user"

        info "请为用户 '$new_user' 设置登录密码："
        local passwd_ok=false
        local retry=0
        while [[ "$passwd_ok" == false && $retry -lt 3 ]]; do
            if passwd "$new_user"; then
                passwd_ok=true
                success "密码设置成功"
            else
                retry=$((retry + 1))
                warn "密码设置失败，剩余尝试次数: $((3 - retry))"
            fi
        done
        if [[ "$passwd_ok" == false ]]; then
            error "密码设置多次失败，已锁定用户账户"
            usermod -L "$new_user"
            return 1
        fi
    fi

    usermod -aG sudo "$new_user"
    success "用户 '$new_user' 已加入 sudo 组"

    if ! grep -q "^%sudo" /etc/sudoers; then
        echo "%sudo ALL=(ALL:ALL) ALL" >> /etc/sudoers
        info "已添加 sudo 组权限到 /etc/sudoers"
    fi

    echo ""
    read -rp "是否将 root 的 SSH 公钥同步到该用户? (y/n): " sync_key
    if [[ "$sync_key" == "y" ]]; then
        if [[ -f /root/.ssh/authorized_keys ]] && [[ -s /root/.ssh/authorized_keys ]]; then
            mkdir -p "/home/$new_user/.ssh"
            cp /root/.ssh/authorized_keys "/home/$new_user/.ssh/authorized_keys"
            chown -R "$new_user:$new_user" "/home/$new_user/.ssh"
            chmod 700 "/home/$new_user/.ssh"
            chmod 600 "/home/$new_user/.ssh/authorized_keys"
            success "root 的 SSH 公钥已同步到 /home/$new_user/.ssh/authorized_keys"
        else
            warn "root 未配置 SSH 公钥，跳过同步"
        fi
    fi

    read -rp "是否为该用户单独添加 SSH 公钥? (y/n): " add_key
    if [[ "$add_key" == "y" ]]; then
        echo -e "${YELLOW}请粘贴 SSH 公钥 (ssh-ed25519 / ssh-rsa ...):${PLAIN}"
        read -r new_pubkey
        if [[ -z "$new_pubkey" ]]; then
            warn "公钥为空，跳过"
        elif [[ ! "$new_pubkey" =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh\.com) ]]; then
            error "公钥格式无效，跳过"
        else
            mkdir -p "/home/$new_user/.ssh"
            echo "$new_pubkey" >> "/home/$new_user/.ssh/authorized_keys"
            chown -R "$new_user:$new_user" "/home/$new_user/.ssh"
            chmod 700 "/home/$new_user/.ssh"
            chmod 600 "/home/$new_user/.ssh/authorized_keys"
            success "公钥已添加到 /home/$new_user/.ssh/authorized_keys"
        fi
    fi

    echo ""
    warn "安全建议：创建普通用户后，可禁止 root 直接 SSH 登录"
    read -rp "是否禁止 root 直接 SSH 登录? (y/n): " disable_root_ssh
    if [[ "$disable_root_ssh" == "y" ]]; then
        if [[ -f "/home/$new_user/.ssh/authorized_keys" ]] && [[ -s "/home/$new_user/.ssh/authorized_keys" ]]; then
            sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
            if ! sshd -t; then
                error "SSH 配置验证失败，已撤销修改"
                sed -i 's/^PermitRootLogin no/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
            else
                systemctl restart sshd
                success "root 直接 SSH 登录已禁止"
                warn "⚠️  请立即新开终端，用 $new_user 用户测试 SSH 连接！"
            fi
        else
            error "新用户未配置 SSH 公钥，拒绝禁止 root 登录（防止锁机）"
        fi
    fi

    echo ""
    success "用户配置完成，摘要："
    echo -e "  用户名:   ${GREEN}$new_user${PLAIN}"
    echo -e "  家目录:   /home/$new_user"
    echo -e "  sudo:     ${GREEN}已启用${PLAIN}"
    echo -e "  SSH公钥:  $([ -s "/home/$new_user/.ssh/authorized_keys" ] && echo "${GREEN}已配置${PLAIN}" || echo "${YELLOW}未配置${PLAIN}")"
}

function reset_create_user() {
    header "[重置] 删除创建的用户"

    if [[ ! -f "$STATE_DIR/created_users.txt" ]]; then
        warn "未找到用户创建记录"
        return
    fi

    echo -e "脚本创建的用户列表:"
    cat "$STATE_DIR/created_users.txt" | while read -r u; do
        if id "$u" &>/dev/null; then
            echo -e "  ${GREEN}$u${PLAIN} (存在)"
        else
            echo -e "  ${YELLOW}$u${PLAIN} (已不存在)"
        fi
    done
    echo ""

    read -rp "请输入要删除的用户名 (直接回车跳过): " del_user
    [[ -z "$del_user" ]] && return

    if ! id "$del_user" &>/dev/null; then
        error "用户 '$del_user' 不存在"
        return 1
    fi

    warn "即将删除用户: $del_user"
    read -rp "是否同时删除用户家目录 /home/$del_user ? (y/n): " del_home

    if [[ "$del_home" == "y" ]]; then
        userdel -r "$del_user" 2>/dev/null
        success "用户 '$del_user' 及其家目录已删除"
    else
        userdel "$del_user" 2>/dev/null
        success "用户 '$del_user' 已删除（家目录保留）"
    fi

    # 从记录中移除
    sed -i "/^${del_user}$/d" "$STATE_DIR/created_users.txt"
    [[ ! -s "$STATE_DIR/created_users.txt" ]] && rm -f "$STATE_DIR/created_users.txt"
}

# ---------------------------------------------------------------
# [11] 配置 SSH 密钥登录
# ---------------------------------------------------------------
function task_ssh() {
    header "[11] 配置 SSH 密钥登录"

    echo -e "此操作将："
    echo -e "  1. 导入您的 SSH 公钥 (写入 root)"
    echo -e "  2. ${RED}禁用密码登录${PLAIN}"
    echo -e "  3. 限制最大认证尝试次数为 3 次"
    echo ""
    warn "⚠️  执行前请确保您已有对应私钥，否则将无法登录！"
    read -rp "确认执行? (y/n): " choice
    [[ "$choice" != "y" ]] && warn "已取消 SSH 配置" && return

    echo -e "${YELLOW}请粘贴您的 SSH 公钥 (ssh-ed25519 / ssh-rsa / ecdsa-sha2-nistp256 ...):${PLAIN}"
    read -r pubkey

    if [[ -z "$pubkey" ]]; then
        error "公钥为空，已取消操作"
        return 1
    fi

    if [[ ! "$pubkey" =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com) ]]; then
        error "公钥格式无效！请确认以 ssh-ed25519 / ssh-rsa 等类型开头"
        return 1
    fi

    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys

    if grep -qF "$pubkey" ~/.ssh/authorized_keys 2>/dev/null; then
        warn "该公钥已存在，跳过写入"
    else
        echo "$pubkey" >> ~/.ssh/authorized_keys
        success "公钥已写入 ~/.ssh/authorized_keys"
    fi

    # 备份 sshd_config（同时写入 state 目录作为"最原始"备份）
    local BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%F_%H%M%S)"
    cp /etc/ssh/sshd_config "$BACKUP_FILE"
    # 如果首次备份，保存到 state
    [[ ! -f "$STATE_DIR/sshd_config.orig" ]] && \
        cp /etc/ssh/sshd_config "$STATE_DIR/sshd_config.orig"
    info "原配置已备份至: $BACKUP_FILE"

    function sshd_set() {
        local key="$1" val="$2"
        if grep -qE "^#?${key}" /etc/ssh/sshd_config; then
            sed -i "s|^#\?${key}.*|${key} ${val}|g" /etc/ssh/sshd_config
        else
            echo "${key} ${val}" >> /etc/ssh/sshd_config
        fi
    }

    sshd_set "PubkeyAuthentication"   "yes"
    sshd_set "AuthorizedKeysFile"     ".ssh/authorized_keys"
    sshd_set "PasswordAuthentication" "no"
    sshd_set "PermitRootLogin"        "prohibit-password"
    sshd_set "MaxAuthTries"           "3"
    sshd_set "X11Forwarding"          "no"
    sshd_set "UseDNS"                 "no"
    sshd_set "ClientAliveInterval"    "60"
    sshd_set "ClientAliveCountMax"    "3"
    sshd_set "LoginGraceTime"         "30"

    if ! sshd -t; then
        error "SSH 配置存在语法错误！正在自动回滚..."
        cp "$BACKUP_FILE" /etc/ssh/sshd_config
        error "已回滚至备份配置: $BACKUP_FILE"
        return 1
    fi

    systemctl restart sshd
    touch "$STATE_DIR/ssh_hardened"
    success "SSH 密钥登录配置完成，密码登录已禁用"
    echo ""
    warn "════════════════════════════════════════════════"
    warn "  ⚠️  请立即新开终端测试 SSH 连接！"
    warn "  确认可以正常登录后，再关闭当前终端！"
    warn "════════════════════════════════════════════════"
}

function reset_ssh() {
    header "[重置] 恢复 SSH 原始配置"

    if [[ ! -f "$STATE_DIR/sshd_config.orig" ]]; then
        # 尝试找最早的备份
        local oldest_bak
        oldest_bak=$(ls -t /etc/ssh/sshd_config.bak.* 2>/dev/null | tail -1)
        if [[ -z "$oldest_bak" ]]; then
            error "未找到任何 SSH 配置备份，无法回退"
            return 1
        fi
        warn "未找到 state 备份，将使用最早的备份: $oldest_bak"
        cp "$oldest_bak" "$STATE_DIR/sshd_config.orig"
    fi

    warn "即将恢复 SSH 配置为初始状态"
    warn "这将重新启用密码登录！"
    read -rp "确认恢复? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    cp "$STATE_DIR/sshd_config.orig" /etc/ssh/sshd_config

    if ! sshd -t; then
        error "恢复的配置存在语法错误，请手动检查 /etc/ssh/sshd_config"
        return 1
    fi

    systemctl restart sshd
    rm -f "$STATE_DIR/sshd_config.orig" "$STATE_DIR/ssh_hardened"
    success "SSH 配置已恢复为原始状态，密码登录已重新开启"
}

# ---------------------------------------------------------------
# [12] 修改 SSH 端口
# ---------------------------------------------------------------
function task_ssh_port() {
    header "[12] 修改 SSH 端口"

    local CURRENT_PORT
    CURRENT_PORT=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}' | head -1)
    CURRENT_PORT=${CURRENT_PORT:-22}
    info "当前 SSH 端口: ${GREEN}${CURRENT_PORT}${PLAIN}"

    # 保存原始端口
    if [[ ! -f "$STATE_DIR/original_ssh_port" ]]; then
        echo "$CURRENT_PORT" > "$STATE_DIR/original_ssh_port"
        info "已记录原始端口: $CURRENT_PORT"
    fi

    echo ""
    warn "修改 SSH 端口可过滤绝大多数自动化扫描攻击"
    warn "建议使用 1024-65535 之间的端口，避免使用知名服务端口"
    echo ""

    local NEW_PORT
    while true; do
        read -rp "请输入新的 SSH 端口号 (1024-65535): " NEW_PORT

        if [[ ! "$NEW_PORT" =~ ^[0-9]+$ ]]; then
            error "端口必须为纯数字，请重新输入"
            continue
        fi

        if [[ "$NEW_PORT" -lt 1024 || "$NEW_PORT" -gt 65535 ]]; then
            error "端口范围无效，请输入 1024-65535 之间的值"
            continue
        fi

        if ss -tlnp | grep -q ":${NEW_PORT} " && [[ "$NEW_PORT" != "$CURRENT_PORT" ]]; then
            warn "端口 $NEW_PORT 已被以下进程占用:"
            ss -tlnp | grep ":${NEW_PORT} "
            read -rp "是否仍要使用此端口? (y/n): " force_use
            [[ "$force_use" != "y" ]] && continue
        fi

        if [[ "$NEW_PORT" == "$CURRENT_PORT" ]]; then
            warn "新端口与当前端口相同 ($CURRENT_PORT)，无需修改"
            return
        fi

        break
    done

    echo ""
    warn "将把 SSH 端口从 ${CURRENT_PORT} 修改为 ${NEW_PORT}"
    read -rp "确认执行? (y/n): " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return

    local BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%F_%H%M%S)"
    cp /etc/ssh/sshd_config "$BACKUP_FILE"
    info "原配置已备份至: $BACKUP_FILE"

    if grep -qE "^#?Port " /etc/ssh/sshd_config; then
        sed -i "s|^#\?Port .*|Port ${NEW_PORT}|g" /etc/ssh/sshd_config
    else
        echo "Port ${NEW_PORT}" >> /etc/ssh/sshd_config
    fi

    if ! sshd -t; then
        error "SSH 配置存在语法错误！正在自动回滚..."
        cp "$BACKUP_FILE" /etc/ssh/sshd_config
        error "已回滚至备份配置"
        return 1
    fi

    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        info "检测到 UFW 已启用，正在更新防火墙规则..."
        ufw allow "${NEW_PORT}/tcp" comment 'SSH-New'
        ufw delete allow "${CURRENT_PORT}/tcp" 2>/dev/null || true
        success "UFW 规则已更新: 关闭 $CURRENT_PORT，开放 $NEW_PORT"
    else
        warn "UFW 未启用，请手动确保新端口 $NEW_PORT 可访问"
    fi

    if [[ -f /etc/fail2ban/jail.local ]]; then
        info "正在更新 Fail2Ban 配置..."
        sed -i '/\[sshd\]/,/\[/{s/^port.*/port = '"${NEW_PORT}"'/}' /etc/fail2ban/jail.local
        systemctl restart fail2ban &>/dev/null && success "Fail2Ban 配置已更新"
    fi

    # 记录当前端口到 state
    echo "$NEW_PORT" > "$STATE_DIR/current_ssh_port"

    systemctl restart sshd
    success "SSH 端口已成功修改: ${CURRENT_PORT} → ${NEW_PORT}"

    echo ""
    warn "════════════════════════════════════════════════════════"
    warn "  ⚠️  重要：请立即新开终端，使用新端口测试连接！"
    warn "  连接命令: ssh -p ${NEW_PORT} root@<你的IP>"
    warn "  确认连接成功后，再关闭当前终端！"
    warn "════════════════════════════════════════════════════════"
}

function reset_ssh_port() {
    header "[重置] 恢复原始 SSH 端口"

    if [[ ! -f "$STATE_DIR/original_ssh_port" ]]; then
        warn "未找到原始端口记录，默认恢复为 22"
        local orig_port="22"
    else
        local orig_port
        orig_port=$(cat "$STATE_DIR/original_ssh_port")
    fi

    local current_port
    current_port=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}' | head -1)
    current_port=${current_port:-22}

    if [[ "$current_port" == "$orig_port" ]]; then
        warn "当前端口已是原始端口 ($orig_port)，无需恢复"
        return
    fi

    warn "将把 SSH 端口从 ${current_port} 恢复为 ${orig_port}"
    read -rp "确认恢复? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    local BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%F_%H%M%S)"
    cp /etc/ssh/sshd_config "$BACKUP_FILE"

    sed -i "s|^Port .*|Port ${orig_port}|g" /etc/ssh/sshd_config

    if ! sshd -t; then
        error "SSH 配置存在语法错误！正在自动回滚..."
        cp "$BACKUP_FILE" /etc/ssh/sshd_config
        return 1
    fi

    # 联动更新 UFW
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        ufw allow "${orig_port}/tcp" comment 'SSH-Restored'
        ufw delete allow "${current_port}/tcp" 2>/dev/null || true
        success "UFW 规则已更新"
    fi

    # 联动更新 Fail2Ban
    if [[ -f /etc/fail2ban/jail.local ]]; then
        sed -i '/\[sshd\]/,/\[/{s/^port.*/port = '"${orig_port}"'/}' /etc/fail2ban/jail.local
        systemctl restart fail2ban &>/dev/null
    fi

    systemctl restart sshd
    rm -f "$STATE_DIR/original_ssh_port" "$STATE_DIR/current_ssh_port"
    success "SSH 端口已恢复为: $orig_port"

    warn "════════════════════════════════════════════════════════"
    warn "  ⚠️  请立即新开终端，使用端口 $orig_port 测试连接！"
    warn "════════════════════════════════════════════════════════"
}

# ---------------------------------------------------------------
# [13] SSH 登录 Telegram 通知
# ---------------------------------------------------------------
function task_ssh_notify() {
    header "[13] SSH 登录 Telegram 通知"

    local NOTIFY_SCRIPT="/etc/profile.d/ssh-login-notify.sh"

    echo -e "功能说明：每次有用户通过 SSH 登录服务器，将向指定 Telegram 发送通知"
    echo ""

    if [[ -f "$NOTIFY_SCRIPT" ]]; then
        warn "检测到已存在通知脚本: $NOTIFY_SCRIPT"
        read -rp "是否重新配置? (y/n): " reconfig
        [[ "$reconfig" != "y" ]] && return
    fi

    echo -e "${CYAN}步骤 1/2：获取 Bot Token${PLAIN}"
    echo -e "  1. Telegram 搜索 @BotFather"
    echo -e "  2. 发送 /newbot 创建机器人"
    echo -e "  3. 复制获得的 Token (格式: 1234567890:ABCDefgh...)"
    echo ""
    read -rp "请输入 Bot Token: " BOT_TOKEN

    if [[ -z "$BOT_TOKEN" ]]; then
        error "Bot Token 不能为空"
        return 1
    fi

    if [[ ! "$BOT_TOKEN" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; then
        warn "Token 格式似乎不标准，仍将继续（如遇问题请检查Token）"
    fi

    echo ""
    echo -e "${CYAN}步骤 2/2：获取 Chat ID${PLAIN}"
    echo -e "  1. 向你的机器人发送任意一条消息"
    echo -e "  2. 访问: https://api.telegram.org/bot${BOT_TOKEN}/getUpdates"
    echo -e "  3. 找到 \"chat\":{\"id\": XXXXXXXX} 中的数字"
    echo ""
    read -rp "请输入 Chat ID: " CHAT_ID

    if [[ -z "$CHAT_ID" ]]; then
        error "Chat ID 不能为空"
        return 1
    fi

    if [[ ! "$CHAT_ID" =~ ^-?[0-9]+$ ]]; then
        error "Chat ID 格式无效，应为纯数字（群组ID可能含负号）"
        return 1
    fi

    info "正在发送测试消息，验证配置是否正确..."
    local TEST_RESULT
    TEST_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=✅ SSH 登录通知配置成功！来自服务器: $(hostname)" \
        -d "parse_mode=HTML" 2>/dev/null)

    if [[ "$TEST_RESULT" != "200" ]]; then
        error "测试消息发送失败 (HTTP $TEST_RESULT)，请检查 Token 和 Chat ID"
        read -rp "是否忽略错误仍然保存配置? (y/n): " ignore_err
        [[ "$ignore_err" != "y" ]] && return 1
    else
        success "测试消息发送成功！请查看 Telegram 是否收到消息"
    fi

    cat > "$NOTIFY_SCRIPT" << EOF
#!/bin/bash
# SSH 登录 Telegram 通知脚本

if [[ -z "\$SSH_CLIENT" && -z "\$SSH_TTY" ]]; then
    exit 0
fi

BOT_TOKEN="${BOT_TOKEN}"
CHAT_ID="${CHAT_ID}"

LOGIN_USER="\$(whoami)"
LOGIN_IP="\$(echo \$SSH_CLIENT | awk '{print \$1}')"
LOGIN_TIME="\$(date '+%Y-%m-%d %H:%M:%S %Z')"
HOST_NAME="\$(hostname)"
HOST_IP="\$(curl -s4m3 ifconfig.me 2>/dev/null || echo '未知')"

GEO_INFO="\$(curl -sm3 "https://ipinfo.io/\${LOGIN_IP}/json" 2>/dev/null)"
GEO_COUNTRY="\$(echo \$GEO_INFO | grep -o '"country":"[^"]*"' | cut -d'"' -f4 || echo '未知')"
GEO_CITY="\$(echo \$GEO_INFO | grep -o '"city":"[^"]*"' | cut -d'"' -f4 || echo '未知')"
GEO_ORG="\$(echo \$GEO_INFO | grep -o '"org":"[^"]*"' | cut -d'"' -f4 || echo '未知')"

MESSAGE="🔐 <b>SSH 登录通知</b>
━━━━━━━━━━━━━━━━
🖥️ <b>主机:</b> \${HOST_NAME} (\${HOST_IP})
👤 <b>用户:</b> \${LOGIN_USER}
🌐 <b>来源IP:</b> \${LOGIN_IP}
📍 <b>地区:</b> \${GEO_CITY}, \${GEO_COUNTRY}
🏢 <b>运营商:</b> \${GEO_ORG}
🕐 <b>时间:</b> \${LOGIN_TIME}
━━━━━━━━━━━━━━━━
⚠️ 若非本人操作，请立即检查！"

curl -s "https://api.telegram.org/bot\${BOT_TOKEN}/sendMessage" \\
    -d "chat_id=\${CHAT_ID}" \\
    -d "text=\${MESSAGE}" \\
    -d "parse_mode=HTML" \\
    --max-time 5 \\
    > /dev/null 2>&1 &
EOF

    chmod +x "$NOTIFY_SCRIPT"
    touch "$STATE_DIR/ssh_notify_installed"
    success "SSH 登录通知脚本已安装: $NOTIFY_SCRIPT"
    echo ""
    echo -e "  如需停用通知: ${YELLOW}rm $NOTIFY_SCRIPT${PLAIN}"
    echo -e "  如需修改配置: ${YELLOW}nano $NOTIFY_SCRIPT${PLAIN}"
}

function reset_ssh_notify() {
    header "[重置] 关闭 SSH 登录 Telegram 通知"

    local NOTIFY_SCRIPT="/etc/profile.d/ssh-login-notify.sh"

    if [[ ! -f "$NOTIFY_SCRIPT" ]]; then
        warn "通知脚本不存在，无需关闭"
        return
    fi

    warn "即将删除 SSH 登录通知脚本: $NOTIFY_SCRIPT"
    read -rp "确认? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    rm -f "$NOTIFY_SCRIPT"
    rm -f "$STATE_DIR/ssh_notify_installed"
    success "SSH 登录 Telegram 通知已关闭"
}

# ---------------------------------------------------------------
# [14] 防火墙与入侵防御 (UFW & Fail2Ban)
# ---------------------------------------------------------------
function task_firewall() {
    header "[14] 安全防护配置 (UFW & Fail2Ban)"

    info "正在安装 UFW 和 Fail2Ban..."
    apt install -y ufw fail2ban

    info "正在配置 Fail2Ban..."
    # 备份原始配置
    [[ -f /etc/fail2ban/jail.local ]] && \
        cp /etc/fail2ban/jail.local "$STATE_DIR/jail.local.orig" 2>/dev/null || true

    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd
banaction = iptables-multiport

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 24h
EOF

    systemctl enable fail2ban &>/dev/null
    systemctl restart fail2ban &>/dev/null

    if systemctl is-active --quiet fail2ban; then
        success "Fail2Ban 已启动：SSH 错误 3 次封禁 24 小时"
    else
        error "Fail2Ban 启动失败，请检查: journalctl -u fail2ban"
    fi

    print_line
    warn "注意：若使用 1Panel 等面板管理端口，UFW 可跳过。"
    read -rp "是否初始化 UFW 防火墙规则? (y/n): " choice

    if [[ "$choice" != "y" ]]; then
        info "已跳过 UFW 配置 (Fail2Ban 继续运行)"
        touch "$STATE_DIR/firewall_configured"
        return
    fi

    local SSH_PORT
    SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}' | head -1)
    SSH_PORT=${SSH_PORT:-22}
    info "检测到当前 SSH 端口: $SSH_PORT"

    ufw --force reset &>/dev/null
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow "${SSH_PORT}/tcp" comment 'SSH'
    ufw allow 80/tcp  comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'

    read -rp "是否需要额外开放端口? (直接回车跳过，多个端口用空格分隔): " extra_ports
    if [[ -n "$extra_ports" ]]; then
        for port in $extra_ports; do
            if [[ "$port" =~ ^[0-9]+(/tcp|/udp)?$ ]]; then
                ufw allow "$port" comment 'Custom'
                info "已开放端口: $port"
            else
                warn "端口格式无效，已跳过: $port"
            fi
        done
    fi

    echo "y" | ufw enable
    ufw status verbose
    touch "$STATE_DIR/firewall_configured"
    success "UFW 防火墙已启用"
    info "已开放端口: SSH(${SSH_PORT}), HTTP(80), HTTPS(443)"
}

function reset_firewall() {
    header "[重置] 关闭防火墙与 Fail2Ban"

    warn "此操作将："
    warn "  1. 禁用并重置 UFW 防火墙所有规则"
    warn "  2. 停止并禁用 Fail2Ban 服务"
    warn "  3. 恢复 fail2ban jail.local 原始配置"
    read -rp "确认关闭防护? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    # 重置 UFW
    if command -v ufw &>/dev/null; then
        ufw --force reset &>/dev/null
        ufw disable &>/dev/null
        success "UFW 已禁用并重置所有规则"
    fi

    # 停止 Fail2Ban
    if command -v fail2ban-client &>/dev/null; then
        systemctl stop fail2ban &>/dev/null
        systemctl disable fail2ban &>/dev/null

        # 恢复原始 jail.local
        if [[ -f "$STATE_DIR/jail.local.orig" ]]; then
            cp "$STATE_DIR/jail.local.orig" /etc/fail2ban/jail.local
            success "Fail2Ban jail.local 已恢复"
        else
            rm -f /etc/fail2ban/jail.local
            info "已移除自定义 jail.local，Fail2Ban 将使用默认配置"
        fi
        success "Fail2Ban 已停止"
    fi

    rm -f "$STATE_DIR/firewall_configured" "$STATE_DIR/jail.local.orig"
    success "防火墙与入侵防御已全部关闭"
    warn "服务器当前处于无防火墙状态，请谨慎操作！"
}

# ---------------------------------------------------------------
# [15] Rootkit 检测 (rkhunter)
# ---------------------------------------------------------------
function task_rkhunter() {
    header "[15] Rootkit 检测工具 (rkhunter)"

    if command -v rkhunter &>/dev/null; then
        warn "rkhunter 已安装: $(rkhunter --version | head -1)"
    else
        info "正在安装 rkhunter..."
        apt install -y rkhunter
        success "rkhunter 安装完成"
    fi

    touch "$STATE_DIR/rkhunter_installed"

    info "正在优化 rkhunter 配置..."
    local RKHUNTER_CONF="/etc/rkhunter.conf"
    if [[ -f "$RKHUNTER_CONF" ]]; then
        [[ ! -f "$STATE_DIR/rkhunter.conf.orig" ]] && \
            cp "$RKHUNTER_CONF" "$STATE_DIR/rkhunter.conf.orig"
        sed -i 's|^#SCRIPTWHITELIST=/usr/bin/ldd|SCRIPTWHITELIST=/usr/bin/ldd|' "$RKHUNTER_CONF" 2>/dev/null || true
        sed -i 's|^#WEB_CMD=.*|WEB_CMD=curl|' "$RKHUNTER_CONF" 2>/dev/null || true
        success "rkhunter 配置已优化"
    fi

    info "正在更新 rkhunter 数据库..."
    rkhunter --update --nocolors 2>/dev/null || warn "数据库更新遇到问题，继续执行..."

    info "正在建立系统文件属性基线..."
    rkhunter --propupd --nocolors &>/dev/null
    success "系统基线已建立"

    local CRON_FILE="/etc/cron.daily/rkhunter-scan"
    cat > "$CRON_FILE" << 'EOF'
#!/bin/bash
/usr/bin/rkhunter \
    --cronjob \
    --update \
    --quiet \
    --nocolors \
    --report-warnings-only \
    --logfile /var/log/rkhunter.log
exit 0
EOF
    chmod +x "$CRON_FILE"
    success "已配置每日自动扫描任务"

    echo ""
    read -rp "是否立即执行一次完整扫描? (耗时约1-2分钟) (y/n): " do_scan
    if [[ "$do_scan" == "y" ]]; then
        info "正在执行扫描，请稍候..."
        rkhunter --check --nocolors --skip-keypress 2>/dev/null || true
        info "扫描完成，详细日志: /var/log/rkhunter.log"
        warn "出现 Warning 不一定是真实威胁，需结合实际情况判断"
    fi

    echo ""
    success "rkhunter 配置完成"
    echo -e "  手动扫描: ${CYAN}rkhunter --check --sk${PLAIN}"
    echo -e "  仅看警告: ${CYAN}rkhunter --check --sk --rwo${PLAIN}"
}

function reset_rkhunter() {
    header "[重置] 卸载 rkhunter"

    if ! command -v rkhunter &>/dev/null; then
        warn "rkhunter 未安装，无需卸载"
        return
    fi

    warn "即将卸载 rkhunter 并移除定时扫描任务"
    read -rp "确认? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    apt remove -y rkhunter
    apt autoremove -y

    rm -f /etc/cron.daily/rkhunter-scan
    rm -f /var/log/rkhunter.log

    # 恢复原始配置
    if [[ -f "$STATE_DIR/rkhunter.conf.orig" ]]; then
        cp "$STATE_DIR/rkhunter.conf.orig" /etc/rkhunter.conf 2>/dev/null || true
    fi

    rm -f "$STATE_DIR/rkhunter_installed" "$STATE_DIR/rkhunter.conf.orig"
    success "rkhunter 已卸载，定时任务已移除"
}

# ---------------------------------------------------------------
# [16] 自动安全更新
# ---------------------------------------------------------------
function task_auto_updates() {
    header "[16] 配置自动安全更新"

    info "正在安装 unattended-upgrades..."
    apt install -y unattended-upgrades apt-listchanges

    # 备份原始配置
    [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]] && \
        cp /etc/apt/apt.conf.d/50unattended-upgrades \
           "$STATE_DIR/50unattended-upgrades.orig" 2>/dev/null || true

    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    systemctl enable unattended-upgrades &>/dev/null
    systemctl restart unattended-upgrades &>/dev/null
    touch "$STATE_DIR/auto_updates_configured"
    success "自动安全更新已启用 (仅更新安全补丁，不自动重启)"
}

function reset_auto_updates() {
    header "[重置] 关闭自动安全更新"

    warn "即将关闭自动安全更新"
    read -rp "确认? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    systemctl stop unattended-upgrades &>/dev/null
    systemctl disable unattended-upgrades &>/dev/null

    # 恢复原始配置或直接删除
    if [[ -f "$STATE_DIR/50unattended-upgrades.orig" ]]; then
        cp "$STATE_DIR/50unattended-upgrades.orig" \
           /etc/apt/apt.conf.d/50unattended-upgrades
        success "已恢复原始 unattended-upgrades 配置"
    else
        rm -f /etc/apt/apt.conf.d/50unattended-upgrades
    fi

    rm -f /etc/apt/apt.conf.d/20auto-upgrades
    rm -f "$STATE_DIR/auto_updates_configured" \
          "$STATE_DIR/50unattended-upgrades.orig"
    success "自动安全更新已关闭"
}

# ---------------------------------------------------------------
# [17] MOTD 系统信息美化
# ---------------------------------------------------------------
function task_motd() {
    header "[17] MOTD 系统信息美化"

    local MOTD_DIR="/etc/update-motd.d"
    local MOTD_SCRIPT="$MOTD_DIR/00-custom-info"

    info "正在禁用系统默认 MOTD 组件..."

    # 备份原始 motd 脚本的可执行状态
    if [[ ! -f "$STATE_DIR/motd_scripts_backed_up" ]]; then
        mkdir -p "$STATE_DIR/motd_perms"
        if [[ -d "$MOTD_DIR" ]]; then
            for f in "$MOTD_DIR"/*; do
                [[ -f "$f" ]] && [[ -x "$f" ]] && \
                    echo "$(basename $f)" >> "$STATE_DIR/motd_perms/executable_list.txt"
            done
        fi
        [[ -f /etc/motd ]] && cp /etc/motd "$STATE_DIR/motd.orig"
        touch "$STATE_DIR/motd_scripts_backed_up"
        info "已备份原始 MOTD 可执行状态"
    fi

    if [[ -d "$MOTD_DIR" ]]; then
        for f in "$MOTD_DIR"/*; do
            [[ -f "$f" ]] && [[ "$f" != "$MOTD_SCRIPT" ]] && \
                chmod -x "$f" 2>/dev/null || true
        done
    fi

    [[ -f /etc/motd ]] && > /etc/motd

    sed -i 's/^session\s*optional\s*pam_motd.so.*/#&/' /etc/pam.d/sshd 2>/dev/null || true
    sed -i 's/^session\s*optional\s*pam_motd.so.*/#&/' /etc/pam.d/login 2>/dev/null || true

    info "正在安装依赖工具 (figlet)..."
    apt install -y figlet bc 2>/dev/null || true

    cat > "$MOTD_SCRIPT" << 'MOTD_EOF'
#!/bin/bash
# ==============================================================
#  Custom MOTD - Server Info Display
# ==============================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
BOLD='\033[1m'

HOSTNAME=$(hostname -f 2>/dev/null || hostname)
OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || uname -s)
KERNEL=$(uname -r)
ARCH=$(uname -m)
UPTIME_RAW=$(cat /proc/uptime | awk '{print $1}')
UPTIME_DAYS=$(echo "$UPTIME_RAW" | awk '{printf "%d", $1/86400}')
UPTIME_HOURS=$(echo "$UPTIME_RAW" | awk '{printf "%d", ($1%86400)/3600}')
UPTIME_MINS=$(echo "$UPTIME_RAW" | awk '{printf "%d", ($1%3600)/60}')
UPTIME_STR="${UPTIME_DAYS}天 ${UPTIME_HOURS}小时 ${UPTIME_MINS}分钟"

CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //' | sed 's/  */ /g')
CPU_CORES=$(nproc)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "0")

MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_AVAIL_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAIL_KB))
MEM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))
MEM_USED_MB=$((MEM_USED_KB / 1024))
MEM_PERCENT=$((MEM_USED_KB * 100 / MEM_TOTAL_KB))

DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
DISK_USED=$(df -h / | awk 'NR==2{print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2{print $4}')
DISK_PERCENT=$(df / | awk 'NR==2{print $5}' | tr -d '%')

LOAD_1=$(cat /proc/loadavg | awk '{print $1}')
LOAD_5=$(cat /proc/loadavg | awk '{print $2}')
LOAD_15=$(cat /proc/loadavg | awk '{print $3}')
PROCESS_COUNT=$(cat /proc/loadavg | awk -F'/' '{print $2}' | awk '{print $1}')

PUB_IP=$(curl -s4m3 ifconfig.me 2>/dev/null || curl -s4m3 ip.sb 2>/dev/null || echo "获取失败")
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

SWAP_TOTAL=$(free -m | awk '/Swap/{print $2}')
SWAP_USED=$(free -m | awk '/Swap/{print $3}')

LAST_LOGIN=$(last -n 2 -F "$USER" 2>/dev/null | grep -v "^$\|still logged" | tail -1)
FAIL_COUNT=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l || echo "0")
BANNED_IP_COUNT=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP" | awk '{print $NF}' || echo "0")
TCP_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")

function draw_bar() {
    local percent=$1
    local total=20
    local filled=$((percent * total / 100))
    local empty=$((total - filled))
    local bar="" color
    if   [[ $percent -lt 50 ]]; then color=$G
    elif [[ $percent -lt 80 ]]; then color=$Y
    else                              color=$R
    fi
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty;  i++)); do bar+="░"; done
    echo -e "${color}${bar}${N} ${color}${percent}%${N}"
}

function pct_color() {
    local pct=$1
    if   [[ $pct -lt 50 ]]; then echo -e "${G}${pct}%${N}"
    elif [[ $pct -lt 80 ]]; then echo -e "${Y}${pct}%${N}"
    else                          echo -e "${R}${pct}%${N}"
    fi
}

echo -e ""
if command -v figlet &>/dev/null; then
    echo -e "${C}$(figlet -f small "  $(hostname -s)" 2>/dev/null || figlet "Server")${N}"
else
    echo -e "${C}${BOLD}       ╔══════════════════════════════════╗        ${N}"
    echo -e "${C}${BOLD}       ║   Welcome to $(hostname -s | cut -c1-16)   ║        ${N}"
    echo -e "${C}${BOLD}       ╚══════════════════════════════════╝        ${N}"
fi

echo -e "${B}  ══════════════════════════════════════════════════════${N}"
echo -e ""
echo -e "  ${W}🖥  系统信息${N}"
echo -e "  ${C}主机名  ${N}  ${W}${HOSTNAME}${N}"
echo -e "  ${C}系统    ${N}  ${OS}"
echo -e "  ${C}内核    ${N}  ${KERNEL} (${ARCH})"
echo -e "  ${C}运行时间${N}  ${UPTIME_STR}"
echo -e "  ${C}TCP算法 ${N}  ${TCP_CC}"
echo -e ""
echo -e "  ${W}🌐  网络信息${N}"
echo -e "  ${C}公网IP  ${N}  ${W}${PUB_IP}${N}"
echo -e "  ${C}内网IP  ${N}  ${LOCAL_IP}"
echo -e ""
echo -e "${B}  ──────────────────────────────────────────────────────${N}"
echo -e ""
echo -e "  ${W}📊  资源状态${N}"
echo -e ""
printf "  ${C}%-8s${N}" "CPU"
echo -e "  ${CPU_MODEL} x${CPU_CORES}核  使用率: $(pct_color $CPU_USAGE)"
printf "  ${C}%-8s${N}" "内存"
printf "  ${W}%4dMB${N} / ${W}%4dMB${N}  " "$MEM_USED_MB" "$MEM_TOTAL_MB"
draw_bar "$MEM_PERCENT"
if [[ "$SWAP_TOTAL" -gt 0 ]]; then
    SWAP_PERCENT=$((SWAP_USED * 100 / SWAP_TOTAL))
    printf "  ${C}%-8s${N}" "Swap"
    printf "  ${W}%4dMB${N} / ${W}%4dMB${N}  " "$SWAP_USED" "$SWAP_TOTAL"
    draw_bar "$SWAP_PERCENT"
else
    echo -e "  ${C}Swap    ${N}  ${Y}未配置${N}"
fi
printf "  ${C}%-8s${N}" "磁盘(/)"
printf "  ${W}%6s${N} / ${W}%6s${N}  剩余: ${W}%s${N}  " "$DISK_USED" "$DISK_TOTAL" "$DISK_AVAIL"
draw_bar "$DISK_PERCENT"
echo -e ""
echo -e "  ${C}系统负载${N}  ${LOAD_1} (1min)  ${LOAD_5} (5min)  ${LOAD_15} (15min)  进程数: ${PROCESS_COUNT}"
echo -e ""
echo -e "${B}  ──────────────────────────────────────────────────────${N}"
echo -e ""
echo -e "  ${W}🔐  安全状态${N}"
echo -e ""
if [[ "$FAIL_COUNT" -gt 100 ]]; then FC=$R
elif [[ "$FAIL_COUNT" -gt 20 ]]; then FC=$Y
else FC=$G; fi
echo -e "  ${C}SSH失败次数${N}    ${FC}${FAIL_COUNT} 次${N}  (来自 /var/log/auth.log)"
if command -v fail2ban-client &>/dev/null && systemctl is-active --quiet fail2ban 2>/dev/null; then
    echo -e "  ${C}Fail2Ban封禁${N}   ${Y}${BANNED_IP_COUNT} 个IP${N}"
else
    echo -e "  ${C}Fail2Ban    ${N}   ${Y}未运行${N}"
fi
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1 | awk '{print $2}')
    [[ "$UFW_STATUS" == "active" ]] && \
        echo -e "  ${C}防火墙UFW   ${N}   ${G}已启用${N}" || \
        echo -e "  ${C}防火墙UFW   ${N}   ${Y}未启用${N}"
fi
[[ -n "$LAST_LOGIN" ]] && echo -e "  ${C}上次登录    ${N}   ${LAST_LOGIN}"
echo -e ""
echo -e "${B}  ══════════════════════════════════════════════════════${N}"
echo -e "  ${Y}  $(date '+%Y-%m-%d %H:%M:%S %Z')${N}"
echo -e "${B}  ══════════════════════════════════════════════════════${N}"
echo -e ""
MOTD_EOF

    chmod +x "$MOTD_SCRIPT"

    grep -qE "^#?PrintMotd" /etc/ssh/sshd_config && \
        sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config || \
        echo "PrintMotd yes" >> /etc/ssh/sshd_config

    grep -qE "^#?PrintLastLog" /etc/ssh/sshd_config && \
        sed -i 's/^#\?PrintLastLog.*/PrintLastLog no/' /etc/ssh/sshd_config || \
        echo "PrintLastLog no" >> /etc/ssh/sshd_config

    sshd -t 2>/dev/null && systemctl restart sshd

    echo ""
    read -rp "是否立即预览 MOTD 效果? (y/n): " preview
    [[ "$preview" == "y" ]] && bash "$MOTD_SCRIPT"

    touch "$STATE_DIR/motd_customized"
    success "MOTD 美化配置完成"
    echo -e "  MOTD脚本: ${CYAN}$MOTD_SCRIPT${PLAIN}"
    echo -e "  修改:     ${YELLOW}nano $MOTD_SCRIPT${PLAIN}"
    echo -e "  预览:     ${YELLOW}bash $MOTD_SCRIPT${PLAIN}"
}

function reset_motd() {
    header "[重置] 恢复默认 MOTD"

    if [[ ! -f "$STATE_DIR/motd_scripts_backed_up" ]]; then
        warn "未找到 MOTD 备份记录"
        return
    fi

    warn "即将移除自定义 MOTD，恢复系统默认登录信息"
    read -rp "确认? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    # 删除自定义脚本
    rm -f /etc/update-motd.d/00-custom-info

    # 恢复原始脚本的可执行权限
    if [[ -f "$STATE_DIR/motd_perms/executable_list.txt" ]]; then
        while read -r script_name; do
            local script_path="/etc/update-motd.d/$script_name"
            [[ -f "$script_path" ]] && chmod +x "$script_path"
        done < "$STATE_DIR/motd_perms/executable_list.txt"
        success "已恢复原始 MOTD 脚本的可执行权限"
    fi

    # 恢复 /etc/motd
    if [[ -f "$STATE_DIR/motd.orig" ]]; then
        cp "$STATE_DIR/motd.orig" /etc/motd
    fi

    # 恢复 PAM motd 配置
    sed -i 's/^#\(session.*pam_motd\.so\)/\1/' /etc/pam.d/sshd 2>/dev/null || true
    sed -i 's/^#\(session.*pam_motd\.so\)/\1/' /etc/pam.d/login 2>/dev/null || true

    rm -f "$STATE_DIR/motd_customized" "$STATE_DIR/motd_scripts_backed_up" \
          "$STATE_DIR/motd.orig" "$STATE_DIR/motd_perms/executable_list.txt"
    rmdir "$STATE_DIR/motd_perms" 2>/dev/null || true

    success "MOTD 已恢复为系统默认"
}

# ---------------------------------------------------------------
# [18] ZSH + 插件环境
# ---------------------------------------------------------------
function task_zsh() {
    header "[18] ZSH + 插件环境"

    if ! command -v zsh &>/dev/null; then
        info "正在安装 Zsh..."
        apt install -y zsh
        success "Zsh 安装完成: $(zsh --version)"
    else
        success "Zsh 已安装: $(zsh --version)"
    fi

    ! command -v git &>/dev/null && apt install -y git

    echo ""
    echo -e "请选择为哪个用户安装 ZSH 环境："
    echo -e "  ${GREEN}1.${PLAIN} 仅 root 用户"
    echo -e "  ${GREEN}2.${PLAIN} 指定普通用户"
    echo -e "  ${GREEN}3.${PLAIN} root + 指定普通用户"
    read -rp "请输入选择 [1-3]: " user_choice

    declare -a TARGET_USERS=()
    case "$user_choice" in
        1) TARGET_USERS=("root") ;;
        2)
            read -rp "请输入用户名: " target_user
            id "$target_user" &>/dev/null || { error "用户 '$target_user' 不存在"; return 1; }
            TARGET_USERS=("$target_user")
            ;;
        3)
            read -rp "请输入普通用户名: " target_user
            id "$target_user" &>/dev/null || { error "用户 '$target_user' 不存在"; return 1; }
            TARGET_USERS=("root" "$target_user")
            ;;
        *) warn "无效选择，默认仅安装到 root"; TARGET_USERS=("root") ;;
    esac

    for INSTALL_USER in "${TARGET_USERS[@]}"; do
        [[ "$INSTALL_USER" == "root" ]] && USER_HOME="/root" || \
            USER_HOME=$(getent passwd "$INSTALL_USER" | cut -d: -f6)

        print_line
        info "正在为用户 ${BOLD}${INSTALL_USER}${PLAIN} 安装 ZSH 环境..."

        local OMZ_DIR="$USER_HOME/.oh-my-zsh"

        # 记录安装目标
        echo "$INSTALL_USER:$USER_HOME" >> "$STATE_DIR/zsh_installed_users.txt"

        if [[ ! -d "$OMZ_DIR" ]]; then
            info "正在安装 Oh-My-Zsh..."
            if [[ "$INSTALL_USER" == "root" ]]; then
                env RUNZSH=no CHSH=no \
                    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || \
                env RUNZSH=no CHSH=no \
                    sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)"
            else
                sudo -u "$INSTALL_USER" env RUNZSH=no CHSH=no HOME="$USER_HOME" \
                    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || \
                sudo -u "$INSTALL_USER" env RUNZSH=no CHSH=no HOME="$USER_HOME" \
                    sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)"
            fi
            [[ -d "$OMZ_DIR" ]] && success "Oh-My-Zsh 安装完成" || { error "Oh-My-Zsh 安装失败"; continue; }
        else
            warn "Oh-My-Zsh 已存在，跳过安装"
        fi

        local ZSH_CUSTOM="$OMZ_DIR/custom"

        for plugin_info in \
            "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions:https://gitee.com/mirrors/zsh-autosuggestions" \
            "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting:https://gitee.com/mirrors/zsh-syntax-highlighting" \
            "zsh-completions:https://github.com/zsh-users/zsh-completions:"; do

            local plugin_name="${plugin_info%%:*}"
            local rest="${plugin_info#*:}"
            local primary_url="${rest%%:*}"
            local fallback_url="${rest##*:}"
            local plugin_dir="$ZSH_CUSTOM/plugins/$plugin_name"

            if [[ ! -d "$plugin_dir" ]]; then
                info "正在安装 $plugin_name..."
                git clone --depth=1 "$primary_url" "$plugin_dir" 2>/dev/null || \
                    { [[ -n "$fallback_url" ]] && git clone --depth=1 "$fallback_url" "$plugin_dir" 2>/dev/null; }
                [[ -d "$plugin_dir" ]] && success "$plugin_name 安装完成" || warn "$plugin_name 安装失败，跳过"
            else
                warn "$plugin_name 已存在，跳过"
            fi
        done

        local ZSHRC="$USER_HOME/.zshrc"
        [[ -f "$ZSHRC" ]] && cp "$ZSHRC" "${ZSHRC}.bak.$(date +%F_%H%M%S)" && info "已备份原 .zshrc"

        cat > "$ZSHRC" << ZSHRC_EOF
# ==============================================================
#  ZSH 配置文件 - 由 server-init 脚本生成
# ==============================================================

export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="ys"

zstyle ':omz:update' mode reminder
zstyle ':omz:update' frequency 7

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    sudo
    colored-man-pages
    command-not-found
    extract
    z
)

source "\$ZSH/oh-my-zsh.sh"

export LANG=en_US.UTF-8
export EDITOR='vim'
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoredups:erasedups

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# --- 系统操作 ---
alias ll='ls -alFh --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ls='ls --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -iv'
alias mkdir='mkdir -pv'
alias df='df -hT'
alias du='du -sh'
alias free='free -mh'
alias ps='ps auxf'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias tree='tree -C'

# --- 网络工具 ---
alias myip='curl -s4 ifconfig.me && echo'
alias myip6='curl -s6 ifconfig.me && echo'
alias ping='ping -c 5'
alias ports='ss -tulnp'
alias netstat='ss -tulnp'

# --- 系统监控 ---
alias top='htop'
alias mem='free -mh'
alias disk='df -hT'
alias load='cat /proc/loadavg'
alias psg='ps aux | grep -v grep | grep -i'

# --- 系统管理 ---
alias update='apt update && apt upgrade -y'
alias install='apt install -y'
alias remove='apt remove -y'
alias search='apt search'
alias svc='systemctl'
alias sstatus='systemctl status'
alias srestart='systemctl restart'
alias sstop='systemctl stop'
alias sstart='systemctl start'
alias senable='systemctl enable'
alias sdisable='systemctl disable'
alias slog='journalctl -u'
alias slogf='journalctl -fu'

# --- Docker ---
alias dk='docker'
alias dkps='docker ps'
alias dkpsa='docker ps -a'
alias dklogs='docker logs -f'
alias dkexec='docker exec -it'
alias dkup='docker-compose up -d'
alias dkdown='docker-compose down'
alias dkrestart='docker-compose restart'

# --- Git ---
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate --all'
alias gd='git diff'

# --- 安全相关 ---
alias f2b='fail2ban-client status'
alias f2bssh='fail2ban-client status sshd'
alias ufws='ufw status verbose'
alias lastlog='last -n 20'
alias whofail='grep "Failed password" /var/log/auth.log | tail -20'

# --- 实用函数 ---
extract() {
    if [[ -f "\$1" ]]; then
        case "\$1" in
            *.tar.bz2)  tar xjf "\$1"    ;;
            *.tar.gz)   tar xzf "\$1"    ;;
            *.tar.xz)   tar xJf "\$1"    ;;
            *.bz2)      bunzip2 "\$1"    ;;
            *.gz)       gunzip "\$1"     ;;
            *.tar)      tar xf "\$1"     ;;
            *.zip)      unzip "\$1"      ;;
            *.7z)       7z x "\$1"       ;;
            *)          echo "无法识别的格式: \$1" ;;
        esac
    else
        echo "文件不存在: \$1"
    fi
}

port()  { ss -tulnp | grep ":\${1}" ; }
mkcd()  { mkdir -p "\$1" && cd "\$1" ; }
hist()  { history | grep "\$1" ; }
bak()   { cp "\$1" "\${1}.bak.\$(date +%Y%m%d%H%M%S)" ; }
ipinfo(){ curl -s "https://ipinfo.io/\${1:-}" | python3 -m json.tool 2>/dev/null || curl -s "https://ipinfo.io/\${1:-}"; }

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select

setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS

stty -ixon 2>/dev/null || true

autoload -U compinit && compinit
ZSHRC_EOF

        [[ "$INSTALL_USER" != "root" ]] && \
            chown -R "$INSTALL_USER:$INSTALL_USER" "$ZSHRC" "$OMZ_DIR" 2>/dev/null || true

        success "用户 $INSTALL_USER 的 .zshrc 配置完成"

        local ZSH_PATH
        ZSH_PATH=$(command -v zsh)
        grep -qx "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" >> /etc/shells

        echo ""
        read -rp "是否将 $INSTALL_USER 的默认 Shell 切换为 Zsh? (y/n): " change_shell
        if [[ "$change_shell" == "y" ]]; then
            # 记录原始 Shell
            local orig_shell
            orig_shell=$(getent passwd "$INSTALL_USER" | cut -d: -f7)
            echo "$INSTALL_USER:$orig_shell" >> "$STATE_DIR/zsh_original_shells.txt"

            chsh -s "$ZSH_PATH" "$INSTALL_USER" && \
                success "用户 $INSTALL_USER 默认 Shell 已切换为 Zsh (重新登录后生效)" || \
                error "切换失败，请手动: chsh -s $ZSH_PATH $INSTALL_USER"
        fi
    done

    echo ""
    success "ZSH 环境安装完成"
    echo -e "  立即生效: ${YELLOW}exec zsh${PLAIN}"
    echo -e "  修改配置: ${YELLOW}nano ~/.zshrc && source ~/.zshrc${PLAIN}"
    echo -e "  快捷键:   → 接受补全  |  Tab 补全菜单  |  ESC×2 加sudo"
}

function reset_zsh() {
    header "[重置] 卸载 ZSH 环境"

    if [[ ! -f "$STATE_DIR/zsh_installed_users.txt" ]]; then
        warn "未找到 ZSH 安装记录"
        return
    fi

    echo -e "已安装 ZSH 的用户:"
    cat "$STATE_DIR/zsh_installed_users.txt" | cut -d: -f1 | while read -r u; do
        echo -e "  ${GREEN}$u${PLAIN}"
    done
    echo ""

    warn "即将为以上所有用户卸载 Oh-My-Zsh，恢复原始 Shell 和 .zshrc"
    read -rp "确认? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    while IFS=: read -r INSTALL_USER USER_HOME; do
        print_line
        info "正在为用户 $INSTALL_USER 卸载 ZSH 环境..."

        # 删除 Oh-My-Zsh
        [[ -d "$USER_HOME/.oh-my-zsh" ]] && rm -rf "$USER_HOME/.oh-my-zsh" && \
            success "已删除 $USER_HOME/.oh-my-zsh"

        # 恢复 .zshrc 备份（取最旧的备份）
        local oldest_zshrc_bak
        oldest_zshrc_bak=$(ls -t "$USER_HOME"/.zshrc.bak.* 2>/dev/null | tail -1)
        if [[ -n "$oldest_zshrc_bak" ]]; then
            cp "$oldest_zshrc_bak" "$USER_HOME/.zshrc"
            success "已恢复原始 .zshrc: $oldest_zshrc_bak"
        else
            rm -f "$USER_HOME/.zshrc"
            info "已删除 .zshrc（无历史备份）"
        fi

        # 恢复原始 Shell
        if [[ -f "$STATE_DIR/zsh_original_shells.txt" ]]; then
            local orig_shell
            orig_shell=$(grep "^${INSTALL_USER}:" "$STATE_DIR/zsh_original_shells.txt" | cut -d: -f2)
            if [[ -n "$orig_shell" ]] && [[ -f "$orig_shell" ]]; then
                chsh -s "$orig_shell" "$INSTALL_USER" && \
                    success "用户 $INSTALL_USER 的 Shell 已恢复为: $orig_shell"
            fi
        fi

    done < "$STATE_DIR/zsh_installed_users.txt"

    rm -f "$STATE_DIR/zsh_installed_users.txt" \
          "$STATE_DIR/zsh_original_shells.txt"
    success "ZSH 环境已卸载完成"
}

# ---------------------------------------------------------------
# [0] 一键全流程
# ---------------------------------------------------------------
function task_all() {
    header "一键全流程初始化"
    warn "将依次执行所有基础配置任务"
    read -rp "确认开始? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    task_source; task_essentials; task_hostname; task_timezone
    task_bbr; task_swap; task_sysctl; task_create_user
    task_ssh; task_ssh_port; task_firewall; task_rkhunter
    task_auto_updates; task_motd; task_zsh

    header "🎉 基础初始化完成"
    success "所有基础任务已执行完毕！"
    print_line

    read -rp "是否配置 SSH 登录 Telegram 通知? (y/n): " n
    [[ "$n" == "y" ]] && task_ssh_notify

    read -rp "是否安装 Docker? (y/n): " d
    [[ "$d" == "y" ]] && task_docker

    read -rp "是否安装 1Panel 面板? (y/n): " p
    [[ "$p" == "y" ]] && task_1panel

    print_line
    echo -e "${YELLOW}  建议重启服务器以确保所有内核参数完全生效${PLAIN}"
    read -rp "是否立即重启? (y/n): " reboot_now
    [[ "$reboot_now" == "y" ]] && reboot
}

# ==============================================================
#  重置/回退 子菜单
# ==============================================================
function show_reset_menu() {
    while true; do
        clear
        echo -e "${RED}=============================================================${PLAIN}"
        echo -e "${BOLD}              ⚠️   重置 / 回退操作中心                    ${PLAIN}"
        echo -e "${RED}=============================================================${PLAIN}"
        echo -e ""
        echo -e "  ${YELLOW}所有重置操作均不可撤销，请谨慎操作！${PLAIN}"
        echo -e ""
        echo -e " ${CYAN}[ 系统基础 ]${PLAIN}"
        echo -e "   ${RED}r1.${PLAIN}  恢复原始软件源"
        echo -e "   ${RED}r2.${PLAIN}  卸载基础软件包"
        echo -e "   ${RED}r3.${PLAIN}  恢复原始时区"
        echo -e "   ${RED}r4.${PLAIN}  关闭 TCP BBR"
        echo -e "   ${RED}r5.${PLAIN}  关闭并删除 Swap"
        echo -e "   ${RED}r6.${PLAIN}  恢复原始主机名"
        echo -e "   ${RED}r7.${PLAIN}  移除内核参数优化"
        echo -e ""
        echo -e " ${CYAN}[ 软件应用 ]${PLAIN}"
        echo -e "   ${RED}r8.${PLAIN}  卸载 Docker"
        echo -e "   ${RED}r9.${PLAIN}  卸载 1Panel"
        echo -e ""
        echo -e " ${CYAN}[ 安全加固 ]${PLAIN}"
        echo -e "   ${RED}r10.${PLAIN} 删除创建的用户"
        echo -e "   ${RED}r11.${PLAIN} 恢复 SSH 原始配置 ${YELLOW}(重新开启密码登录)${PLAIN}"
        echo -e "   ${RED}r12.${PLAIN} 恢复原始 SSH 端口"
        echo -e "   ${RED}r13.${PLAIN} 关闭 SSH Telegram 通知"
        echo -e "   ${RED}r14.${PLAIN} 关闭防火墙与 Fail2Ban"
        echo -e "   ${RED}r15.${PLAIN} 卸载 rkhunter"
        echo -e "   ${RED}r16.${PLAIN} 关闭自动安全更新"
        echo -e ""
        echo -e " ${CYAN}[ 体验优化 ]${PLAIN}"
        echo -e "   ${RED}r17.${PLAIN} 恢复默认 MOTD"
        echo -e "   ${RED}r18.${PLAIN} 卸载 ZSH 环境"
        echo -e ""
        echo -e " ${CYAN}[ 其他 ]${PLAIN}"
        echo -e "   ${GREEN}cache.${PLAIN} 清空本地脚本缓存"
        echo -e "   ${GREEN}state.${PLAIN} 查看已保存的状态信息"
        echo -e ""
        echo -e "${RED}-------------------------------------------------------------${PLAIN}"
        echo -e "   ${GREEN}b.${PLAIN}   返回主菜单"
        echo -e "${RED}=============================================================${PLAIN}"
        echo -e ""

        read -rp " 请输入重置选项: " choice
        echo ""

        case "$choice" in
            r1)   reset_source ;;
            r2)   reset_essentials ;;
            r3)   reset_timezone ;;
            r4)   reset_bbr ;;
            r5)   reset_swap ;;
            r6)   reset_hostname ;;
            r7)   reset_sysctl ;;
            r8)   reset_docker ;;
            r9)   reset_1panel ;;
            r10)  reset_create_user ;;
            r11)  reset_ssh ;;
            r12)  reset_ssh_port ;;
            r13)  reset_ssh_notify ;;
            r14)  reset_firewall ;;
            r15)  reset_rkhunter ;;
            r16)  reset_auto_updates ;;
            r17)  reset_motd ;;
            r18)  reset_zsh ;;
            cache) clear_cache ;;
            state)
                echo -e "${CYAN}已保存的状态文件列表:${PLAIN}"
                ls -lh "$STATE_DIR"/ 2>/dev/null || echo "  (空)"
                echo -e "${CYAN}脚本缓存文件列表:${PLAIN}"
                ls -lh "$CACHE_DIR"/ 2>/dev/null || echo "  (空)"
                ;;
            b|B) return ;;
            *) error "无效输入: '$choice'" ;;
        esac

        echo ""
        read -rp " 按回车键继续..."
    done
}

# ==============================================================
#  主菜单界面
# ==============================================================
function show_menu() {
    while true; do
        clear
        echo -e "${BLUE}=============================================================${PLAIN}"
        echo -e "${BOLD}          🚀  Linux 服务器初始化助手  (Pro V8)           ${PLAIN}"
        echo -e "${BLUE}=============================================================${PLAIN}"
        show_sysinfo
        echo -e "${BLUE}-------------------------------------------------------------${PLAIN}"
        echo -e ""
        echo -e " ${CYAN}[ 系统基础 ]${PLAIN}"
        echo -e "   ${GREEN}1.${PLAIN}   配置软件源"
        echo -e "   ${GREEN}2.${PLAIN}   安装基础工具"
        echo -e "   ${GREEN}3.${PLAIN}   配置系统时区 ${CYAN}(含NTP同步)${PLAIN}"
        echo -e "   ${GREEN}4.${PLAIN}   开启 TCP BBR"
        echo -e "   ${GREEN}5.${PLAIN}   配置 Swap 交换空间"
        echo -e "   ${GREEN}6.${PLAIN}   配置主机名"
        echo -e "   ${GREEN}7.${PLAIN}   内核网络参数优化"
        echo -e ""
        echo -e " ${CYAN}[ 软件应用 ]${PLAIN}"
        echo -e "   ${GREEN}8.${PLAIN}   安装 Docker"
        echo -e "   ${GREEN}9.${PLAIN}   安装 1Panel 面板"
        echo -e ""
        echo -e " ${CYAN}[ 安全加固 ]${PLAIN}"
        echo -e "   ${GREEN}10.${PLAIN}  创建普通用户 ${CYAN}(sudo权限 + SSH同步)${PLAIN}"
        echo -e "   ${GREEN}11.${PLAIN}  配置 SSH 密钥登录 ${RED}(禁密码)${PLAIN}"
        echo -e "   ${GREEN}12.${PLAIN}  修改 SSH 端口 ${CYAN}(联动UFW/Fail2Ban)${PLAIN}"
        echo -e "   ${GREEN}13.${PLAIN}  SSH 登录 Telegram 通知"
        echo -e "   ${GREEN}14.${PLAIN}  防火墙与入侵防御 ${YELLOW}(UFW & Fail2Ban)${PLAIN}"
        echo -e "   ${GREEN}15.${PLAIN}  Rootkit 检测工具 ${CYAN}(rkhunter)${PLAIN}"
        echo -e "   ${GREEN}16.${PLAIN}  配置自动安全更新"
        echo -e ""
        echo -e " ${CYAN}[ 体验优化 ]${PLAIN}"
        echo -e "   ${GREEN}17.${PLAIN}  MOTD 系统信息美化"
        echo -e "   ${GREEN}18.${PLAIN}  ZSH + 插件环境 ${CYAN}(Oh-My-Zsh / 补全 / 高亮)${PLAIN}"
        echo -e ""
        echo -e "${BLUE}-------------------------------------------------------------${PLAIN}"
        echo -e "   ${GREEN}0.${PLAIN}   ${BOLD}一键执行全部基础配置${PLAIN}"
        echo -e "   ${RED}r.${PLAIN}   ${BOLD}重置 / 回退操作中心${PLAIN}"
        echo -e "   ${GREEN}q.${PLAIN}   退出脚本"
        echo -e "${BLUE}=============================================================${PLAIN}"
        echo -e ""

        read -rp " 请输入选项编号: " choice
        echo ""

        case "$choice" in
            1)   task_source ;;
            2)   task_essentials ;;
            3)   task_timezone ;;
            4)   task_bbr ;;
            5)   task_swap ;;
            6)   task_hostname ;;
            7)   task_sysctl ;;
            8)   task_docker ;;
            9)   task_1panel ;;
            10)  task_create_user ;;
            11)  task_ssh ;;
            12)  task_ssh_port ;;
            13)  task_ssh_notify ;;
            14)  task_firewall ;;
            15)  task_rkhunter ;;
            16)  task_auto_updates ;;
            17)  task_motd ;;
            18)  task_zsh ;;
            0)   task_all ;;
            r|R) show_reset_menu ;;
            q|Q) success "已退出脚本"; exit 0 ;;
            *)   error "无效输入: '$choice'，请重新选择" ;;
        esac

        echo ""
        read -rp " 按回车键返回主菜单..."
    done
}

# --- 启动 ---
show_menu
