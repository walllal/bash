#!/bin/bash

# ==============================================================
#  Linux Server Initialization Script (Ultimate Edition)
#  Author: Customized based on user request
#  System: Debian / Ubuntu
# ==============================================================

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
function info() { echo -e "${BLUE}[INFO]${PLAIN} $1"; }
function success() { echo -e "${GREEN}[OK]${PLAIN} $1"; }
function warn() { echo -e "${YELLOW}[WARN]${PLAIN} $1"; }
function error() { echo -e "${RED}[ERROR]${PLAIN} $1"; }
function header() { 
    echo -e ""
    print_line
    echo -e "${PURPLE}# $1${PLAIN}"
    print_line
}

# --- 权限检查 ---
[[ $EUID -ne 0 ]] && error "必须使用 root 用户运行此脚本！" && exit 1

# --- 环境预检 ---
if ! command -v curl &> /dev/null; then
    warn "未检测到 curl，正在安装..."
    apt-get update -qq && apt-get install -y -qq curl
fi

# ==============================================================
#  核心功能模块
# ==============================================================

# [1] 配置软件源
function task_source() {
    header "配置系统软件源"
    echo -e "请选择服务器网络环境："
    echo -e "  ${GREEN}1.${PLAIN} 国内服务器 (清华/中科大/阿里等镜像)"
    echo -e "  ${GREEN}2.${PLAIN} 海外服务器 (官方源/全球CDN)"
    read -p "请输入选择 [1/2]: " choice

    case "$choice" in
        1) bash <(curl -sSL https://linuxmirrors.cn/main.sh) ;;
        2) bash <(curl -sSL https://linuxmirrors.cn/main.sh) --abroad ;;
        *) warn "跳过源更新..." ;;
    esac
}

# [2] 基础组件安装
function task_essentials() {
    header "安装基础软件包"
    info "正在更新软件包列表..."
    apt update -y
    
    info "正在安装常用工具 (curl, git, vim, htop, fail2ban...)"
    PACKAGES="build-essential curl wget git vim nano unzip zip htop net-tools sudo fail2ban ufw"
    apt install -y $PACKAGES
    
    # 配置 Fail2Ban
    if [ -f /etc/fail2ban/jail.conf ] && [ ! -f /etc/fail2ban/jail.local ]; then
        cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
        systemctl enable fail2ban &>/dev/null
        systemctl start fail2ban &>/dev/null
        success "Fail2Ban 已启用"
    fi
    success "基础软件安装完成"
}

# [3] 安装 Docker
function task_docker() {
    header "安装 Docker 环境"
    if command -v docker &> /dev/null; then
        warn "Docker 已安装，跳过"
    else
        bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
    fi
}

# [4] 安装 1Panel
function task_1panel() {
    header "安装 1Panel 面板"
    
    if ! command -v docker &> /dev/null; then
        warn "前置依赖 Docker 未找到，即将先安装 Docker..."
        task_docker
    fi
    
    info "启动 1Panel 官方安装脚本..."
    bash -c "$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)"
}

# [5] 配置 SSH
function task_ssh() {
    header "配置 SSH 安全登录"
    echo -e "此操作将：\n 1. 导入您的 SSH 公钥\n 2. ${RED}禁用密码登录${PLAIN} (提高安全性)"
    read -p "确认执行? (y/n): " choice
    [[ "$choice" != "y" ]] && return

    echo -e "${YELLOW}请粘贴您的 SSH 公钥 (ssh-ed25519/ssh-rsa ...):${PLAIN}"
    read pubkey
    
    if [[ -z "$pubkey" ]]; then
        error "公钥为空，已取消操作"
        return
    fi

    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    
    if ! grep -q "$pubkey" ~/.ssh/authorized_keys 2>/dev/null; then
        echo "$pubkey" >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        success "公钥已导入"
    else
        warn "该公钥已存在"
    fi

    # 备份并修改配置
    cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%F_%T)"
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
    
    systemctl restart sshd
    success "SSH 配置已更新"
    warn "请务必新开一个终端窗口测试连接，确保无误后再关闭当前窗口！"
}

