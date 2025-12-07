#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 检查是否以 Root 权限运行
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 必须使用 root 用户运行此脚本！${PLAIN}" && exit 1

# 检查并安装 curl
if ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}检测到未安装 curl，正在安装...${PLAIN}"
    if [ -f /etc/redhat-release ]; then
        yum install -y curl
    elif cat /etc/issue | grep -q -E -i "debian|ubuntu"; then
        apt-get update && apt-get install -y curl
    elif cat /etc/issue | grep -q -E -i "alpine"; then
        apk add curl
    else
        echo -e "${RED}无法自动安装 curl，请手动安装后重试。${PLAIN}"
        exit 1
    fi
fi

# 功能 1: 更新软件源
function update_source() {
    echo -e "${GREEN}>>> 开始更新软件源 (使用 --abroad 模式)...${PLAIN}"
    bash <(curl -sSL https://linuxmirrors.cn/main.sh) --abroad
}

# 功能 2: 安装 Docker
function install_docker() {
    echo -e "${GREEN}>>> 开始安装 Docker...${PLAIN}"
    bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
}

# 功能 3: 设置 Swap 内存
function setup_swap() {
    echo -e "${GREEN}>>> 开始设置 Swap 内存...${PLAIN}"
    bash <(curl -sL https://gist.githubusercontent.com/walllal/cfdc13f6fbc21bc61e8d1ae279141980/raw/b6020aa68a66c40d0ddbe4d0a3f8785dee53fce3/swap.sh)
}

# 功能 4: 一键执行所有 (顺序: 源 -> Docker -> Swap)
function run_all() {
    echo -e "${YELLOW}即将开始按顺序执行所有任务...${PLAIN}"
    sleep 2
    
    echo -e "${GREEN}STEP 1/3: 更新软件源${PLAIN}"
    update_source
    echo -e "------------------------------------------------"
    
    echo -e "${GREEN}STEP 2/3: 安装 Docker${PLAIN}"
    install_docker
    echo -e "------------------------------------------------"
    
    echo -e "${GREEN}STEP 3/3: 设置 Swap${PLAIN}"
    setup_swap
    
    echo -e "${GREEN}所有任务执行完毕！${PLAIN}"
}

# 主菜单
function show_menu() {
    clear
    echo -e "============================================"
    echo -e " ${GREEN}服务器初始化综合脚本${PLAIN}"
    echo -e "============================================"
    echo -e " 1. 更新软件源 (LinuxMirrors --abroad)"
    echo -e " 2. 安装 Docker (LinuxMirrors)"
    echo -e " 3. 设置 Swap 内存"
    echo -e " -------------------------------------------"
    echo -e " 4. 一键运行所有 (1 -> 2 -> 3)"
    echo -e " 0. 退出脚本"
    echo -e "============================================"
    read -p " 请输入数字 [0-4]: " num

    case "$num" in
        1)
            update_source
            ;;
        2)
            install_docker
            ;;
        3)
            setup_swap
            ;;
        4)
            run_all
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}请输入正确的数字 [0-4]${PLAIN}"
            sleep 2
            show_menu
            ;;
    esac
}

# 运行菜单
show_menu
