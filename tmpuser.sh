#!/bin/bash
# ============================================================
#  临时 sudo 用户脚本
#  功能：创建临时用户，密码带毫秒时间戳+随机10位，到期后自动删除
# ============================================================

set -euo pipefail

# ---------- 颜色定义 ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

USER="tmproot"

# 毫秒时间戳
MS=$(date +%s%3N)

# 随机 10 位英文+数字
RAND=$(cat /dev/urandom | tr -dc 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789' | head -c 10)

PASS="Tmp@${MS}@${RAND}"

clear
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║        🔑  临时用户创建工具              ║${RESET}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""

# ---------- 检查 root 权限 ----------
if [[ $EUID -ne 0 ]]; then
    echo -e "  ${RED}✘  请用 sudo 运行此脚本${RESET}"
    echo -e "     ${BOLD}sudo bash tmpuser.sh${RESET}"
    exit 1
fi

# ---------- 提示输入有效小时数 ----------
echo -ne "  请输入临时用户有效时长（小时），直接回车默认 24 小时：${BOLD}"
read -r INPUT_EXPIRE
echo -e "${RESET}"

# 校验是否为正整数，否则用默认值
if [[ "$INPUT_EXPIRE" =~ ^[1-9][0-9]*$ ]]; then
    EXPIRE=$INPUT_EXPIRE
else
    EXPIRE=24
    echo -e "  ${YELLOW}⚙  未输入有效数字，使用默认 24 小时${RESET}"
    echo ""
fi

# ---------- 检查并安装 at ----------
if ! command -v at &>/dev/null; then
    echo -e "  ${YELLOW}⚙  正在安装 at 定时工具...${RESET}"
    apt install at -y 2>/dev/null || yum install at -y 2>/dev/null || true
    systemctl enable atd && systemctl start atd 2>/dev/null || true
fi

# ---------- 如果用户已存在先清理 ----------
if id "$USER" &>/dev/null; then
    echo -e "  ${YELLOW}⚙  检测到旧用户，正在清理...${RESET}"
    userdel -r "$USER" 2>/dev/null || true
fi

# ---------- 创建用户 ----------
useradd -m -G sudo "$USER" 2>/dev/null || useradd -m -G wheel "$USER"
echo "$USER:$PASS" | chpasswd

# ---------- 定时删除 ----------
echo "userdel -r $USER" | at now + ${EXPIRE} hour 2>/dev/null

# ---------- 打印结果 ----------
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║           ✅  临时用户创建成功！          ║${RESET}"
echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}  用户名 ：${BOLD}${USER}${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}  密  码 ：${BOLD}${GREEN}${PASS}${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}  有效期 ：${BOLD}${EXPIRE} 小时后自动删除${RESET}"
echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}  ${YELLOW}👆 请立即复制上方密码并发送给对方${RESET}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${YELLOW}💡  用完立即手动删除：${BOLD}userdel -r ${USER}${RESET}"
echo ""
