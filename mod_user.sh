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

# ---------------------------------------------------------------
# 显示当前 root 登录状态
# ---------------------------------------------------------------
function show_root_login_status() {
    local permit_root
    permit_root=$(grep -E "^#?PermitRootLogin" /etc/ssh/sshd_config | tail -1 | awk '{print $2}')
    [[ -z "$permit_root" ]] && permit_root="prohibit-password (默认)"
    echo -e "当前 SSH 配置中 root 登录状态：${CYAN}${permit_root}${PLAIN}"
    echo -e "  • ${GREEN}yes${PLAIN}               - 允许密码和密钥登录"
    echo -e "  • ${GREEN}prohibit-password${PLAIN} - 仅允许密钥登录 (推荐)"
    echo -e "  • ${GREEN}no${PLAIN}                - 禁止 root 登录"
}

# ---------------------------------------------------------------
# 修改 root 登录方式
# ---------------------------------------------------------------
function manage_root_login() {
    echo ""
    show_root_login_status
    echo -e "\n请选择要设置的状态："
    echo -e "  ${GREEN}1.${PLAIN} 仅允许密钥登录 (prohibit-password) 【推荐】"
    echo -e "  ${GREEN}2.${PLAIN} 允许密码+密钥登录 (yes) 【不推荐】"
    echo -e "  ${GREEN}3.${PLAIN} 完全禁止 root 登录 (no)"
    echo -e "  ${GREEN}0.${PLAIN} 返回"
    read -rp "请输入选项 [0-3]: " root_choice

    local new_value=""
    case "$root_choice" in
        1) new_value="prohibit-password" ;;
        2) new_value="yes" ;;
        3) new_value="no" ;;
        0) return ;;
        *) warn "无效选择"; return ;;
    esac

    local backup_file="/etc/ssh/sshd_config.bak.root.$(date +%Y%m%d-%H%M%S)"
    cp /etc/ssh/sshd_config "$backup_file"
    info "已备份 SSH 配置至: $backup_file"

    if grep -qE "^#?PermitRootLogin" /etc/ssh/sshd_config; then
        sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin ${new_value}/" /etc/ssh/sshd_config
    else
        echo "PermitRootLogin ${new_value}" >> /etc/ssh/sshd_config
    fi

    if sshd -t; then
        systemctl restart sshd
        success "root 登录方式已更改为: ${new_value}"
        [[ "$new_value" == "prohibit-password" ]] && warn "现在只能使用 SSH 密钥登录 root，请确保您的密钥已配置！"
        [[ "$new_value" == "yes" ]] && warn "已允许 root 密码登录，请务必设置强密码"
        [[ "$new_value" == "no" ]] && warn "root 登录已完全禁止，请确保有其他 sudo 用户可用"
    else
        error "SSH 配置语法错误，已回滚"
        cp "$backup_file" /etc/ssh/sshd_config
        systemctl restart sshd
    fi
    echo ""
    read -rp "按回车键继续..."
}

# ---------------------------------------------------------------
# 创建新用户
# ---------------------------------------------------------------
function create_new_user() {
    echo -e "当前系统用户列表 (UID 1000+):"
    awk -F: '$3 >= 1000 && $3 < 65534 {print "  "$1" (uid="$3")"}' /etc/passwd
    echo ""

    read -rp "请输入新用户名: " new_user
    if [[ -z "$new_user" ]]; then
        error "用户名不能为空"; return 1
    fi
    if [[ ! "$new_user" =~ ^[a-z][a-z0-9_-]{0,30}$ ]]; then
        error "用户名格式无效，只允许小写字母开头，包含小写字母/数字/下划线/连字符，长度 ≤ 31"
        return 1
    fi

    if id "$new_user" &>/dev/null; then
        warn "用户 '$new_user' 已存在"
        read -rp "是否继续为该用户配置 sudo 和 SSH 密钥? (y/n): " cont
        [[ "$cont" != "y" ]] && return 0
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
        info "已添加 sudo 组权限"
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
            success "公钥已添加"
        fi
    fi

    echo ""
    success "用户配置完成"
    echo -e "  用户名:   ${GREEN}$new_user${PLAIN}"
    echo -e "  家目录:   /home/$new_user"
    echo -e "  sudo:     ${GREEN}已启用${PLAIN}"
    echo -e "  SSH公钥:  $([ -s "/home/$new_user/.ssh/authorized_keys" ] && echo "${GREEN}已配置${PLAIN}" || echo "${YELLOW}未配置${PLAIN}")"

    echo ""
    warn "是否要立即禁止 root 直接 SSH 登录？(建议先确认新用户可正常登录)"
    read -rp "禁止 root 登录? (y/n): " disable_root_ssh
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
}

