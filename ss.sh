#!/bin/bash

# ==============================================================
#  Linux Server Initialization Script (Ultimate Edition v7)
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
    echo -e "请选择服务器网络环境："
    echo -e "  ${GREEN}1.${PLAIN} 国内服务器 (清华/中科大/阿里等镜像)"
    echo -e "  ${GREEN}2.${PLAIN} 海外服务器 (官方源/全球CDN)"
    echo -e "  ${GREEN}3.${PLAIN} 跳过"
    read -rp "请输入选择 [1-3]: " choice

    case "$choice" in
        1) bash <(curl -sSL https://linuxmirrors.cn/main.sh) ;;
        2) bash <(curl -sSL https://linuxmirrors.cn/main.sh) --abroad ;;
        *) warn "已跳过软件源配置" ;;
    esac
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

    info "正在安装软件包: ${PACKAGES[*]}"
    apt install -y "${PACKAGES[@]}"
    success "基础系统工具安装完成"
}

# ---------------------------------------------------------------
# [3] 配置系统时区
# ---------------------------------------------------------------
function task_timezone() {
    header "[3] 配置系统时区"

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

# ---------------------------------------------------------------
# [5] 配置 Swap
# ---------------------------------------------------------------
function task_swap() {
    header "[5] 配置 Swap 交换空间"

    local current_swap
    current_swap=$(free -h | awk '/Swap/{print $2}')
    info "当前 Swap 大小: $current_swap"
    swapon --show

    info "正在拉取 Swap 管理脚本..."
    bash <(curl -sL https://raw.githubusercontent.com/walllal/bash/refs/heads/main/swap.sh)
}

# ---------------------------------------------------------------
# [6] 配置主机名
# ---------------------------------------------------------------
function task_hostname() {
    header "[6] 配置服务器主机名"
    echo -e "当前主机名: ${GREEN}$(hostname)${PLAIN}"
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
    success "内核参数优化完成，配置文件: $SYSCTL_CONF"
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

    info "正在通过 LinuxMirrors 安装 Docker..."
    bash <(curl -sSL https://linuxmirrors.cn/docker.sh)

    if command -v docker &>/dev/null; then
        systemctl enable docker &>/dev/null
        systemctl start docker &>/dev/null
        success "Docker 安装成功: $(docker --version)"
    else
        error "Docker 安装未成功，请手动检查"
        return 1
    fi
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

    info "启动 1Panel 官方安装脚本..."
    bash <(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)
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

    local BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%F_%H%M%S)"
    cp /etc/ssh/sshd_config "$BACKUP_FILE"
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
    success "SSH 密钥登录配置完成，密码登录已禁用"
    echo ""
    warn "════════════════════════════════════════════════"
    warn "  ⚠️  请立即新开终端测试 SSH 连接！"
    warn "  确认可以正常登录后，再关闭当前终端！"
    warn "════════════════════════════════════════════════"
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

    systemctl restart sshd
    success "SSH 端口已成功修改: ${CURRENT_PORT} → ${NEW_PORT}"

    echo ""
    warn "════════════════════════════════════════════════════════"
    warn "  ⚠️  重要：请立即新开终端，使用新端口测试连接！"
    warn "  连接命令: ssh -p ${NEW_PORT} root@<你的IP>"
    warn "  确认连接成功后，再关闭当前终端！"
    warn "════════════════════════════════════════════════════════"
}

# ---------------------------------------------------------------
# [13] SSH 登录 Telegram 通知
# ---------------------------------------------------------------
function task_ssh_notify() {
    header "[13] SSH 登录 Telegram 通知"

    local NOTIFY_SCRIPT="/etc/profile.d/ssh-login-notify.sh"

    echo -e "功能说明：每次有用户通过 SSH 登录服务器，将向指定 Telegram 发送通知"
    echo -e "通知内容：登录用户、来源IP、地理位置、登录时间、主机名"
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
        error "测试消息发送失败 (HTTP $TEST_RESULT)，请检查 Token 和 Chat ID 是否正确"
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
    success "SSH 登录通知脚本已安装: $NOTIFY_SCRIPT"
    info "从下次 SSH 登录开始，将自动发送 Telegram 通知"
    echo ""
    echo -e "  如需停用通知: ${YELLOW}rm $NOTIFY_SCRIPT${PLAIN}"
    echo -e "  如需修改配置: ${YELLOW}nano $NOTIFY_SCRIPT${PLAIN}"
}

# ---------------------------------------------------------------
# [14] 防火墙与入侵防御 (UFW & Fail2Ban)
# ---------------------------------------------------------------
function task_firewall() {
    header "[14] 安全防护配置 (UFW & Fail2Ban)"

    info "正在安装 UFW 和 Fail2Ban..."
    apt install -y ufw fail2ban

    info "正在配置 Fail2Ban..."
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
    success "UFW 防火墙已启用"
    info "已开放端口: SSH(${SSH_PORT}), HTTP(80), HTTPS(443)"
}

# ---------------------------------------------------------------
# [15] Rootkit 检测 (rkhunter)
# ---------------------------------------------------------------
function task_rkhunter() {
    header "[15] Rootkit 检测工具 (rkhunter)"

    echo -e "rkhunter 可检测："
    echo -e "  • Rootkit / 后门程序"
    echo -e "  • 可疑的本地文件和二进制文件"
    echo -e "  • 系统命令是否被替换"
    echo -e "  • 网络端口、启动文件、日志异常"
    echo ""

    if command -v rkhunter &>/dev/null; then
        warn "rkhunter 已安装: $(rkhunter --version | head -1)"
    else
        info "正在安装 rkhunter..."
        apt install -y rkhunter
        success "rkhunter 安装完成"
    fi

    info "正在优化 rkhunter 配置..."
    local RKHUNTER_CONF="/etc/rkhunter.conf"
    if [[ -f "$RKHUNTER_CONF" ]]; then
        cp "$RKHUNTER_CONF" "${RKHUNTER_CONF}.bak.$(date +%F)" 2>/dev/null || true
        sed -i 's|^#SCRIPTWHITELIST=/usr/bin/ldd|SCRIPTWHITELIST=/usr/bin/ldd|' "$RKHUNTER_CONF" 2>/dev/null || true
        sed -i 's|^#WEB_CMD=.*|WEB_CMD=curl|' "$RKHUNTER_CONF" 2>/dev/null || true
        success "rkhunter 配置已优化"
    fi

    info "正在更新 rkhunter 数据库..."
    if rkhunter --update --nocolors 2>/dev/null; then
        success "数据库更新完成"
    else
        warn "数据库更新遇到问题 (可能是网络原因)，继续执行..."
    fi

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
    else
        info "已跳过立即扫描，系统将每天凌晨自动执行"
    fi

    echo ""
    success "rkhunter 配置完成"
    echo -e "  手动扫描: ${CYAN}rkhunter --check --sk${PLAIN}"
    echo -e "  仅看警告: ${CYAN}rkhunter --check --sk --rwo${PLAIN}"
    echo -e "  扫描日志: /var/log/rkhunter.log"
}

# ---------------------------------------------------------------
# [16] 自动安全更新
# ---------------------------------------------------------------
function task_auto_updates() {
    header "[16] 配置自动安全更新"

    info "正在安装 unattended-upgrades..."
    apt install -y unattended-upgrades apt-listchanges

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
    success "自动安全更新已启用 (仅更新安全补丁，不自动重启)"
}

# ---------------------------------------------------------------
# [17] MOTD 系统信息美化
# ---------------------------------------------------------------
function task_motd() {
    header "[17] MOTD 系统信息美化"

    echo -e "功能说明：SSH 登录后自动显示精美的系统状态信息"
    echo -e "展示内容：系统信息、CPU/内存/磁盘、负载、网络、安全状态"
    echo ""

    info "正在禁用系统默认 MOTD 组件..."
    local MOTD_DIR="/etc/update-motd.d"
    if [[ -d "$MOTD_DIR" ]]; then
        for f in "$MOTD_DIR"/*; do
            [[ -f "$f" ]] && chmod -x "$f" 2>/dev/null && \
                info "已禁用: $(basename $f)"
        done
    fi

    if [[ -f /etc/motd ]]; then
        cp /etc/motd /etc/motd.bak
        > /etc/motd
    fi

    sed -i 's/^session\s*optional\s*pam_motd.so.*/#&/' /etc/pam.d/sshd 2>/dev/null || true
    sed -i 's/^session\s*optional\s*pam_motd.so.*/#&/' /etc/pam.d/login 2>/dev/null || true

    info "正在安装依赖工具 (figlet)..."
    apt install -y figlet bc 2>/dev/null || true

    local MOTD_SCRIPT="$MOTD_DIR/00-custom-info"

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
    local bar=""
    local color

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

if [[ "$FAIL_COUNT" -gt 100 ]]; then
    FAIL_COLOR=$R
elif [[ "$FAIL_COUNT" -gt 20 ]]; then
    FAIL_COLOR=$Y
else
    FAIL_COLOR=$G
fi
echo -e "  ${C}SSH失败次数${N}    ${FAIL_COLOR}${FAIL_COUNT} 次${N}  (来自 /var/log/auth.log)"

if command -v fail2ban-client &>/dev/null && systemctl is-active --quiet fail2ban 2>/dev/null; then
    echo -e "  ${C}Fail2Ban封禁${N}   ${Y}${BANNED_IP_COUNT} 个IP${N}  (当前已封禁)"
else
    echo -e "  ${C}Fail2Ban    ${N}   ${Y}未运行${N}"
fi

if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1 | awk '{print $2}')
    if [[ "$UFW_STATUS" == "active" ]]; then
        echo -e "  ${C}防火墙UFW   ${N}   ${G}已启用${N}"
    else
        echo -e "  ${C}防火墙UFW   ${N}   ${Y}未启用${N}"
    fi
fi

if [[ -n "$LAST_LOGIN" ]]; then
    echo -e "  ${C}上次登录    ${N}   ${LAST_LOGIN}"
fi

echo -e ""
echo -e "${B}  ══════════════════════════════════════════════════════${N}"
echo -e "  ${Y}  $(date '+%Y-%m-%d %H:%M:%S %Z')${N}"
echo -e "${B}  ══════════════════════════════════════════════════════${N}"
echo -e ""
MOTD_EOF

    chmod +x "$MOTD_SCRIPT"

    if grep -qE "^#?PrintMotd" /etc/ssh/sshd_config; then
        sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
    else
        echo "PrintMotd yes" >> /etc/ssh/sshd_config
    fi

    if grep -qE "^#?PrintLastLog" /etc/ssh/sshd_config; then
        sed -i 's/^#\?PrintLastLog.*/PrintLastLog no/' /etc/ssh/sshd_config
    else
        echo "PrintLastLog no" >> /etc/ssh/sshd_config
    fi

    if sshd -t 2>/dev/null; then
        systemctl restart sshd
    fi

    echo ""
    read -rp "是否立即预览 MOTD 效果? (y/n): " preview
    if [[ "$preview" == "y" ]]; then
        echo ""
        bash "$MOTD_SCRIPT"
    fi

    success "MOTD 美化配置完成"
    echo -e "  MOTD脚本路径: ${CYAN}$MOTD_SCRIPT${PLAIN}"
    echo -e "  修改MOTD:     ${YELLOW}nano $MOTD_SCRIPT${PLAIN}"
    echo -e "  立即预览:     ${YELLOW}bash $MOTD_SCRIPT${PLAIN}"
    echo -e "  恢复默认:     ${YELLOW}chmod +x /etc/update-motd.d/*${PLAIN}"
}

# ---------------------------------------------------------------
# [18] ZSH + 插件环境
# ---------------------------------------------------------------
function task_zsh() {
    header "[18] ZSH + 插件环境"

    echo -e "将安装以下内容："
    echo -e "  • ${GREEN}Zsh${PLAIN}                    现代化 Shell"
    echo -e "  • ${GREEN}Oh-My-Zsh${PLAIN}              Zsh 配置管理框架"
    echo -e "  • ${GREEN}zsh-autosuggestions${PLAIN}    命令自动补全建议"
    echo -e "  • ${GREEN}zsh-syntax-highlighting${PLAIN} 命令语法高亮"
    echo -e "  • ${GREEN}zsh-completions${PLAIN}        增强 Tab 补全"
    echo -e "  • ${GREEN}自定义 Alias${PLAIN}           常用命令别名"
    echo ""

    if ! command -v zsh &>/dev/null; then
        info "正在安装 Zsh..."
        apt install -y zsh
        success "Zsh 安装完成: $(zsh --version)"
    else
        success "Zsh 已安装: $(zsh --version)"
    fi

    if ! command -v git &>/dev/null; then
        info "正在安装 git..."
        apt install -y git
    fi

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
            if ! id "$target_user" &>/dev/null; then
                error "用户 '$target_user' 不存在"
                return 1
            fi
            TARGET_USERS=("$target_user")
            ;;
        3)
            read -rp "请输入普通用户名: " target_user
            if ! id "$target_user" &>/dev/null; then
                error "用户 '$target_user' 不存在"
                return 1
            fi
            TARGET_USERS=("root" "$target_user")
            ;;
        *)
            warn "无效选择，默认仅安装到 root"
            TARGET_USERS=("root")
            ;;
    esac

    for INSTALL_USER in "${TARGET_USERS[@]}"; do

        if [[ "$INSTALL_USER" == "root" ]]; then
            USER_HOME="/root"
        else
            USER_HOME=$(getent passwd "$INSTALL_USER" | cut -d: -f6)
        fi

        print_line
        info "正在为用户 ${BOLD}${INSTALL_USER}${PLAIN} 安装 ZSH 环境..."
        info "家目录: $USER_HOME"

        local OMZ_DIR="$USER_HOME/.oh-my-zsh"

        if [[ -d "$OMZ_DIR" ]]; then
            warn "Oh-My-Zsh 已存在于 $OMZ_DIR，跳过安装"
        else
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

            if [[ -d "$OMZ_DIR" ]]; then
                success "Oh-My-Zsh 安装完成"
            else
                error "Oh-My-Zsh 安装失败，请检查网络"
                continue
            fi
        fi

        local ZSH_CUSTOM="$OMZ_DIR/custom"

        local AUTOSUGGEST_DIR="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        if [[ ! -d "$AUTOSUGGEST_DIR" ]]; then
            info "正在安装 zsh-autosuggestions..."
            git clone --depth=1 \
                https://github.com/zsh-users/zsh-autosuggestions \
                "$AUTOSUGGEST_DIR" 2>/dev/null || \
            git clone --depth=1 \
                https://gitee.com/mirrors/zsh-autosuggestions \
                "$AUTOSUGGEST_DIR" 2>/dev/null
            success "zsh-autosuggestions 安装完成"
        else
            warn "zsh-autosuggestions 已存在，跳过"
        fi

        local SYNTAX_DIR="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        if [[ ! -d "$SYNTAX_DIR" ]]; then
            info "正在安装 zsh-syntax-highlighting..."
            git clone --depth=1 \
                https://github.com/zsh-users/zsh-syntax-highlighting \
                "$SYNTAX_DIR" 2>/dev/null || \
            git clone --depth=1 \
                https://gitee.com/mirrors/zsh-syntax-highlighting \
                "$SYNTAX_DIR" 2>/dev/null
            success "zsh-syntax-highlighting 安装完成"
        else
            warn "zsh-syntax-highlighting 已存在，跳过"
        fi

        local COMPLETIONS_DIR="$ZSH_CUSTOM/plugins/zsh-completions"
        if [[ ! -d "$COMPLETIONS_DIR" ]]; then
            info "正在安装 zsh-completions..."
            git clone --depth=1 \
                https://github.com/zsh-users/zsh-completions \
                "$COMPLETIONS_DIR" 2>/dev/null || true
            success "zsh-completions 安装完成"
        else
            warn "zsh-completions 已存在，跳过"
        fi

        local ZSHRC="$USER_HOME/.zshrc"

        if [[ -f "$ZSHRC" ]]; then
            cp "$ZSHRC" "${ZSHRC}.bak.$(date +%F_%H%M%S)"
            info "已备份原 .zshrc"
        fi

        info "正在写入 .zshrc 配置..."

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

