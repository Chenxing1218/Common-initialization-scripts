#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
CONTAINER_NAME="cloudreve"
WEB_PORT="7777"
BT_PORT="6888"
DATA_DIR="/opt/cloudreve/data"
CONFIG_DIR="/opt/cloudreve/config"

# 显示菜单
show_menu() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}    Cloudreve BT网盘管理脚本    ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "1) ${GREEN}安装 Cloudreve (含BT功能)${NC}"
    echo -e "2) ${RED}彻底删除 Cloudreve${NC}"
    echo -e "3) ${YELLOW}检查运行状态${NC}"
    echo -e "4) ${BLUE}检查是否彻底卸载${NC}"
    echo -e "5) ${GREEN}重启服务${NC}"
    echo -e "6) ${YELLOW}查看日志${NC}"
    echo -e "0) 退出"
    echo -e "${BLUE}================================${NC}"
}

# 安装函数
install_cloudreve() {
    echo -e "${GREEN}[INFO] 开始安装 Cloudreve (含BT功能)...${NC}"
    
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}[ERROR] Docker 未安装，请先安装Docker${NC}"
        exit 1
    fi
    
    # 检查端口是否被占用
    if ss -tlnp | grep -q ":${WEB_PORT} "; then
        echo -e "${RED}[ERROR] 端口 ${WEB_PORT} 已被占用${NC}"
        exit 1
    fi
    
    if ss -tlnp | grep -q ":${BT_PORT} "; then
        echo -e "${RED}[ERROR] 端口 ${BT_PORT} 已被占用${NC}"
        exit 1
    fi
    
    # 创建目录
    echo -e "${YELLOW}[INFO] 创建数据目录...${NC}"
    sudo mkdir -p "${DATA_DIR}"
    sudo mkdir -p "${CONFIG_DIR}"
    sudo chown -R $USER:$USER /opt/cloudreve
    
    # 停止已存在的容器
    if docker ps -a | grep -q "${CONTAINER_NAME}"; then
        echo -e "${YELLOW}[INFO] 停止已存在的容器...${NC}"
        docker stop "${CONTAINER_NAME}" >/dev/null 2>&1
        docker rm "${CONTAINER_NAME}" >/dev/null 2>&1
    fi
    
    # 拉取最新镜像
    echo -e "${YELLOW}[INFO] 拉取 Docker 镜像...${NC}"
    docker pull cloudreve/cloudreve:latest
    
    # 运行容器（包含BT功能）
    echo -e "${YELLOW}[INFO] 启动 Cloudreve 容器...${NC}"
    docker run -d --name "${CONTAINER_NAME}" \
        -p "${WEB_PORT}:5212" \
        -p "${BT_PORT}:6888" \
        -p "${BT_PORT}:6888/udp" \
        -v "${DATA_DIR}:/cloudreve/data" \
        -v "${CONFIG_DIR}:/cloudreve/conf" \
        -v "/:/cloudreve/files" \
        --restart unless-stopped \
        cloudreve/cloudreve:latest
    
    # 等待启动
    echo -e "${YELLOW}[INFO] 等待服务启动...${NC}"
    for i in {1..30}; do
        if curl -s http://localhost:${WEB_PORT} >/dev/null 2>&1; then
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""
    
    # 显示安装信息
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}     Cloudreve 安装完成!        ${NC}"
    echo -e "${GREEN}================================${NC}"
    echo -e "🌐 ${BLUE}访问地址:${NC} http://$(curl -s ifconfig.me):${WEB_PORT}"
    echo -e "📡 ${BLUE}BT下载端口:${NC} ${BT_PORT} (TCP/UDP)"
    echo -e "💾 ${BLUE}数据目录:${NC} ${DATA_DIR}"
    echo -e "⚙️  ${BLUE}配置目录:${NC} ${CONFIG_DIR}"
    echo -e ""
    echo -e "${YELLOW}初始管理员账号密码:${NC}"
    docker logs "${CONTAINER_NAME}" 2>&1 | grep -E "初始管理员账号|password|Password" | head -5
    
    echo -e ""
    echo -e "${GREEN}✅ 安装成功！请在浏览器中访问上述地址${NC}"
}

