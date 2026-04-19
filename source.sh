#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; PLAIN='\033[0m'; BOLD='\033[1m'
function info()    { echo -e "${BLUE}[INFO]${PLAIN}  $1"; }
function success() { echo -e "${GREEN}[OK]${PLAIN}    $1"; }
function warn()    { echo -e "${YELLOW}[WARN]${PLAIN}  $1"; }
function error()   { echo -e "${RED}[ERROR]${PLAIN} $1"; }
STATE_DIR="/etc/server-init/state"; mkdir -p "$STATE_DIR"

function do_install() {
    echo -e "\n${PURPLE}${BOLD}  配置系统软件源${PLAIN}"
    echo -e "-------------------------------------------------------------"

    # 首次执行时备份
    if [[ ! -f "$STATE_DIR/sources.saved" ]]; then
        [[ -f /etc/apt/sources.list ]] && \
            cp /etc/apt/sources.list "$STATE_DIR/sources.list.orig"
        [[ -d /etc/apt/sources.list.d ]] && \
            tar -czf "$STATE_DIR/sources.list.d.orig.tar.gz" \
                -C /etc/apt sources.list.d 2>/dev/null || true
        touch "$STATE_DIR/sources.saved"
        info "已备份原始软件源"
    fi

    echo -e "请选择服务器网络环境："
    echo -e "  ${GREEN}1.${PLAIN} 国内服务器 (清华/中科大/阿里镜像)"
    echo -e "  ${GREEN}2.${PLAIN} 海外服务器 (官方源)"
    echo -e "  ${GREEN}3.${PLAIN} 跳过"
    read -rp "请输入选择 [1-3]: " choice
    case "$choice" in
        1) bash <(curl -sSL https://linuxmirrors.cn/main.sh) ;;
        2) bash <(curl -sSL https://linuxmirrors.cn/main.sh) --abroad ;;
        *) warn "已跳过" ;;
    esac
}

function do_reset() {
    echo -e "\n${RED}${BOLD}  [重置] 恢复原始软件源${PLAIN}"
    echo -e "-------------------------------------------------------------"
    if [[ ! -f "$STATE_DIR/sources.saved" ]]; then
        warn "未找到备份，跳过"; return
    fi
    read -rp "确认恢复原始软件源? (y/n): " c; [[ "$c" != "y" ]] && return
    [[ -f "$STATE_DIR/sources.list.orig" ]] && \
        cp "$STATE_DIR/sources.list.orig" /etc/apt/sources.list
    [[ -f "$STATE_DIR/sources.list.d.orig.tar.gz" ]] && \
        tar -xzf "$STATE_DIR/sources.list.d.orig.tar.gz" -C /etc/apt 2>/dev/null
    apt update -y
    rm -f "$STATE_DIR/sources.saved" "$STATE_DIR/sources.list.orig" \
          "$STATE_DIR/sources.list.d.orig.tar.gz"
    success "软件源已恢复"
}

[[ "$1" == "--reset" ]] && do_reset || do_install
