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

header "[12] 修改 SSH 端口"

CURRENT_PORT=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}' | head -1)
CURRENT_PORT=${CURRENT_PORT:-22}
info "当前 SSH 端口: ${GREEN}${CURRENT_PORT}${PLAIN}"

echo ""
warn "修改 SSH 端口可过滤绝大多数自动化扫描攻击"
warn "建议使用 1024-65535 之间的端口，避免使用知名服务端口"
echo ""

while true; do
    read -rp "请输入新的 SSH 端口号 (1024-65535): " NEW_PORT

    if [[ ! "$NEW_PORT" =~ ^[0-9]+$ ]]; then
        error "端口必须为纯数字，请重新输入"; continue
    fi
    if [[ "$NEW_PORT" -lt 1024 || "$NEW_PORT" -gt 65535 ]]; then
        error "端口范围无效，请输入 1024-65535 之间的值"; continue
    fi
    if ss -tlnp | grep -q ":${NEW_PORT} " && [[ "$NEW_PORT" != "$CURRENT_PORT" ]]; then
        warn "端口 $NEW_PORT 已被以下进程占用:"
        ss -tlnp | grep ":${NEW_PORT} "
        read -rp "是否仍要使用此端口? (y/n): " force_use
        [[ "$force_use" != "y" ]] && continue
    fi
    if [[ "$NEW_PORT" == "$CURRENT_PORT" ]]; then
        warn "新端口与当前端口相同 ($CURRENT_PORT)，无需修改"; exit 0
    fi
    break
done

echo ""
warn "将把 SSH 端口从 ${CURRENT_PORT} 修改为 ${NEW_PORT}"
read -rp "确认执行? (y/n): " confirm
[[ "$confirm" != "y" ]] && warn "已取消" && exit 0

BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%F_%H%M%S)"
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
    error "已回滚至备份配置"; exit 1
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
