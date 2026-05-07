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

header "[17] MOTD 系统信息美化"
echo -e "功能说明：SSH 登录后自动显示精美的系统状态信息"
echo -e "展示内容：系统信息、CPU/内存/磁盘、负载、网络、安全状态"
echo ""

info "正在禁用系统默认 MOTD 组件（仅禁用不必要的动态脚本，保留 PAM 调用）..."

MOTD_DIR="/etc/update-motd.d"
if [[ -d "$MOTD_DIR" ]]; then
    # 备份原有脚本（可选）
    if [[ ! -d "$MOTD_DIR.bak" ]]; then
        cp -r "$MOTD_DIR" "$MOTD_DIR.bak"
        info "已备份原始 MOTD 脚本到 $MOTD_DIR.bak"
    fi
    # 删除或禁用所有原有脚本（避免重复输出）
    rm -f "$MOTD_DIR"/* 2>/dev/null
    # 或者 chmod -x 全部原有脚本，但确保目录为空
    # 确保目录存在
    mkdir -p "$MOTD_DIR"
fi

# 确保 PAM 中 pam_motd.so 没有被注释
# 检查 /etc/pam.d/sshd 和 /etc/pam.d/login
for pamfile in /etc/pam.d/sshd /etc/pam.d/login; do
    if [[ -f "$pamfile" ]]; then
        # 取消注释包含 pam_motd.so 的行
        sed -i 's/^#\s*\(session\s\+optional\s\+pam_motd.so\)/\1/' "$pamfile"
        # 确保存在该行，如果没有则添加
        if ! grep -q "pam_motd.so" "$pamfile"; then
            echo "session optional pam_motd.so motd=/run/motd.dynamic" >> "$pamfile"
        fi
    fi
done

# 清空静态 /etc/motd (防止旧的静态内容)
> /etc/motd

info "正在安装依赖工具 (figlet)..."
apt install -y figlet bc 2>/dev/null || true

# 创建自定义 MOTD 脚本
CUSTOM_SCRIPT="$MOTD_DIR/00-custom-info"

cat > "$CUSTOM_SCRIPT" << 'MOTD_EOF'
#!/bin/bash
# ==============================================================
#  Custom MOTD - Server Info Display
# ==============================================================

R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'; BOLD='\033[1m'

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
    local percent=$1 total=20
    local filled=$((percent * total / 100))
    local empty=$((total - filled))
    local bar="" color
    if   [[ $percent -lt 50 ]]; then color=$G
    elif [[ $percent -lt 80 ]]; then color=$Y
    else                              color=$R; fi
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty;  i++)); do bar+="░"; done
    echo -e "${color}${bar}${N} ${color}${percent}%${N}"
}

function pct_color() {
    local pct=$1
    if   [[ $pct -lt 50 ]]; then echo -e "${G}${pct}%${N}"
    elif [[ $pct -lt 80 ]]; then echo -e "${Y}${pct}%${N}"
    else                          echo -e "${R}${pct}%${N}"; fi
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
if [[ "$FAIL_COUNT" -gt 100 ]]; then FAIL_COLOR=$R
elif [[ "$FAIL_COUNT" -gt 20 ]]; then FAIL_COLOR=$Y
else FAIL_COLOR=$G; fi
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
[[ -n "$LAST_LOGIN" ]] && echo -e "  ${C}上次登录    ${N}   ${LAST_LOGIN}"
echo -e ""
echo -e "${B}  ══════════════════════════════════════════════════════${N}"
echo -e "  ${Y}  $(date '+%Y-%m-%d %H:%M:%S %Z')${N}"
echo -e "${B}  ══════════════════════════════════════════════════════${N}"
echo -e ""
MOTD_EOF

chmod +x "$CUSTOM_SCRIPT"

# 确保 sshd 配置中的 PrintMotd yes
if grep -qE "^#?PrintMotd" /etc/ssh/sshd_config; then
    sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
else
    echo "PrintMotd yes" >> /etc/ssh/sshd_config
fi

# 确保 PrintLastLog 为 no（可选，避免重复）
if grep -qE "^#?PrintLastLog" /etc/ssh/sshd_config; then
    sed -i 's/^#\?PrintLastLog.*/PrintLastLog no/' /etc/ssh/sshd_config
else
    echo "PrintLastLog no" >> /etc/ssh/sshd_config
fi

# 重新加载 sshd
if sshd -t 2>/dev/null; then
    systemctl restart sshd
    success "SSH 服务已重启"
else
    error "SSH 配置语法错误，请检查"
fi

# 立即预览
echo ""
read -rp "是否立即预览 MOTD 效果? (y/n): " preview
if [[ "$preview" == "y" ]]; then
    echo ""
    bash "$CUSTOM_SCRIPT"
fi

success "MOTD 美化配置完成"
echo -e "  MOTD脚本路径: ${CYAN}$CUSTOM_SCRIPT${PLAIN}"
echo -e "  测试显示:     ${YELLOW}run-parts /etc/update-motd.d/ 2>/dev/null${PLAIN}"
echo -e "  立即预览:     ${YELLOW}bash $CUSTOM_SCRIPT${PLAIN}"
echo -e "  恢复默认:     ${YELLOW}rm -rf /etc/update-motd.d/* && cp -r /etc/update-motd.d.bak/* /etc/update-motd.d/ && systemctl restart sshd${PLAIN}"
