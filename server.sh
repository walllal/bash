#!/bin/bash
# ==============================================================
#  Linux Server Initialization Script (Pro V8)
#  Usage: bash <(curl -sL https://raw.githubusercontent.com/walllal/bash/refs/heads/main/server.sh)
# ==============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'
PLAIN='\033[0m';   BOLD='\033[1m'

BASE_URL="https://raw.githubusercontent.com/walllal/bash/refs/heads/main"

function print_line() { echo -e "${BLUE}-------------------------------------------------------------${PLAIN}"; }
function info()    { echo -e "${BLUE}[INFO]${PLAIN}  $1"; }
function success() { echo -e "${GREEN}[OK]${PLAIN}    $1"; }
function warn()    { echo -e "${YELLOW}[WARN]${PLAIN}  $1"; }
function error()   { echo -e "${RED}[ERROR]${PLAIN} $1"; }

[[ $EUID -ne 0 ]] && error "必须使用 root 用户运行！" && exit 1
[[ ! -f /etc/debian_version ]] && error "仅支持 Debian / Ubuntu！" && exit 1

# 调用模块
function run() { bash <(curl -sL "${BASE_URL}/$1"); }
# 调用模块（重置模式）
function run_reset() { bash <(curl -sL "${BASE_URL}/$1") --reset; }

function show_sysinfo() {
    local os kernel ip mem_used mem_total disk_used disk_total
    os=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2)
    kernel=$(uname -r)
    ip=$(curl -s4m5 ifconfig.me 2>/dev/null || echo "获取失败")
    mem_used=$(free -m | awk '/Mem/{print $3}')
    mem_total=$(free -m | awk '/Mem/{print $2}')
    disk_used=$(df -h / | awk 'NR==2{print $3}')
    disk_total=$(df -h / | awk 'NR==2{print $2}')
    echo -e ""
    echo -e " ${CYAN}主机名:${PLAIN} $(hostname)   ${CYAN}系统:${PLAIN} $os"
    echo -e " ${CYAN}内核:  ${PLAIN} $kernel        ${CYAN}IP:${PLAIN} $ip"
    echo -e " ${CYAN}内存:  ${PLAIN} ${mem_used}MB / ${mem_total}MB   ${CYAN}磁盘:${PLAIN} ${disk_used} / ${disk_total}"
    echo -e " ${CYAN}时间:  ${PLAIN} $(date '+%Y-%m-%d %H:%M:%S %Z')"
}

function show_reset_menu() {
    while true; do
        clear
        echo -e "${RED}=============================================================${PLAIN}"
        echo -e "${BOLD}               ⚠️   重置 / 回退操作中心                   ${PLAIN}"
        echo -e "${RED}=============================================================${PLAIN}"
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
        echo -e "   ${RED}r11.${PLAIN} 恢复 SSH 原始配置"
        echo -e "   ${RED}r12.${PLAIN} 恢复原始 SSH 端口"
        echo -e "   ${RED}r13.${PLAIN} 关闭 Telegram 登录通知"
        echo -e "   ${RED}r14.${PLAIN} 关闭防火墙与 Fail2Ban"
        echo -e "   ${RED}r15.${PLAIN} 卸载 rkhunter"
        echo -e "   ${RED}r16.${PLAIN} 关闭自动安全更新"
        echo -e ""
        echo -e " ${CYAN}[ 体验优化 ]${PLAIN}"
        echo -e "   ${RED}r17.${PLAIN} 恢复默认 MOTD"
        echo -e "   ${RED}r18.${PLAIN} 卸载 ZSH 环境"
        echo -e ""
        echo -e "${RED}-------------------------------------------------------------${PLAIN}"
        echo -e "   ${GREEN}b.${PLAIN}  返回主菜单"
        echo -e "${RED}=============================================================${PLAIN}"
        echo -e ""
        read -rp " 请输入重置选项: " choice
        echo ""
        case "$choice" in
            r1)  run_reset source.sh ;;
            r2)  run_reset essentials.sh ;;
            r3)  run_reset timezone.sh ;;
            r4)  run_reset bbr.sh ;;
            r5)  run_reset swap.sh ;;
            r6)  run_reset hostname.sh ;;
            r7)  run_reset sysctl.sh ;;
            r8)  run_reset docker.sh ;;
            r9)  run_reset 1panel.sh ;;
            r10) run_reset user.sh ;;
            r11) run_reset ssh.sh ;;
            r12) run_reset ssh-port.sh ;;
            r13) run_reset notify.sh ;;
            r14) run_reset firewall.sh ;;
            r15) run_reset rkhunter.sh ;;
            r16) run_reset autoupdate.sh ;;
            r17) run_reset motd.sh ;;
            r18) run_reset zsh.sh ;;
            b|B) return ;;
            *) error "无效输入" ;;
        esac
        echo ""
        read -rp " 按回车键继续..."
    done
}

