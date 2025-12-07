#!/bin/bash

#=================================================
# Description: Linux Swap Management Script
# Best Practice: Based on Debian/Ubuntu Server Docs
# System Required: CentOS/Debian/Ubuntu
#=================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'

# 定义 Swap 文件路径
SWAP_FILE="/swapfile"

# 检查是否为 Root 用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 必须使用 root 用户运行此脚本！${PLAIN}" 
   exit 1
fi

# 获取当前 Swap 信息
function get_swap_info() {
    echo -e "${SKYBLUE}当前 Swap 状态:${PLAIN}"
    if free -h | grep -q "Swap"; then
        free -h | grep -i swap
    else
        echo "无 Swap 分区"
    fi
    echo ""
}

# 1. 添加或修改 Swap
function add_swap() {
    echo -e "${YELLOW}准备创建或修改 Swap...${PLAIN}"
    
    # 内存建议提示
    mem_total_gb=$(free -g | awk '/^Mem:/{print $2}')
    echo -e "系统物理内存: ${SKYBLUE}${mem_total_gb}GB${PLAIN}"
    echo -e "建议大小: 内存<=2G设为2倍; 2G-8G设为等大; >8G设为8G。"
    
    # 获取用户输入
    read -p "请输入需要设置的 Swap 大小 (单位: GB, 例如输入 2): " swap_size
    
    # 简单的数字检查
    if [[ ! $swap_size =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误: 请输入有效的整数数字！${PLAIN}"
        return
    fi

    # 如果已经存在 swapfile，先清理
    if [ -f "$SWAP_FILE" ]; then
        echo -e "${YELLOW}检测到已存在 $SWAP_FILE，正在卸载并清理旧文件...${PLAIN}"
        swapoff $SWAP_FILE >/dev/null 2>&1
        # 清理 fstab 中的旧记录
        sed -i '/\/swapfile/d' /etc/fstab
        rm -f $SWAP_FILE
    fi

    echo -e "${GREEN}正在创建 ${swap_size}GB 的 Swap 文件...${PLAIN}"
    
    # 尝试使用 fallocate (速度快)，如果失败则回退到 dd (兼容性好)
    if ! fallocate -l ${swap_size}G $SWAP_FILE; then
        echo -e "${YELLOW}fallocate 失败，尝试使用 dd (速度较慢，请耐心等待)...${PLAIN}"
        dd if=/dev/zero of=$SWAP_FILE bs=1M count=$(($swap_size * 1024)) status=progress
    fi

    # 检查文件是否创建成功
    if [ ! -f "$SWAP_FILE" ]; then
        echo -e "${RED}错误: Swap 文件创建失败！${PLAIN}"
        return
    fi

    # [重要] 设置权限: 只有 root 用户应该能够读写交换文件
    echo -e "${GREEN}设置安全权限 (chmod 600)...${PLAIN}"
    chmod 600 $SWAP_FILE
    
    # 格式化为 Swap
    echo -e "${GREEN}标记为 Swap 空间 (mkswap)...${PLAIN}"
    mkswap $SWAP_FILE
    
    # 启用 Swap
    echo -e "${GREEN}启用 Swap (swapon)...${PLAIN}"
    swapon $SWAP_FILE
    
    # 写入 fstab 实现开机自启
    echo -e "${GREEN}写入 /etc/fstab 配置开机自启...${PLAIN}"
    # 确保不重复写入
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi
    
    echo -e "${GREEN}Swap 设置成功！${PLAIN}"
    
    # 询问是否设置 Swappiness
    read -p "是否需要优化 Swappiness 值 (推荐服务器选 y)? [y/n]: " opt_swap
    if [[ "$opt_swap" == "y" ]]; then
        set_swappiness "auto"
    fi
    
    get_swap_info
}

# 2. 删除 Swap
function del_swap() {
    if [ ! -f "$SWAP_FILE" ]; then
        echo -e "${RED}错误: 未检测到 $SWAP_FILE，无需删除！${PLAIN}"
        return
    fi

    echo -e "${YELLOW}正在停止 Swap 服务 (swapoff)...${PLAIN}"
    swapoff $SWAP_FILE
    
    echo -e "${YELLOW}正在清理 /etc/fstab 配置...${PLAIN}"
    sed -i '/\/swapfile/d' /etc/fstab
    
    # [安全擦除选项]
    echo -e "${YELLOW}注意：Swap 文件可能包含内存中的敏感数据。${PLAIN}"
    read -p "是否使用 shred 安全擦除文件内容? (较慢, 但更安全) [y/n]: " secure_del
    
    if [[ "$secure_del" == "y" ]]; then
        if command -v shred &> /dev/null; then
            echo -e "${SKYBLUE}正在执行安全擦除 (shred -v -n 1 -z)...${PLAIN}"
            shred -v -n 1 -z $SWAP_FILE
        else
            echo -e "${RED}未找到 shred 命令，将执行普通删除。${PLAIN}"
        fi
    fi
    
    echo -e "${YELLOW}正在删除 Swap 文件...${PLAIN}"
    rm -f $SWAP_FILE
    
    echo -e "${GREEN}Swap 已完全移除！${PLAIN}"
    get_swap_info
}

# 3. 设置 Swappiness
function set_swappiness() {
    # 接收参数，如果是 "auto" 则自动引导，否则手动输入
    local mode=$1
    
    current_swappiness=$(cat /proc/sys/vm/swappiness)
    echo -e "------------------------------------------------"
    echo -e "当前 Swappiness 值: ${SKYBLUE}$current_swappiness${PLAIN}"
    echo -e "值范围: 0-100 (值越低，越倾向使用物理内存)"
    echo -e "建议值: ${GREEN}10${PLAIN} (适用于大多数服务器)"
    echo -e "------------------------------------------------"
    
    local new_val=""
    if [[ "$mode" == "auto" ]]; then
        echo -e "已自动为您推荐设置值为 10。"
        new_val=10
    else
        read -p "请输入新的 Swappiness 值 (0-100): " new_val
    fi
    
    if [[ ! $new_val =~ ^[0-9]+$ ]] || [ $new_val -lt 0 ] || [ $new_val -gt 100 ]; then
        echo -e "${RED}错误: 输入无效！${PLAIN}"
        return
    fi

    # 临时生效
    sysctl vm.swappiness=$new_val
    
    # 永久生效 (写入 sysctl.conf)
    if grep -q "vm.swappiness" /etc/sysctl.conf; then
        sed -i "s/^vm.swappiness.*/vm.swappiness=$new_val/" /etc/sysctl.conf
    else
        echo "vm.swappiness=$new_val" >> /etc/sysctl.conf
    fi
    
    echo -e "${GREEN}Swappiness 已成功设置为 $new_val (永久生效)${PLAIN}"
}

# 主菜单
function main_menu() {
    clear
    echo -e "============================================"
    echo -e " ${GREEN}Linux Swap 交换空间管理脚本${PLAIN}"
    echo -e "============================================"
    get_swap_info
    echo -e "  1. 添加/修改 Swap 容量"
    echo -e "  2. 删除 Swap (支持安全擦除)"
    echo -e "  3. 修改 Swappiness (优化性能)"
    echo -e "  0. 退出脚本"
    echo -e "============================================"
    read -p "请输入数字 [0-3]: " num
    
    case "$num" in
        1)
            add_swap
            ;;
        2)
            del_swap
            ;;
        3)
            set_swappiness
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}请输入正确的数字！${PLAIN}"
            sleep 2
            main_menu
            ;;
    esac
}

# 运行主菜单
main_menu
