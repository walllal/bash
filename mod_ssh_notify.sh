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

SSH_NOTIFY_SCRIPT="/etc/profile.d/ssh-login-notify.sh"
ROOT_NOTIFY_SCRIPT="/etc/profile.d/root-escalation-notify.sh"
COMMON_FUNC_SCRIPT="/etc/profile.d/tg-notify-common.sh"

header "[13] SSH 登录 Telegram 通知"
echo -e "功能说明："
echo -e "  • 普通用户 SSH 登录时发送通知"
echo -e "  • 通过 sudo su / su - 切换到 root 时发送通知"
echo -e "通知内容：登录用户、来源IP、地理位置、登录时间、主机名"
echo ""

if [[ -f "$SSH_NOTIFY_SCRIPT" ]] || [[ -f "$ROOT_NOTIFY_SCRIPT" ]]; then
    warn "检测到已存在通知脚本"
    [[ -f "$SSH_NOTIFY_SCRIPT" ]]  && info "SSH登录通知:   $SSH_NOTIFY_SCRIPT"
    [[ -f "$ROOT_NOTIFY_SCRIPT" ]] && info "Root切换通知:  $ROOT_NOTIFY_SCRIPT"
    read -rp "是否重新配置? (y/n): " reconfig
    [[ "$reconfig" != "y" ]] && exit 0
fi

# ---------------------------------------------------------------
# 获取 Bot Token
# ---------------------------------------------------------------
echo -e "${CYAN}步骤 1/2：获取 Bot Token${PLAIN}"
echo -e "  1. Telegram 搜索 @BotFather"
echo -e "  2. 发送 /newbot 创建机器人"
echo -e "  3. 复制获得的 Token (格式: 1234567890:ABCDefgh...)"
echo ""
read -rp "请输入 Bot Token: " BOT_TOKEN

if [[ -z "$BOT_TOKEN" ]]; then
    error "Bot Token 不能为空"; exit 1
