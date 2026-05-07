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
    error "时区不能为空，已跳过"; exit 1
fi

if ! timedatectl list-timezones | grep -qx "$MY_TZ"; then
    error "时区 '$MY_TZ' 无效，请检查输入"; exit 1
fi

timedatectl set-timezone "$MY_TZ"
timedatectl set-ntp true
success "时区已更新为: $MY_TZ"
info "NTP 同步状态: $(timedatectl show -p NTPSynchronized --value)"
info "更新后时间: $(date)"