function task_all() {
    warn "将依次执行所有基础配置任务"
    read -rp "确认开始? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return
    run source.sh; run essentials.sh; run hostname.sh; run timezone.sh
    run bbr.sh;    run swap.sh;       run sysctl.sh;  run user.sh
    run ssh.sh;    run ssh-port.sh;   run firewall.sh; run rkhunter.sh
    run autoupdate.sh; run motd.sh;   run zsh.sh
    echo ""
    success "所有基础任务执行完毕！"
    read -rp "是否配置 Telegram 通知? (y/n): " n; [[ "$n" == "y" ]] && run notify.sh
    read -rp "是否安装 Docker? (y/n): "         d; [[ "$d" == "y" ]] && run docker.sh
    read -rp "是否安装 1Panel? (y/n): "         p; [[ "$p" == "y" ]] && run 1panel.sh
    read -rp "是否立即重启? (y/n): " rb; [[ "$rb" == "y" ]] && reboot
}

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
        echo -e "   ${GREEN}1.${PLAIN}   配置软件源         ${GREEN}2.${PLAIN}  安装基础工具"
        echo -e "   ${GREEN}3.${PLAIN}   配置时区(NTP)       ${GREEN}4.${PLAIN}  开启 TCP BBR"
        echo -e "   ${GREEN}5.${PLAIN}   配置 Swap           ${GREEN}6.${PLAIN}  配置主机名"
        echo -e "   ${GREEN}7.${PLAIN}   内核参数优化"
        echo -e ""
        echo -e " ${CYAN}[ 软件应用 ]${PLAIN}"
        echo -e "   ${GREEN}8.${PLAIN}   安装 Docker         ${GREEN}9.${PLAIN}  安装 1Panel"
        echo -e ""
        echo -e " ${CYAN}[ 安全加固 ]${PLAIN}"
        echo -e "   ${GREEN}10.${PLAIN}  创建普通用户        ${GREEN}11.${PLAIN} SSH 密钥登录"
        echo -e "   ${GREEN}12.${PLAIN}  修改 SSH 端口       ${GREEN}13.${PLAIN} Telegram 登录通知"
        echo -e "   ${GREEN}14.${PLAIN}  UFW & Fail2Ban      ${GREEN}15.${PLAIN} rkhunter 检测"
        echo -e "   ${GREEN}16.${PLAIN}  自动安全更新"
        echo -e ""
        echo -e " ${CYAN}[ 体验优化 ]${PLAIN}"
        echo -e "   ${GREEN}17.${PLAIN}  MOTD 美化           ${GREEN}18.${PLAIN} ZSH 环境"
        echo -e ""
        echo -e "${BLUE}-------------------------------------------------------------${PLAIN}"
        echo -e "   ${GREEN}0.${PLAIN}   一键全部配置"
        echo -e "   ${RED}r.${PLAIN}   重置 / 回退中心"
        echo -e "   ${GREEN}q.${PLAIN}   退出"
        echo -e "${BLUE}=============================================================${PLAIN}"
        echo -e ""
        read -rp " 请输入选项: " choice
        echo ""
        case "$choice" in
            1)  run source.sh ;;     2)  run essentials.sh ;;
            3)  run timezone.sh ;;   4)  run bbr.sh ;;
            5)  run swap.sh ;;       6)  run hostname.sh ;;
            7)  run sysctl.sh ;;     8)  run docker.sh ;;
            9)  run 1panel.sh ;;     10) run user.sh ;;
            11) run ssh.sh ;;        12) run ssh-port.sh ;;
            13) run notify.sh ;;     14) run firewall.sh ;;
            15) run rkhunter.sh ;;   16) run autoupdate.sh ;;
            17) run motd.sh ;;       18) run zsh.sh ;;
            0)  task_all ;;
            r|R) show_reset_menu ;;
            q|Q) success "已退出"; exit 0 ;;
            *) error "无效输入" ;;
        esac
        echo ""
        read -rp " 按回车键返回主菜单..."
    done
}

show_menu
