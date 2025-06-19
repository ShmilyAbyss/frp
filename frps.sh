#!/bin/bash
# 自定义frp安装脚本 (保存为 install_frp.sh)
set -e

# 交互式配置函数
configure_frp() {
    echo "┌──────────────────────────────────────────┐"
    echo "│          FRP 服务配置向导                │"
    echo "└──────────────────────────────────────────┘"
    
    # 设置默认值
    local DEFAULT_BIND_PORT=7000
    local DEFAULT_TOKEN=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)
    local DEFAULT_DASHBOARD_PORT=7500
    
    # 获取用户输入
    read -p "► 输入FRP服务端口 [$DEFAULT_BIND_PORT]: " BIND_PORT
    BIND_PORT=${BIND_PORT:-$DEFAULT_BIND_PORT}
    
    read -p "► 输入认证Token(建议随机) [$DEFAULT_TOKEN]: " TOKEN
    TOKEN=${TOKEN:-$DEFAULT_TOKEN}
    
    read -p "► 启用Web控制台? (y/n) [y]: " ENABLE_DASHBOARD
    ENABLE_DASHBOARD=${ENABLE_DASHBOARD:-y}
    
    if [[ $ENABLE_DASHBOARD =~ ^[Yy]$ ]]; then
        read -p "► 输入控制台端口 [$DEFAULT_DASHBOARD_PORT]: " DASHBOARD_PORT
        DASHBOARD_PORT=${DASHBOARD_PORT:-$DEFAULT_DASHBOARD_PORT}
        
        read -p "► 输入控制台用户名 [admin]: " DASHBOARD_USER
        DASHBOARD_USER=${DASHBOARD_USER:-admin}
        
        read -p "► 输入控制台密码: " DASHBOARD_PWD
        while [ -z "$DASHBOARD_PWD" ]; do
            echo "✗ 密码不能为空!"
            read -p "► 输入控制台密码: " DASHBOARD_PWD
        done
    else
        DASHBOARD_PORT=""
    fi

    # 生成TOML配置文件
    sudo tee /usr/local/share/frp/frps.toml > /dev/null <<EOF
# FRP 服务器配置 (由安装脚本生成)
bindPort = $BIND_PORT
auth.token = "$TOKEN"

# Web控制台配置
EOF

    if [ -n "$DASHBOARD_PORT" ]; then
        sudo tee -a /usr/local/share/frp/frps.toml > /dev/null <<EOF
webServer.addr = "0.0.0.0"
webServer.port = $DASHBOARD_PORT
webServer.user = "$DASHBOARD_USER"
webServer.password = "$DASHBOARD_PWD"
EOF
    fi

    echo -e "\n✔ 配置文件已生成: /usr/local/share/frp/frps.toml"
}

# 主安装流程
echo "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
echo "█ 开始安装自定义 FRP 服务"
echo "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"

# 创建安装目录
sudo mkdir -p /usr/local/share/frp

TARGET_ARCH="amd64"
echo "► 下载 FRP 文件..."
# 2. 下载特定文件夹
# 格式: https://github.com/<用户名>/<仓库名>/trunk/<文件夹路径>
git clone https://github.com/ShmilyAbyss/frp.git /usr/local/share/frp
echo "✓ 下载完成"

# 运行交互式配置
configure_frp

echo "► 创建 systemd 服务..."
sudo tee /etc/systemd/system/frps.service > /dev/null <<EOF
[Unit]
Description=Frp Server
After=network.target

[Service]
ExecStart=cd /usr/local/share/frp ./frps -c /usr/local/share/frp/frps.toml
Restart=on-failure
RestartSec=5s
User=root
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

echo "✓ 服务文件已创建"

echo "► 启用服务..."
sudo systemctl daemon-reload
sudo systemctl enable frps --now

echo "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
echo "█ 安装完成!"
echo "█ 服务状态: sudo systemctl status frps"
echo "█ 配置文件: /usr/local/share/frps.toml"

if grep -q "webServer.port" /usr/local/share/frps.toml; then
    DASH_PORT=$(grep "webServer.port" /usr/local/share/frps.toml | awk -F'=' '{print $2}' | tr -d ' ')
    echo "█ 控制台地址: http://$(curl -s ifconfig.me):$DASH_PORT"
fi
echo "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"