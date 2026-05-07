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

header "[10] 创建普通用户"

echo -e "当前系统用户列表 (UID 1000+):"
awk -F: '$3 >= 1000 && $3 < 65534 {print "  "$1" (uid="$3")"}' /etc/passwd
echo ""

read -rp "请输入新用户名: " new_user

if [[ -z "$new_user" ]]; then
    error "用户名不能为空"; exit 1
fi

if [[ ! "$new_user" =~ ^[a-z][a-z0-9_-]{0,30}$ ]]; then
    error "用户名格式无效，只允许小写字母开头，包含小写字母/数字/下划线/连字符，长度不超过31位"
    exit 1
fi

if id "$new_user" &>/dev/null; then
    warn "用户 '$new_user' 已存在"
    read -rp "是否继续为该用户配置 sudo 和 SSH 密钥? (y/n): " cont
    [[ "$cont" != "y" ]] && exit 0
else
    useradd -m -s /bin/bash "$new_user"
    success "用户 '$new_user' 已创建，家目录: /home/$new_user"

    info "请为用户 '$new_user' 设置登录密码："
    passwd_ok=false
    retry=0
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
        exit 1
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