# [6] 配置防火墙
function task_firewall() {
    header "配置防火墙 (UFW)"
    warn "如果后续安装 1Panel，建议跳过此步，直接在面板中管理。"
    read -p "是否初始化 UFW (仅开放 22,80,443)? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow 22/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        echo "y" | ufw enable
        success "UFW 防火墙已启用"
    else
        info "已跳过"
    fi
}

# [7] 系统设置 (时区 & BBR)
function task_sys_config() {
    header "系统基础设置"
    
    # 时区
    timedatectl set-timezone Asia/Shanghai
    success "时区已设置为 Asia/Shanghai"
    
    # BBR
    if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p &>/dev/null
        success "TCP BBR 已开启"
    else
        info "TCP BBR 已经开启"
    fi
}

# [8] 配置 Swap
function task_swap() {
    header "配置 Swap 交换空间"
    info "正在拉取 Swap 管理脚本..."
    bash <(curl -sL https://raw.githubusercontent.com/walllal/bash/refs/heads/main/swap.sh)
}

# [0] 一键全流程
function task_all() {
    task_source
    task_essentials
    task_sys_config
    task_docker
    task_swap
    task_firewall
    task_ssh
    
    header "初始化完成"
    success "所有基础任务已执行完毕！"
    echo -e "-------------------------------------------------------------"
    read -p "是否继续安装 1Panel 面板? (y/n): " install_panel
    if [[ "$install_panel" == "y" ]]; then
        task_1panel
    fi
    
    echo -e "${YELLOW}为了确保所有内核参数和更新生效，建议重启服务器。${PLAIN}"
    read -p "是否立即重启? (y/n): " reboot_now
    [[ "$reboot_now" == "y" ]] && reboot
}

# ==============================================================
#  主菜单界面
# ==============================================================
function show_menu() {
    clear
    echo -e "${BLUE}=============================================================${PLAIN}"
    echo -e "${BOLD}            🚀 Linux 服务器初始化助手 (Pro)            ${PLAIN}"
    echo -e "${BLUE}=============================================================${PLAIN}"
    echo -e ""
    echo -e " ${CYAN}[ 系统基础 ]${PLAIN}"
    echo -e "   ${GREEN}1.${PLAIN} 配置软件源 (LinuxMirrors)"
    echo -e "   ${GREEN}2.${PLAIN} 安装基础软件 (Fail2Ban/Curl/Git...)"
    echo -e "   ${GREEN}3.${PLAIN} 配置系统设置 (时区 & BBR)"
    echo -e "   ${GREEN}4.${PLAIN} 配置 Swap 交换空间"
    echo -e ""
    echo -e " ${CYAN}[ 软件应用 ]${PLAIN}"
    echo -e "   ${GREEN}5.${PLAIN} 安装 Docker 环境"
    echo -e "   ${GREEN}6.${PLAIN} 安装 1Panel 面板 ${YELLOW}(含 Docker 检查)${PLAIN}"
    echo -e ""
    echo -e " ${CYAN}[ 安全加固 ]${PLAIN}"
    echo -e "   ${GREEN}7.${PLAIN} 配置 SSH 密钥登录 ${RED}(禁密码)${PLAIN}"
    echo -e "   ${GREEN}8.${PLAIN} 配置 UFW 防火墙"
    echo -e ""
    echo -e "${BLUE}-------------------------------------------------------------${PLAIN}"
    echo -e "   ${GREEN}0.${PLAIN} ${BOLD}一键执行所有基础配置${PLAIN} (1-5, 7-8)"
    echo -e "   ${GREEN}q.${PLAIN} 退出脚本"
    echo -e "${BLUE}=============================================================${PLAIN}"
    echo -e ""
    read -p " 请输入选项编号: " choice

    case "$choice" in
        1) task_source ;;
        2) task_essentials ;;
        3) task_sys_config ;;
        4) task_swap ;;
        5) task_docker ;;
        6) task_1panel ;;
        7) task_ssh ;;
        8) task_firewall ;;
        0) task_all ;;
        q) exit 0 ;;
        *) error "无效输入" ;;
    esac
    
    echo -e ""
    if [[ "$choice" != "q" ]]; then
        read -p "按回车键返回主菜单..."
        show_menu
    fi
}

# 启动菜单
show_menu
