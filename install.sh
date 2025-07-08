#!/bin/sh
set -e

# 默认参数
PORT=1080
USER=""
PASSWD=""

# 解析命令行参数
for i in "$@"; do
    case $i in
        --port=*)
            PORT="${i#*=}"
            ;;
        --user=*)
            USER="${i#*=}"
            ;;
        --passwd=*)
            PASSWD="${i#*=}"
            ;;
        *)
            echo "未知参数: $i"
            exit 1
            ;;
    esac
done

# 检查必须参数
if [ -z "$USER" ] || [ -z "$PASSWD" ]; then
    echo "用法: $0 --port=端口 --user=用户名 --passwd=密码"
    exit 1
fi

echo "=> 正在更新系统包..."
apk update

echo "=> 安装 dante-server..."
apk add dante-server

echo "=> 配置 /etc/sockd.conf..."

cat > /etc/sockd.conf <<EOF
logoutput: stdout syslog /var/log/sockd.log

# 全局声明允许的 socks 认证方式
socksmethod: username none

# 内部接口和端口
internal: 0.0.0.0 port = $PORT
external: eth0

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    socksmethod: username
    log: connect disconnect error
}
EOF

echo "=> 创建用户 $USER..."
adduser -H -s /sbin/nologin $USER
echo "$USER:$PASSWD" | chpasswd

# 禁用密码复杂度限制（避免交互式输入）
sed -i 's/^password.*/password    sufficient    pam_unix.so/' /etc/pam.d/passwd

echo "=> 设置 sockd 开机启动..."
rc-update add sockd default
rc-service sockd start

echo "=> 重启 sockd 服务..."
rc-service sockd restart

echo "✅ SOCKS5 代理部署完成！"
echo "IP 地址: $(hostname -I | awk '{print $1}')"
echo "端口: $PORT"
echo "用户名: $USER"
echo "密码: $PASSWD"
