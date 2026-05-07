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

NOTIFY_SCRIPT="/etc/profile.d/ssh-login-notify.sh"

header "[13] SSH 登录 Telegram 通知"
echo -e "功能说明：每次有用户通过 SSH 登录服务器，将向指定 Telegram 发送通知"
echo -e "通知内容：登录用户、来源IP、地理位置、登录时间、主机名"
echo ""

if [[ -f "$NOTIFY_SCRIPT" ]]; then
    warn "检测到已存在通知脚本: $NOTIFY_SCRIPT"
    read -rp "是否重新配置? (y/n): " reconfig
    [[ "$reconfig" != "y" ]] && exit 0
fi

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

info "正在发送测试消息，验证配置是否正确..."
TEST_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=✅ SSH 登录通知配置成功！来自服务器: $(hostname)" \
    -d "parse_mode=HTML" 2>/dev/null)

if [[ "$TEST_RESULT" != "200" ]]; then
    error "测试消息发送失败 (HTTP $TEST_RESULT)，请检查 Token 和 Chat ID 是否正确"
    read -rp "是否忽略错误仍然保存配置? (y/n): " ignore_err
    [[ "$ignore_err" != "y" ]] && exit 1
else
    success "测试消息发送成功！请查看 Telegram 是否收到消息"
fi

cat > "$NOTIFY_SCRIPT" << EOF
#!/bin/bash
# SSH 登录 Telegram 通知脚本

if [[ -z "\$SSH_CLIENT" && -z "\$SSH_TTY" ]]; then
    exit 0
fi

BOT_TOKEN="${BOT_TOKEN}"
CHAT_ID="${CHAT_ID}"

LOGIN_USER="\$(whoami)"
LOGIN_IP="\$(echo \$SSH_CLIENT | awk '{print \$1}')"
LOGIN_TIME="\$(date '+%Y-%m-%d %H:%M:%S %Z')"
HOST_NAME="\$(hostname)"
HOST_IP="\$(curl -s4m3 ifconfig.me 2>/dev/null || echo '未知')"

GEO_INFO="\$(curl -sm3 "https://ipinfo.io/\${LOGIN_IP}/json" 2>/dev/null)"
GEO_COUNTRY="\$(echo \$GEO_INFO | grep -o '"country":"[^"]*"' | cut -d'"' -f4 || echo '未知')"
GEO_CITY="\$(echo \$GEO_INFO | grep -o '"city":"[^"]*"' | cut -d'"' -f4 || echo '未知')"
GEO_ORG="\$(echo \$GEO_INFO | grep -o '"org":"[^"]*"' | cut -d'"' -f4 || echo '未知')"

MESSAGE="🔐 <b>SSH 登录通知</b>
━━━━━━━━━━━━━━━━
🖥️ <b>主机:</b> \${HOST_NAME} (\${HOST_IP})
👤 <b>用户:</b> \${LOGIN_USER}
🌐 <b>来源IP:</b> \${LOGIN_IP}
📍 <b>地区:</b> \${GEO_CITY}, \${GEO_COUNTRY}
🏢 <b>运营商:</b> \${GEO_ORG}
🕐 <b>时间:</b> \${LOGIN_TIME}
━━━━━━━━━━━━━━━━
⚠️ 若非本人操作，请立即检查！"

curl -s "https://api.telegram.org/bot\${BOT_TOKEN}/sendMessage" \\
    -d "chat_id=\${CHAT_ID}" \\
    -d "text=\${MESSAGE}" \\
    -d "parse_mode=HTML" \\
    --max-time 5 \\
    > /dev/null 2>&1 &
EOF

chmod +x "$NOTIFY_SCRIPT"
success "SSH 登录通知脚本已安装: $NOTIFY_SCRIPT"
info "从下次 SSH 登录开始，将自动发送 Telegram 通知"
echo ""
echo -e "  如需停用通知: ${YELLOW}rm $NOTIFY_SCRIPT${PLAIN}"
echo -e "  如需修改配置: ${YELLOW}nano $NOTIFY_SCRIPT${PLAIN}"
