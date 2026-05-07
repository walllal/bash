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

function sshd_set() {
    local key="$1" val="$2"
    if grep -qE "^#?${key}" /etc/ssh/sshd_config; then
        sed -i "s|^#\?${key}.*|${key} ${val}|g" /etc/ssh/sshd_config
    else
        echo "${key} ${val}" >> /etc/ssh/sshd_config
    fi
}

header "[11] 配置 SSH 密钥登录"

echo -e "此操作将："
echo -e "  1. 导入您的 SSH 公钥 (写入 root)"
echo -e "  2. ${RED}禁用密码登录${PLAIN}"
echo -e "  3. 限制最大认证尝试次数为 3 次"
echo ""
warn "⚠️  执行前请确保您已有对应私钥，否则将无法登录！"
read -rp "确认执行? (y/n): " choice
[[ "$choice" != "y" ]] && warn "已取消 SSH 配置" && exit 0

echo -e "${YELLOW}请粘贴您的 SSH 公钥 (ssh-ed25519 / ssh-rsa / ecdsa-sha2-nistp256 ...):${PLAIN}"
read -r pubkey

if [[ -z "$pubkey" ]]; then
    error "公钥为空，已取消操作"; exit 1
fi

if [[ ! "$pubkey" =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com) ]]; then
    error "公钥格式无效！请确认以 ssh-ed25519 / ssh-rsa 等类型开头"; exit 1
fi

mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys

if grep -qF "$pubkey" ~/.ssh/authorized_keys 2>/dev/null; then
    warn "该公钥已存在，跳过写入"
else
    echo "$pubkey" >> ~/.ssh/authorized_keys
    success "公钥已写入 ~/.ssh/authorized_keys"
fi

BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%F_%H%M%S)"
cp /etc/ssh/sshd_config "$BACKUP_FILE"
info "原配置已备份至: $BACKUP_FILE"

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
    exit 1
fi

systemctl restart sshd
success "SSH 密钥登录配置完成，密码登录已禁用"
echo ""
warn "════════════════════════════════════════════════"
warn "  ⚠️  请立即新开终端测试 SSH 连接！"
warn "  确认可以正常登录后，再关闭当前终端！"
warn "════════════════════════════════════════════════"
