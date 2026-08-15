#!/bin/bash

# ==============================================================
#  Linux Server Initialization Script (Ultimate Edition v7)
#  Author: Optimized Edition
#  System: Debian / Ubuntu
# ==============================================================

# --- 权限检查 ---
[[ $EUID -ne 0 ]] && echo -e "\033[0;31m[ERROR]\033[0m 必须使用 root 用户运行此脚本！" && exit 1

# --- 系统兼容性检查 ---
if [[ ! -f /etc/debian_version ]]; then
    echo -e "\033[0;31m[ERROR]\033[0m 此脚本仅支持 Debian / Ubuntu 系统！"
    exit 1
fi

# --- 确保 curl 可用 ---
if ! command -v curl &>/dev/null; then
    echo -e "\033[0;33m[WARN]\033[0m 未检测到 curl，正在安装..."
    apt update -qq && apt install -y -qq curl
fi

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
PLAIN='\033[0m'
BOLD='\033[1m'

# --- 基础URL ---
BASE_URL="https://raw.githubusercontent.com/walllal/bash/refs/heads/main"

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
#  模块调度函数（每个函数只负责调用对应模块脚本）
# ==============================================================
function task_source()       { bash <(curl -sL "${BASE_URL}/mod_source.sh"); }
function task_essentials()   { bash <(curl -sL "${BASE_URL}/mod_essentials.sh"); }
function task_timezone()     { bash <(curl -sL "${BASE_URL}/mod_timezone.sh"); }
function task_bbr()          { bash <(curl -sL "${BASE_URL}/mod_bbr.sh"); }
function task_swap()         { bash <(curl -sL "${BASE_URL}/swap.sh"); }
function task_hostname()     { bash <(curl -sL "${BASE_URL}/mod_hostname.sh"); }
function task_sysctl()       { bash <(curl -sL "${BASE_URL}/mod_sysctl.sh"); }
function task_mount()        { bash <(curl -sL "${BASE_URL}/mod_mount.sh"); }
function task_docker()       { bash <(curl -sL "${BASE_URL}/mod_docker.sh"); }
function task_1panel()       { bash <(curl -sL "${BASE_URL}/mod_1panel.sh"); }
function task_create_user()  { bash <(curl -sL "${BASE_URL}/mod_user.sh"); }
function task_ssh()          { bash <(curl -sL "${BASE_URL}/mod_ssh.sh"); }
function task_ssh_port()     { bash <(curl -sL "${BASE_URL}/mod_ssh_port.sh"); }
function task_ssh_notify()   { bash <(curl -sL "${BASE_URL}/mod_ssh_notify.sh"); }
function task_motd()         { bash <(curl -sL "${BASE_URL}/mod_motd.sh"); }

# ==============================================================
#  主菜单
# ==============================================================
function show_menu() {
    while true; do
        clear
        echo -e "${BLUE}=============================================================${PLAIN}"
        echo -e "${BOLD}            Linux 服务器初始化助手           ${PLAIN}"
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
        echo -e "   ${GREEN}8.${PLAIN}   磁盘挂载"
        echo -e ""
        echo -e " ${CYAN}[ 软件应用 ]${PLAIN}"
        echo -e "   ${GREEN}9.${PLAIN}   安装 Docker"
        echo -e "   ${GREEN}10.${PLAIN}  安装 1Panel 面板"
        echo -e ""
        echo -e " ${CYAN}[ 安全加固 ]${PLAIN}"
        echo -e "   ${GREEN}11.${PLAIN}  创建普通用户 ${CYAN}(sudo权限 + SSH同步)${PLAIN}"
        echo -e "   ${GREEN}12.${PLAIN}  配置 SSH 密钥登录 ${RED}(禁密码)${PLAIN}"
        echo -e "   ${GREEN}13.${PLAIN}  修改 SSH 端口 ${CYAN}(联动UFW/Fail2Ban)${PLAIN}"
        echo -e "   ${GREEN}14.${PLAIN}  SSH 登录 Telegram 通知"
        echo -e ""
        echo -e " ${CYAN}[ 体验优化 ]${PLAIN}"
        echo -e "   ${GREEN}15.${PLAIN}  MOTD 系统信息美化"
        echo -e ""
        echo -e "${BLUE}-------------------------------------------------------------${PLAIN}"
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
            8)   task_mount ;;
            9)   task_docker ;;
            10)  task_1panel ;;
            11)  task_create_user ;;
            12)  task_ssh ;;
            13)  task_ssh_port ;;
            14)  task_ssh_notify ;;
            15)  task_motd ;;
            q|Q) success "已退出脚本"; exit 0 ;;
            *)   error "无效输入: '$choice'，请重新选择" ;;
        esac

        echo ""
        read -rp " 按回车键返回主菜单..."
    done
}

show_menu