fi
if [[ ! "$BOT_TOKEN" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; then
    warn "Token 格式似乎不标准，仍将继续（如遇问题请检查Token）"
fi

# ---------------------------------------------------------------
# 获取 Chat ID
# ---------------------------------------------------------------
echo ""
echo -e "${CYAN}步骤 2/2：获取 Chat ID${PLAIN}"
echo -e "  1. 向你的机器人发送任意一条消息"
echo -e "  2. 访问: https://api.telegram.org/bot${BOT_TOKEN}/getUpdates"
echo -e "  3. 找到 \"chat\":{\"id\": XXXXXXXX} 中的数字"
echo ""
read -rp "请输入 Chat ID: " CHAT_ID

if [[ -z "$CHAT_ID" ]]; then
    error "Chat ID 不能为空"; exit 1
fi
if [[ ! "$CHAT_ID" =~ ^-?[0-9]+$ ]]; then
    error "Chat ID 格式无效，应为纯数字（群组ID可能含负号）"; exit 1
fi

# ---------------------------------------------------------------
# 发送测试消息
# ---------------------------------------------------------------
info "正在发送测试消息，验证配置是否正确..."
TEST_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=✅ Telegram 通知配置成功！来自服务器: $(hostname)" \
    -d "parse_mode=HTML" 2>/dev/null)

if [[ "$TEST_RESULT" != "200" ]]; then
    error "测试消息发送失败 (HTTP $TEST_RESULT)，请检查 Token 和 Chat ID 是否正确"
    read -rp "是否忽略错误仍然保存配置? (y/n): " ignore_err
    [[ "$ignore_err" != "y" ]] && exit 1
else
    success "测试消息发送成功！请查看 Telegram 是否收到消息"
fi

# ---------------------------------------------------------------
# 写入公共配置文件（只存 Token 和 ChatID，不含函数）
# profile.d 脚本是 source 执行的，公共函数不适合放这里
# 改为存纯变量配置文件，由各通知脚本独立读取
# ---------------------------------------------------------------
COMMON_CONF="/etc/tg-notify.conf"

cat > "$COMMON_CONF" << EOF
# Telegram 通知配置
# 由 server-init 脚本自动生成
TG_BOT_TOKEN="${BOT_TOKEN}"
TG_CHAT_ID="${CHAT_ID}"
EOF

chmod 600 "$COMMON_CONF"
success "通知配置文件已创建: $COMMON_CONF"

# ---------------------------------------------------------------
# 写入 SSH 登录通知脚本
# 关键：所有逻辑包在 ( ) & 子shell中执行
# 原因：profile.d 脚本是 source 执行，直接 exit 会退出登录 shell
#       用子shell隔离，exit 只退出子shell，不影响用户登录
# ---------------------------------------------------------------
cat > "$SSH_NOTIFY_SCRIPT" << 'NOTIFY_EOF'
#!/bin/bash
# SSH 登录 Telegram 通知
# 由 server-init 脚本自动生成
# ⚠️ 所有逻辑必须在 ( ) & 子shell中运行，禁止在顶层使用 exit
# 否则 source 执行时 exit 会直接退出用户的登录 shell

(
    # 仅在 SSH 登录时触发
    [[ -z "$SSH_CLIENT" && -z "$SSH_TTY" ]] && exit 0

    # 读取配置
    [[ ! -f /etc/tg-notify.conf ]] && exit 0
    source /etc/tg-notify.conf

    # 收集登录信息
    LOGIN_USER="$(whoami)"
    LOGIN_IP="$(echo "$SSH_CLIENT" | awk '{print $1}')"
    LOGIN_PORT="$(echo "$SSH_CLIENT" | awk '{print $3}')"
    LOGIN_TIME="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    HOST_NAME="$(hostname)"
    HOST_IP="$(curl -s4m3 ifconfig.me 2>/dev/null || echo '未知')"

    # 获取地理信息
    GEO_INFO="$(curl -sm3 "https://ipinfo.io/${LOGIN_IP}/json" 2>/dev/null)"
    GEO_COUNTRY="$(echo "$GEO_INFO" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)"
    GEO_CITY="$(echo "$GEO_INFO"    | grep -o '"city":"[^"]*"'    | cut -d'"' -f4)"
    GEO_ORG="$(echo "$GEO_INFO"     | grep -o '"org":"[^"]*"'     | cut -d'"' -f4)"
    GEO_STR="${GEO_CITY:-未知}, ${GEO_COUNTRY:-未知} | ${GEO_ORG:-未知}"

    MESSAGE="🔐 <b>SSH 登录通知</b>
━━━━━━━━━━━━━━━━━━━━
🖥️ <b>主机:</b> ${HOST_NAME} (${HOST_IP})
👤 <b>用户:</b> ${LOGIN_USER}
🌐 <b>来源IP:</b> ${LOGIN_IP}:${LOGIN_PORT}
📍 <b>地区:</b> ${GEO_STR}
🕐 <b>时间:</b> ${LOGIN_TIME}
━━━━━━━━━━━━━━━━━━━━
⚠️ 若非本人操作，请立即检查！"

    curl -s "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        -d "text=${MESSAGE}" \
        -d "parse_mode=HTML" \
        --max-time 5 \
        > /dev/null 2>&1

) &
# ^ 子shell在后台运行，不阻塞登录，exit只退出子shell不影响父shell
NOTIFY_EOF

chmod +x "$SSH_NOTIFY_SCRIPT"
success "SSH 登录通知脚本已安装: $SSH_NOTIFY_SCRIPT"

# ---------------------------------------------------------------
# 写入 Root 切换通知脚本
# 同样：所有逻辑包在 ( ) & 子shell中，禁止顶层 exit
# ---------------------------------------------------------------
cat > "$ROOT_NOTIFY_SCRIPT" << 'ROOT_EOF'
#!/bin/bash
# Root 权限切换 Telegram 通知
# 触发时机：通过 sudo su / su - 切换到 root 时
# 由 server-init 脚本自动生成
# ⚠️ 所有逻辑必须在 ( ) & 子shell中运行，禁止在顶层使用 exit
# 否则 source 执行时 exit 会直接把用户踢出 root shell

(
    # 只在切换到 root 时触发
    [[ "$(id -u)" -ne 0 ]] && exit 0

    # 读取配置
    [[ ! -f /etc/tg-notify.conf ]] && exit 0
    source /etc/tg-notify.conf

    SWITCH_TIME="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    HOST_NAME="$(hostname)"
    HOST_IP="$(curl -s4m3 ifconfig.me 2>/dev/null || echo '未知')"

    # ---- 判断切换来源 ----

    # 场景1: sudo su / sudo -i / sudo -s
    # SUDO_USER 由 sudo 自动设置，包含原始用户名
    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        FROM_USER="$SUDO_USER"
        SWITCH_TYPE="sudo su"
        SWITCH_ICON="🔑"

        # 从 who 命令获取该用户的 SSH 来源 IP
        FROM_IP="$(who | grep "^${SUDO_USER}" | awk '{print $NF}' | \
            sed 's/[()]//g' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)"
        [[ -z "$FROM_IP" ]] && FROM_IP="本地/未知"

    # 场景2: su - / su root
    else
        WHO_INFO="$(who am i 2>/dev/null)"
        FROM_USER="$(echo "$WHO_INFO" | awk '{print $1}')"
        FROM_IP="$(echo "$WHO_INFO" | awk '{print $NF}' | sed 's/[()]//g')"

        # who am i 获取失败时通过父进程判断
        if [[ -z "$FROM_USER" || "$FROM_USER" == "root" ]]; then
            FROM_USER="$(ps -o user= -p $PPID 2>/dev/null | head -1 | tr -d ' ')"
            [[ -z "$FROM_USER" || "$FROM_USER" == "root" ]] && exit 0
            FROM_IP="本地/未知"
        fi

        SWITCH_TYPE="su -"
        SWITCH_ICON="🔓"
    fi

    # 来源是 root 本身则不通知（避免误报）
    [[ "$FROM_USER" == "root" || -z "$FROM_USER" ]] && exit 0

    # 获取来源 IP 地理信息
    if [[ "$FROM_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        GEO_INFO="$(curl -sm3 "https://ipinfo.io/${FROM_IP}/json" 2>/dev/null)"
        GEO_COUNTRY="$(echo "$GEO_INFO" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)"
        GEO_CITY="$(echo "$GEO_INFO"    | grep -o '"city":"[^"]*"'    | cut -d'"' -f4)"
        GEO_ORG="$(echo "$GEO_INFO"     | grep -o '"org":"[^"]*"'     | cut -d'"' -f4)"
        GEO_STR="${GEO_CITY:-未知}, ${GEO_COUNTRY:-未知} | ${GEO_ORG:-未知}"
    else
        GEO_STR="本地终端"
    fi

    MESSAGE="🚨 <b>Root 权限切换通知</b>
━━━━━━━━━━━━━━━━━━━━
🖥️ <b>主机:</b> ${HOST_NAME} (${HOST_IP})
${SWITCH_ICON} <b>切换方式:</b> ${SWITCH_TYPE}
👤 <b>操作用户:</b> ${FROM_USER} → root
🌐 <b>来源IP:</b> ${FROM_IP}
📍 <b>地区:</b> ${GEO_STR}
🕐 <b>时间:</b> ${SWITCH_TIME}
━━━━━━━━━━━━━━━━━━━━
⚠️ 若非本人操作，请立即检查！"

    curl -s "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        -d "text=${MESSAGE}" \
        -d "parse_mode=HTML" \
        --max-time 5 \
        > /dev/null 2>&1

) &
# ^ 子shell在后台运行，不阻塞切换，exit只退出子shell不影响父shell
ROOT_EOF

chmod +x "$ROOT_NOTIFY_SCRIPT"
success "Root 切换通知脚本已安装: $ROOT_NOTIFY_SCRIPT"

# ---------------------------------------------------------------
# 配置 sudo 保留 SSH 环境变量
# ---------------------------------------------------------------
print_line
info "正在配置 sudo 环境变量保留..."

SUDOERS_CONF="/etc/sudoers.d/99-notify-env"
cat > "$SUDOERS_CONF" << 'EOF'
# 保留通知所需的环境变量
# 由 server-init 脚本自动生成
Defaults env_keep += "SSH_CLIENT SSH_TTY SSH_CONNECTION"
EOF

chmod 440 "$SUDOERS_CONF"

if visudo -cf "$SUDOERS_CONF" &>/dev/null; then
    success "sudo 环境变量配置完成: $SUDOERS_CONF"
else
    warn "sudo 配置语法验证失败，已删除该文件"
    rm -f "$SUDOERS_CONF"
fi

# ---------------------------------------------------------------
# 输出安装摘要
# ---------------------------------------------------------------
echo ""
success "Telegram 通知配置完成，摘要："
echo ""
echo -e "  ${CYAN}已安装脚本:${PLAIN}"
echo -e "   ${GREEN}①${PLAIN} SSH登录通知:   ${CYAN}$SSH_NOTIFY_SCRIPT${PLAIN}"
echo -e "      触发时机: 任意用户通过 SSH 登录时"
echo -e ""
echo -e "   ${GREEN}②${PLAIN} Root切换通知: ${CYAN}$ROOT_NOTIFY_SCRIPT${PLAIN}"
echo -e "      触发时机: 通过 sudo su / su - 切换到 root 时"
echo -e ""
echo -e "   ${GREEN}③${PLAIN} 通知配置:     ${CYAN}$COMMON_CONF${PLAIN}"
echo -e "      作用:     存储 Bot Token 和 Chat ID"
echo ""
echo -e "  ${CYAN}通知场景覆盖:${PLAIN}"
echo -e "   ${GREEN}✓${PLAIN} 普通用户 SSH 登录          → 👤 SSH 登录通知"
echo -e "   ${GREEN}✓${PLAIN} 普通用户 sudo su 到 root   → 🔑 Root 切换通知 (sudo)"
echo -e "   ${GREEN}✓${PLAIN} 普通用户 su - 到 root      → 🔓 Root 切换通知 (su)"
echo -e "   ${YELLOW}—${PLAIN} root 直接 SSH 登录         → 已禁用，不会触发"
echo ""
echo -e "  ${CYAN}管理命令:${PLAIN}"
echo -e "   停用所有通知: ${YELLOW}rm $SSH_NOTIFY_SCRIPT $ROOT_NOTIFY_SCRIPT $COMMON_CONF${PLAIN}"
echo -e "   修改Token:    ${YELLOW}nano $COMMON_CONF${PLAIN}"
echo ""
warn "通知将从下次登录/切换时开始生效，当前会话不触发"