# 彻底删除函数
uninstall_cloudreve() {
    echo -e "${YELLOW}[INFO] 开始彻底删除 Cloudreve...${NC}"
    
    # 停止并删除容器
    if docker ps -a | grep -q "${CONTAINER_NAME}"; then
        echo -e "${YELLOW}[INFO] 停止并删除容器...${NC}"
        docker stop "${CONTAINER_NAME}" >/dev/null 2>&1
        docker rm "${CONTAINER_NAME}" >/dev/null 2>&1
        echo -e "${GREEN}✅ 容器已删除${NC}"
    else
        echo -e "${BLUE}[INFO] 未找到 Cloudreve 容器${NC}"
    fi
    
    # 删除镜像
    if docker images | grep -q "cloudreve/cloudreve"; then
        echo -e "${YELLOW}[INFO] 删除 Docker 镜像...${NC}"
        docker rmi cloudreve/cloudreve:latest >/dev/null 2>&1
        echo -e "${GREEN}✅ 镜像已删除${NC}"
    fi
    
    # 询问是否删除数据
    echo -e "${YELLOW}是否删除数据目录？${NC}"
    echo -e "   - ${DATA_DIR}"
    echo -e "   - ${CONFIG_DIR}"
    read -p "请输入选择 (y/N): " delete_choice
    
    if [[ $delete_choice == "y" || $delete_choice == "Y" ]]; then
        if [ -d "/opt/cloudreve" ]; then
            echo -e "${YELLOW}[INFO] 删除数据目录...${NC}"
            sudo rm -rf /opt/cloudreve
            echo -e "${GREEN}✅ 数据目录已删除${NC}"
        else
            echo -e "${BLUE}[INFO] 数据目录不存在${NC}"
        fi
    else
        echo -e "${BLUE}[INFO] 数据目录保留在 /opt/cloudreve${NC}"
    fi
    
    # 清理Docker
    echo -e "${YELLOW}[INFO] 清理Docker系统...${NC}"
    docker system prune -f >/dev/null 2>&1
    
    echo -e "${GREEN}✅ Cloudreve 已彻底删除${NC}"
}

# 检查状态函数
check_status() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}        Cloudreve 状态检查       ${NC}"
    echo -e "${BLUE}================================${NC}"
    
    # 检查容器状态
    echo -e "${YELLOW}1. 容器状态:${NC}"
    if docker ps | grep -q "${CONTAINER_NAME}"; then
        echo -e "   ${GREEN}✅ 运行中${NC}"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "${CONTAINER_NAME}"
    else
        echo -e "   ${RED}❌ 未运行${NC}"
    fi
    
    # 检查端口监听
    echo -e "${YELLOW}2. 端口监听:${NC}"
    if ss -tlnp | grep -q ":${WEB_PORT} "; then
        echo -e "   ${GREEN}✅ Web端口 ${WEB_PORT} 监听中${NC}"
    else
        echo -e "   ${RED}❌ Web端口 ${WEB_PORT} 未监听${NC}"
    fi
    
    if ss -tlnp | grep -q ":${BT_PORT} "; then
        echo -e "   ${GREEN}✅ BT端口 ${BT_PORT} (TCP) 监听中${NC}"
    else
        echo -e "   ${RED}❌ BT端口 ${BT_PORT} (TCP) 未监听${NC}"
    fi
    
    if ss -ulnp | grep -q ":${BT_PORT} "; then
        echo -e "   ${GREEN}✅ BT端口 ${BT_PORT} (UDP) 监听中${NC}"
    else
        echo -e "   ${RED}❌ BT端口 ${BT_PORT} (UDP) 未监听${NC}"
    fi
    
    # 检查服务可访问性
    echo -e "${YELLOW}3. 服务可访问性:${NC}"
    if curl -s http://localhost:${WEB_PORT} >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Web服务可访问${NC}"
    else
        echo -e "   ${RED}❌ Web服务不可访问${NC}"
    fi
    
    # 显示访问信息
    echo -e "${YELLOW}4. 访问信息:${NC}"
    echo -e "   ${BLUE}访问地址:${NC} http://$(curl -s ifconfig.me):${WEB_PORT}"
    echo -e "   ${BLUE}BT端口:${NC} ${BT_PORT}"
}

