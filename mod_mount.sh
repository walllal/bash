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

header "[8] 磁盘挂载"

# --- 展示当前磁盘状态 ---
info "当前磁盘列表 (lsblk)："
echo -e ""
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
echo -e ""

# --- 选择目标磁盘 ---
echo -e "请选择要挂载的磁盘 (如 /dev/vdb)，或输入 q 退出："
read -rp "磁盘设备: " DISK

if [[ "$DISK" == "q" || "$DISK" == "Q" ]]; then
    warn "已取消磁盘挂载"
    exit 0
fi

# 校验磁盘是否存在
if [[ ! -b "$DISK" ]]; then
    error "设备 $DISK 不存在或不是块设备，请检查输入 (可使用 lsblk 查看)"
    exit 1
fi

# 系统盘保护：禁止挂载系统盘 vda / sda
if [[ "$DISK" == "/dev/vda"* || "$DISK" == "/dev/sda"* ]]; then
    error "禁止挂载系统盘 $DISK！"
    exit 1
fi

# --- 选择挂载点 ---
read -rp "请输入挂载点目录 (默认 /mnt/data): " MOUNT_POINT
[[ -z "$MOUNT_POINT" ]] && MOUNT_POINT="/mnt/data"

# --- 选择文件系统 ---
echo -e "请选择文件系统类型："
echo -e "  ${GREEN}1.${PLAIN} ext4 (默认，通用性最好)"
echo -e "  ${GREEN}2.${PLAIN} xfs  (大文件性能好)"
echo -e "  ${GREEN}3.${PLAIN} btrfs (快照/压缩)"
read -rp "请输入选择 [1-3] (默认 1): " fs_opt
[[ -z "$fs_opt" ]] && fs_opt="1"
case "$fs_opt" in
    1) FILESYSTEM="ext4" ;;
    2) FILESYSTEM="xfs"  ;;
    3) FILESYSTEM="btrfs" ;;
    *) FILESYSTEM="ext4" ;;
esac

# --- 询问是否格式化（危险操作） ---
echo -e ""
warn "格式化会清空磁盘上的所有数据！"
read -rp "是否格式化 $DISK 为 $FILESYSTEM? [y/N]: " do_format

if [[ "$do_format" =~ ^[Yy]$ ]]; then
    info "正在格式化 $DISK 为 $FILESYSTEM ..."
    mkfs.$FILESYSTEM -F "$DISK"
    if [[ $? -ne 0 ]]; then
        error "格式化失败！"
        exit 1
    fi
    success "格式化完成"
else
    info "跳过格式化，将直接挂载（请确保磁盘已有文件系统）"
fi

# --- 创建挂载点并挂载 ---
mkdir -p "$MOUNT_POINT"
mount "$DISK" "$MOUNT_POINT"
if [[ $? -ne 0 ]]; then
    error "挂载失败，请检查磁盘与文件系统"
    exit 1
fi
success "已挂载 $DISK 到 $MOUNT_POINT"

# --- 写入 fstab 实现开机自动挂载 ---
UUID=$(blkid -s UUID -o value "$DISK")
if grep -qs "$UUID" /etc/fstab; then
    warn "该磁盘已在 /etc/fstab 中，跳过自动挂载配置"
else
    echo "UUID=$UUID $MOUNT_POINT $FILESYSTEM defaults,noatime 0 2" >> /etc/fstab
    success "已写入 /etc/fstab，开机将自动挂载"
fi

# --- 展示结果 ---
echo -e ""
success "挂载完成！"
info "当前挂载情况："
df -h "$MOUNT_POINT"
info "验证开机自动挂载: mount -a"