# ==============================================================
#  环境变量
# ==============================================================
export LANG=en_US.UTF-8
export EDITOR='vim'
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoredups:erasedups

# ==============================================================
#  自动补全颜色
# ==============================================================
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ==============================================================
#  实用 Alias
# ==============================================================

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
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
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
alias cpu='top -bn1 | grep "Cpu(s)"'
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
alias dkstop='docker stop'
alias dkrm='docker rm'
alias dkrmi='docker rmi'
alias dkpull='docker pull'
alias dkcp='docker-compose'
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
alias gb='git branch'
alias gco='git checkout'

# --- 安全相关 ---
alias f2b='fail2ban-client status'
alias f2bssh='fail2ban-client status sshd'
alias ufws='ufw status verbose'
alias lastlog='last -n 20'
alias whofail='grep "Failed password" /var/log/auth.log | tail -20'

# ==============================================================
#  实用函数
# ==============================================================

extract() {
    if [[ -f "\$1" ]]; then
        case "\$1" in
            *.tar.bz2)  tar xjf "\$1"     ;;
            *.tar.gz)   tar xzf "\$1"     ;;
            *.tar.xz)   tar xJf "\$1"     ;;
            *.tar.zst)  tar xaf "\$1"     ;;
            *.bz2)      bunzip2 "\$1"     ;;
            *.rar)      unrar x "\$1"     ;;
            *.gz)       gunzip "\$1"      ;;
            *.tar)      tar xf "\$1"      ;;
            *.tbz2)     tar xjf "\$1"     ;;
            *.tgz)      tar xzf "\$1"     ;;
            *.zip)      unzip "\$1"       ;;
            *.Z)        uncompress "\$1"  ;;
            *.7z)       7z x "\$1"        ;;
            *)          echo "'$1' 无法识别的压缩格式" ;;
        esac
    else
        echo "'$1' 不是一个有效文件"
    fi
}

