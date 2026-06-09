#!/bin/bash
# ============================================================
#  一键设置强密码脚本
#  功能：生成 15-20 位随机强密码并自动修改当前用户密码
#  字符集：大小写字母 + 数字 + 简洁符号（! @ # $ % & *）
# ============================================================

set -euo pipefail

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------- 生成密码 ----------
generate_password() {
    local charset='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%&*'
    local length=$(( RANDOM % 6 + 15 ))   # 15 ~ 20 位

    # 用 /dev/urandom 保证随机性
    local password
    password=$(cat /dev/urandom | tr -dc "$charset" | head -c "$length")
    echo "$password"
}

# ---------- 校验密码强度（至少包含四类字符） ----------
validate_password() {
    local pwd="$1"
    local has_upper has_lower has_digit has_symbol
    has_upper=$(echo "$pwd" | grep -c '[A-Z]' || true)
    has_lower=$(echo "$pwd" | grep -c '[a-z]' || true)
    has_digit=$(echo "$pwd" | grep -c '[0-9]' || true)
    has_symbol=$(echo "$pwd" | grep -c '[^A-Za-z0-9]' || true)

    if [[ $has_upper -ge 1 && $has_lower -ge 1 && $has_digit -ge 1 && $has_symbol -ge 1 ]]; then
        return 0
    fi
    return 1
}

# ---------- 生成一个通过校验的密码 ----------
get_strong_password() {
    local pwd
    while true; do
        pwd=$(generate_password)
        if validate_password "$pwd"; then
            echo "$pwd"
            return
        fi
    done
}

# ---------- 主流程 ----------
main() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║        🔐  一键强密码设置工具            ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
    echo ""

    # 获取当前用户
    CURRENT_USER=$(whoami)
    echo -e "  当前用户：${BOLD}${CURRENT_USER}${RESET}"
    echo ""

    # 生成强密码
    echo -e "  ${YELLOW}⚙  正在生成强密码...${RESET}"
    NEW_PASSWORD=$(get_strong_password)
    PASSWORD_LENGTH=${#NEW_PASSWORD}
    echo -e "  ${GREEN}✔  密码已生成（${PASSWORD_LENGTH} 位）${RESET}"
    echo ""

    # 确认是否继续
    echo -e "  ${YELLOW}⚠  即将修改用户 [${BOLD}${CURRENT_USER}${RESET}${YELLOW}] 的登录密码，是否继续？${RESET}"
    echo -ne "  输入 ${BOLD}yes${RESET} 确认，其他任意键取消：${BOLD}"
    read -r CONFIRM
    echo -e "${RESET}"

    if [[ "$CONFIRM" != "yes" ]]; then
        echo -e "  ${RED}✘  已取消，密码未修改。${RESET}"
        echo ""
        exit 0
    fi

    # 修改密码
    echo -e "  ${YELLOW}⚙  正在修改密码...${RESET}"

    if echo "${CURRENT_USER}:${NEW_PASSWORD}" | sudo chpasswd 2>/dev/null; then
        CHANGE_OK=true
    elif echo "${NEW_PASSWORD}" | passwd --stdin "${CURRENT_USER}" 2>/dev/null; then
        CHANGE_OK=true
    else
        # 兜底：尝试直接调用 chpasswd（需要 root）
        echo -e "  ${RED}✘  自动修改失败（权限不足）。${RESET}"
        echo -e "     请手动执行以下命令（以 root 身份）："
        echo ""
        echo -e "     ${BOLD}echo '${CURRENT_USER}:${NEW_PASSWORD}' | sudo chpasswd${RESET}"
        echo ""
        CHANGE_OK=false
    fi

    # ---------- 打印结果 ----------
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
    if [[ "${CHANGE_OK}" == true ]]; then
        echo -e "${CYAN}${BOLD}║           ✅  密码修改成功！              ║${RESET}"
    else
        echo -e "${CYAN}${BOLD}║       ⚠  密码未自动修改，请见上方提示    ║${RESET}"
    fi
    echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}  用户名 ：${BOLD}${CURRENT_USER}${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}  新密码 ：${BOLD}${GREEN}${NEW_PASSWORD}${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}  位  数 ：${BOLD}${PASSWORD_LENGTH} 位${RESET}"
    echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}  ${YELLOW}👆 请立即复制上方密码并保存到安全位置！${RESET}  ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
    echo ""

    # 尝试自动复制到剪贴板
    if command -v xclip &>/dev/null; then
        echo -n "$NEW_PASSWORD" | xclip -selection clipboard
        echo -e "  ${GREEN}📋  密码已自动复制到剪贴板（xclip）${RESET}"
    elif command -v xsel &>/dev/null; then
        echo -n "$NEW_PASSWORD" | xsel --clipboard --input
        echo -e "  ${GREEN}📋  密码已自动复制到剪贴板（xsel）${RESET}"
    elif command -v pbcopy &>/dev/null; then
        echo -n "$NEW_PASSWORD" | pbcopy
        echo -e "  ${GREEN}📋  密码已自动复制到剪贴板（pbcopy）${RESET}"
    else
        echo -e "  ${YELLOW}💡  未检测到剪贴板工具，请手动选中上方密码复制。${RESET}"
        echo -e "     可安装：${BOLD}sudo apt install xclip${RESET}  或  ${BOLD}sudo yum install xclip${RESET}"
    fi

    echo ""

    # 安全提示：密码不写入任何日志文件
    echo -e "  ${YELLOW}🔒  安全提示：本脚本不会将密码写入任何日志或文件。${RESET}"
    echo ""
}

main "$@"
