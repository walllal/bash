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

# --- 系统兼容性检查 ---
if [[ ! -f /etc/debian_version ]]; then
    error "此脚本仅支持 Debian 系统！"
    exit 1
fi

DEBIAN_CODENAME=$(grep VERSION_CODENAME /etc/os-release 2>/dev/null | cut -d= -f2)
info "检测到 Debian 系统，代号: ${DEBIAN_CODENAME:-未知}"

echo -e "请选择服务器网络环境："
echo -e "  ${GREEN}1.${PLAIN} 国内服务器 (清华/中科大/阿里等镜像)"
echo -e "  ${GREEN}2.${PLAIN} 海外服务器 (官方 CDN: deb.debian.org)"
echo -e "  ${GREEN}3.${PLAIN} 更新系统软件包 (apt update + upgrade + 清理)"
echo -e "  ${GREEN}0.${PLAIN} 跳过"
read -rp "请输入选择 [0-3]: " choice

case "$choice" in
    1)
        info "使用国内镜像一键脚本 (linuxmirrors.cn) 配置..."
        bash <(curl -sSL https://linuxmirrors.cn/main.sh)
        ;;
    2)
        info "写入 Debian 官方 CDN 源 (deb.debian.org)..."
        # 备份原源
        if [[ ! -f /etc/apt/sources.list.bak ]]; then
            cp /etc/apt/sources.list /etc/apt/sources.list.bak
            info "已备份原源到 /etc/apt/sources.list.bak"
        fi
        # 写入官方 CDN 源（deb.debian.org 会自动重定向到就近镜像）
        cat > /etc/apt/sources.list <<EOF
deb https://deb.debian.org/debian ${DEBIAN_CODENAME:-bookworm} main contrib non-free non-free-firmware
deb https://deb.debian.org/debian-security ${DEBIAN_CODENAME:-bookworm}-security main contrib non-free non-free-firmware
deb https://deb.debian.org/debian ${DEBIAN_CODENAME:-bookworm}-updates main contrib non-free non-free-firmware
EOF
        success "官方 CDN 源已写入"
        info "正在更新软件包索引..."
        apt update -y
        if [[ $? -eq 0 ]]; then
            success "软件源索引更新完成"
        else
            error "软件源索引更新失败，请检查网络"
        fi
        ;;
    3)
        info "开始更新系统软件包..."
        apt update -y \
        && echo "软件源索引更新完成" \
        && \
        # 4. 升级所有已安装软件包（-y 自动确认）
        apt upgrade -y \
        && echo "系统软件升级完成" \
        && \
        # 5. 清理无用依赖与缓存
        apt autoremove -y \
        && apt autoclean \
        && success "全部完成！系统已升级到最新状态。"
        ;;
    *)
        warn "已跳过软件源配置"
        ;;
esac