port()  { ss -tulnp | grep ":\${1}" ; }
mkcd()  { mkdir -p "\$1" && cd "\$1" ; }
hist()  { history | grep "\$1" ; }
ipinfo(){ curl -s "https://ipinfo.io/\${1:-}" | python3 -m json.tool 2>/dev/null || curl -s "https://ipinfo.io/\${1:-}" ; }
bak()   { cp "\$1" "\${1}.bak.\$(date +%Y%m%d%H%M%S)" ; }

# ==============================================================
#  补全与历史优化
# ==============================================================
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select

setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS

stty -ixon 2>/dev/null || true

autoload -U compinit && compinit
ZSHRC_EOF

        if [[ "$INSTALL_USER" != "root" ]]; then
            chown "$INSTALL_USER:$INSTALL_USER" "$ZSHRC"
            chown -R "$INSTALL_USER:$INSTALL_USER" "$OMZ_DIR" 2>/dev/null || true
        fi

        success "用户 $INSTALL_USER 的 .zshrc 配置完成"

        local ZSH_PATH
        ZSH_PATH=$(command -v zsh)

        if ! grep -qx "$ZSH_PATH" /etc/shells; then
            echo "$ZSH_PATH" >> /etc/shells
            info "已将 $ZSH_PATH 添加到 /etc/shells"
        fi

        echo ""
        read -rp "是否将 $INSTALL_USER 的默认 Shell 切换为 Zsh? (y/n): " change_shell
        if [[ "$change_shell" == "y" ]]; then
            if chsh -s "$ZSH_PATH" "$INSTALL_USER"; then
                success "用户 $INSTALL_USER 的默认 Shell 已切换为 Zsh"
                warn "需要重新登录后生效"
            else
                error "切换 Shell 失败，请手动执行: chsh -s $ZSH_PATH $INSTALL_USER"
            fi
        else
            info "保持原有 Shell，可手动切换: chsh -s $ZSH_PATH $INSTALL_USER"
        fi

        info "也可在当前会话临时使用: ${CYAN}exec zsh${PLAIN}"
    done

    echo ""
    success "ZSH 环境安装完成，摘要："
    echo -e "  Zsh版本:   $(zsh --version)"
    echo -e "  主题:      ${CYAN}ys${PLAIN} (可在 .zshrc 中修改 ZSH_THEME)"
    echo -e "  已装插件:  ${CYAN}autosuggestions / syntax-highlighting / completions${PLAIN}"
    echo -e ""
    echo -e "  ${YELLOW}快捷键提示:${PLAIN}"
    echo -e "   ${CYAN}→ 方向键${PLAIN}   接受自动补全建议"
    echo -e "   ${CYAN}Tab${PLAIN}        触发命令补全菜单"
    echo -e "   ${CYAN}Ctrl+R${PLAIN}     历史命令搜索"
    echo -e "   ${CYAN}ESC ESC${PLAIN}    在命令前加 sudo (sudo 插件)"
    echo -e ""
    echo -e "  立即生效:  ${YELLOW}exec zsh${PLAIN}"
    echo -e "  修改配置:  ${YELLOW}nano ~/.zshrc && source ~/.zshrc${PLAIN}"
}