# 检查是否彻底卸载
check_uninstall() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}     彻底卸载检查       ${NC}"
    echo -e "${BLUE}================================${NC}"
    
    local completely_removed=true
    
    # 检查容器
    echo -e "${YELLOW}1. 容器检查:${NC}"
    if docker ps -a | grep -q "${CONTAINER_NAME}"; then
        echo -e "   ${RED}❌ 容器仍然存在${NC}"
        completely_removed=false
    else
        echo -e "   ${GREEN}✅ 容器已删除${NC}"
    fi
    
    # 检查镜像
    echo -e "${YELLOW}2. 镜像检查:${NC}"
    if docker images | grep -q "cloudreve/cloudreve"; then
        echo -e "   ${RED}❌ 镜像仍然存在${NC}"
        completely_removed=false
    else
        echo -e "   ${GREEN}✅ 镜像已删除${NC}"
    fi
    
    # 检查数据目录
    echo -e "${YELLOW}3. 数据目录检查:${NC}"
    if [ -d "/opt/cloudreve" ]; then
        echo -e "   ${YELLOW}⚠️  数据目录存在: /opt/cloudreve${NC}"
        echo -e "   ${BLUE}   如需删除请运行: sudo rm -rf /opt/cloudreve${NC}"
    else
        echo -e "   ${GREEN}✅ 数据目录已删除${NC}"
    fi
    
    # 检查端口占用
    echo -e "${YELLOW}4. 端口占用检查:${NC}"
    if ss -tlnp | grep -q ":${WEB_PORT} "; then
        echo -e "   ${RED}❌ 端口 ${WEB_PORT} 仍被占用${NC}"
        completely_removed=false
    else
        echo -e "   ${GREEN}✅ 端口 ${WEB_PORT} 空闲${NC}"
    fi
    
    if ss -tlnp | grep -q ":${BT_PORT} "; then
        echo -e "   ${RED}❌ 端口 ${BT_PORT} 仍被占用${NC}"
        completely_removed=false
    else
        echo -e "   ${GREEN}✅ 端口 ${BT_PORT} 空闲${NC}"
    fi
    
    # 总结
    echo -e "${BLUE}================================${NC}"
    if $completely_removed && [ ! -d "/opt/cloudreve" ]; then
        echo -e "${GREEN}✅ Cloudreve 已彻底卸载${NC}"
    else
        echo -e "${YELLOW}⚠️  Cloudreve 未完全卸载${NC}"
        echo -e "${BLUE}请运行选项2进行彻底删除${NC}"
    fi
}

# 重启服务
restart_service() {
    echo -e "${YELLOW}[INFO] 重启 Cloudreve 服务...${NC}"
    
    if docker ps | grep -q "${CONTAINER_NAME}"; then
        docker restart "${CONTAINER_NAME}"
        echo -e "${GREEN}✅ 服务重启完成${NC}"
        
        # 等待重启
        echo -e "${YELLOW}[INFO] 等待服务恢复...${NC}"
        sleep 5
        check_status
    else
        echo -e "${RED}❌ Cloudreve 未运行，请先安装${NC}"
    fi
}

# 查看日志
view_logs() {
    echo -e "${YELLOW}[INFO] 显示 Cloudreve 日志 (最后50行)...${NC}"
    
    if docker ps | grep -q "${CONTAINER_NAME}"; then
        docker logs "${CONTAINER_NAME}" --tail 50
        echo -e "${GREEN}--------------------------------${NC}"
        echo -e "输入 'q' 退出日志查看"
        read -p "按回车键继续查看实时日志，或输入q退出: " choice
        if [[ $choice != "q" ]]; then
            echo -e "${YELLOW}[INFO] 开始实时日志 (Ctrl+C 退出)...${NC}"
            docker logs "${CONTAINER_NAME}" -f
        fi
    else
        echo -e "${RED}❌ Cloudreve 未运行${NC}"
    fi
}

# 主程序
main() {
    while true; do
        show_menu
        read -p "请输入选择 [0-6]: " choice
        
        case $choice in
            1)
                install_cloudreve
                ;;
            2)
                uninstall_cloudreve
                ;;
            3)
                check_status
                ;;
            4)
                check_uninstall
                ;;
            5)
                restart_service
                ;;
            6)
                view_logs
                ;;
            0)
                echo -e "${GREEN}再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
        clear
    done
}

# 脚本入口
clear
echo -e "${GREEN}Cloudreve BT网盘管理脚本启动...${NC}"
main
