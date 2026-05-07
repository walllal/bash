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
