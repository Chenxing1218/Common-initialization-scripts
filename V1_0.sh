#!/bin/bash

# 检查是否为root用户或使用sudo运行
if [ "$(id -u)" -ne 0 ]; then
    echo "此脚本需要以root权限运行，请使用sudo或切换至root用户。"
    exit 1
fi

# 设置颜色代码用于输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 函数：打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 1. 系统更新
print_message "${YELLOW}" "\n开始系统更新..."
apt update -y || {
    print_message "${RED}" "系统更新失败！"
    exit 1
}
print_message "${GREEN}" "系统更新完成。"

# 2. 安装Docker
print_message "${YELLOW}" "\n开始安装Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh || {
    print_message "${RED}" "下载Docker安装脚本失败！"
    exit 1
}

sh get-docker.sh || {
    print_message "${RED}" "Docker安装失败！"
    rm -f get-docker.sh
    exit 1
}
rm -f get-docker.sh
print_message "${GREEN}" "Docker安装完成。"

# 3. 启动Docker服务
print_message "${YELLOW}" "\n启动Docker服务..."
systemctl start docker || {
    print_message "${RED}" "启动Docker服务失败！"
    exit 1
}
systemctl enable docker || {
    print_message "${RED}" "设置Docker开机启动失败！"
    exit 1
}
print_message "${GREEN}" "Docker服务已启动并设置为开机启动。"

# 4. 安装Docker Compose
print_message "${YELLOW}" "\n安装Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || {
    print_message "${RED}" "下载Docker Compose失败！"
    exit 1
}

chmod +x /usr/local/bin/docker-compose || {
    print_message "${RED}" "设置Docker Compose执行权限失败！"
    exit 1
}
print_message "${GREEN}" "Docker Compose安装完成。"

# 验证安装
print_message "${YELLOW}" "\n验证安装..."
docker --version
docker-compose --version

print_message "${GREEN}" "\n所有操作已完成！Docker和Docker Compose已成功安装。"
