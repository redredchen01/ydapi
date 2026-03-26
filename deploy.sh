#!/bin/bash
# YDAPI 一键部署脚本
# 用法: scp 整个目录到 VPS 后执行 bash deploy.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "========================================="
echo "  YDAPI 部署脚本"
echo "========================================="

# 检查 Docker
if ! command -v docker &>/dev/null; then
    echo -e "${RED}Docker 未安装，正在安装...${NC}"
    DOCKER_SCRIPT=$(mktemp)
    curl -fsSL https://get.docker.com -o "$DOCKER_SCRIPT"
    echo "Downloaded Docker install script to $DOCKER_SCRIPT"
    echo "Please review before running: less $DOCKER_SCRIPT"
    read -p "Install Docker now? [y/N] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sh "$DOCKER_SCRIPT"
        systemctl enable docker
        systemctl start docker
    else
        echo "Aborted. Install Docker manually and re-run."
        rm -f "$DOCKER_SCRIPT"
        exit 1
    fi
    rm -f "$DOCKER_SCRIPT"
fi

if ! docker compose version &>/dev/null; then
    echo -e "${RED}Docker Compose 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}Docker 就绪${NC}"

# 启动服务
echo "正在启动 YDAPI..."
docker compose up -d

echo ""
echo "========================================="
echo -e "${GREEN}  YDAPI 部署完成！${NC}"
echo "========================================="
echo ""
echo "管理后台: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'YOUR_SERVER_IP'):8080"
echo ""
echo "首次启动请查看日志获取管理员密码:"
echo "  docker compose logs ydapi | grep password"
echo ""
echo "常用命令:"
echo "  docker compose logs -f ydapi  # 查看日志"
echo "  docker compose restart ydapi  # 重启服务"
echo "  docker compose down             # 停止服务"
echo "  docker compose pull && docker compose up -d  # 升级"