# ---------------------------------------------------------------
# [0] 一键全流程
# ---------------------------------------------------------------
function task_all() {
    header "一键全流程初始化"
    warn "将依次执行以下任务："
    echo -e "  软件源 → 基础工具 → 主机名 → 时区 → BBR"
    echo -e "  → Swap → 内核优化 → 创建用户 → SSH密钥"
    echo -e "  → SSH端口 → 防火墙 → rkhunter → 自动更新"
    echo -e "  → MOTD美化 → ZSH环境"
    echo ""
    read -rp "确认开始? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    task_source
    task_essentials
    task_hostname
    task_timezone
    task_bbr
    task_swap
    task_sysctl
    task_create_user
    task_ssh
    task_ssh_port
    task_firewall
    task_rkhunter
    task_auto_updates
    task_motd
    task_zsh

    header "🎉 基础初始化完成"
    success "所有基础任务已执行完毕！"
    print_line

    read -rp "是否配置 SSH 登录 Telegram 通知? (y/n): " notify
    [[ "$notify" == "y" ]] && task_ssh_notify

    read -rp "是否安装 Docker? (y/n): " install_docker
    [[ "$install_docker" == "y" ]] && task_docker

    read -rp "是否安装 1Panel 面板? (y/n): " install_panel
    [[ "$install_panel" == "y" ]] && task_1panel

    print_line
    echo -e "${YELLOW}  建议重启服务器以确保所有内核参数完全生效${PLAIN}"
    read -rp "是否立即重启? (y/n): " reboot_now
    [[ "$reboot_now" == "y" ]] && reboot
}

# ==============================================================
#  主菜单界面
# ==============================================================
function show_menu() {
    while true; do
        clear
        echo -e "${BLUE}=============================================================${PLAIN}"
        echo -e "${BOLD}          🚀  Linux 服务器初始化助手  (Pro V7)           ${PLAIN}"
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
        echo -e "   ${GREEN}17.${PLAIN}  MOTD 系统信息美化 ${CYAN}(登录后显示系统状态)${PLAIN}"
        echo -e "   ${GREEN}18.${PLAIN}  ZSH + 插件环境 ${CYAN}(Oh-My-Zsh / 补全 / 高亮)${PLAIN}"
        echo -e ""
        echo -e "${BLUE}-------------------------------------------------------------${PLAIN}"
        echo -e "   ${GREEN}0.${PLAIN}   ${BOLD}一键执行全部基础配置${PLAIN}"
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
            q|Q)
                success "已退出脚本"
                exit 0
                ;;
            *)   error "无效输入: '$choice'，请重新选择" ;;
        esac

        echo ""
        read -rp " 按回车键返回主菜单..."
    done
}

# --- 启动 ---
show_menu