# ---------------------------------------------------------------
# 删除用户
# ---------------------------------------------------------------
function delete_user() {
    echo -e "现有普通用户列表 (UID 1000+, 不含系统用户):"
    local user_list=()
    while IFS=: read -r user uid rest; do
        if [[ $uid -ge 1000 && $uid -lt 65534 ]]; then
            user_list+=("$user")
            echo -e "  ${GREEN}$user${PLAIN} (uid=$uid)"
        fi
    done < /etc/passwd

    if [[ ${#user_list[@]} -eq 0 ]]; then
        warn "没有找到普通用户"
        return
    fi

    echo ""
    read -rp "请输入要删除的用户名: " del_user
    if [[ -z "$del_user" ]]; then
        error "用户名不能为空"; return 1
    fi

    # 安全检查1: 禁止删除 root
    if [[ "$del_user" == "root" ]]; then
        error "禁止删除 root 用户！"; return 1
    fi

    # 安全检查2: 禁止删除当前登录用户
    local current_user=$(whoami)
    if [[ "$del_user" == "$current_user" ]]; then
        error "不能删除当前登录的用户 $current_user，请切换其他用户后操作"; return 1
    fi

    # 验证用户是否存在
    if ! id "$del_user" &>/dev/null; then
        error "用户 $del_user 不存在"; return 1
    fi

    # 检查用户是否正在运行进程（可选警告）
    local user_pids=$(pgrep -u "$del_user" 2>/dev/null | head -1)
    if [[ -n "$user_pids" ]]; then
        warn "用户 $del_user 当前有正在运行的进程"
        read -rp "是否强制终止其所有进程并删除? (y/n): " force_kill
        if [[ "$force_kill" == "y" ]]; then
            pkill -u "$del_user" 2>/dev/null
            info "已终止用户 $del_user 的所有进程"
        else
            error "取消删除操作"; return 1
        fi
    fi

    # 选择是否删除家目录和 mail spool
    echo ""
    read -rp "是否同时删除用户的家目录 (/home/$del_user) 和邮箱 (/var/mail/$del_user)? (y/n): " del_home
    local remove_opt=""
    if [[ "$del_home" == "y" ]]; then
        remove_opt="-r"
        info "将删除家目录和邮箱"
    else
        warn "将保留家目录和邮箱（仅删除用户账户）"
    fi

    # 最终确认
    echo ""
    warn "即将删除用户 ${del_user}"
    read -rp "确认执行删除? (请输入 yes 确认): " confirm
    if [[ "$confirm" != "yes" ]]; then
        info "已取消删除操作"; return 0
    fi

    # 执行删除
    if userdel $remove_opt "$del_user" 2>/dev/null; then
        success "用户 $del_user 已删除"
        if [[ "$del_home" == "y" ]]; then
            success "已删除 /home/$del_user 和 /var/mail/$del_user"
        else
            info "家目录 /home/$del_user 和邮箱文件已保留"
        fi
    else
        error "删除失败，请检查用户是否存在或进程是否清理干净"
        return 1
    fi
}

# ---------------------------------------------------------------
# 主菜单（循环）
# ---------------------------------------------------------------
while true; do
    clear
    print_line
    echo -e "${PURPLE}${BOLD}  用户管理 / Root 登录控制${PLAIN}"
    print_line
    show_root_login_status
    echo -e "\n  ${GREEN}1.${PLAIN} 创建新用户（并配置 sudo / SSH 密钥）"
    echo -e "  ${GREEN}2.${PLAIN} 删除已有用户"
    echo -e "  ${GREEN}3.${PLAIN} 修改 root 登录方式（密钥/密码/禁止）"
    echo -e "  ${GREEN}0.${PLAIN} 返回主菜单"
    read -rp "请选择 [0-3]: " action

    case "$action" in
        1) create_new_user ;;
        2) delete_user ;;
        3) manage_root_login ;;
        0) break ;;
        *) warn "无效输入" ;;
    esac
    echo ""
    read -rp "按回车键继续..."
done
