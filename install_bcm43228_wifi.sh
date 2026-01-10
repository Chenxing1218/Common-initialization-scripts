#!/bin/bash

# =============================================
# 飞牛 OS (fnOS) Broadcom BCM43228 无线网卡一键安装脚本
# 作者: Qwen (Alibaba)
# 适用系统: 基于 Debian 的 fnOS（需能联网）
# 功能: 自动安装固件、加载驱动、设置开机自启
# =============================================

set -e  # 遇错即停

echo "🚀 开始安装 Broadcom BCM43228 无线网卡驱动..."

# 检查是否为 root 或使用 sudo
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  请使用 sudo 运行此脚本！"
  echo "用法: sudo ./install_bcm43228_wifi.sh"
  exit 1
fi

# 1. 更新 apt 源
echo "🔄 正在更新软件源..."
apt update -y

# 2. 安装 b43 固件
echo "📥 正在安装 firmware-b43-installer..."
apt install -y firmware-b43-installer

# 3. 卸载可能冲突的模块
echo "🧹 卸载冲突驱动（如有）..."
modprobe -r b43 bcma wl 2>/dev/null || true

# 4. 加载 b43 驱动
echo "🔌 加载 b43 驱动..."
modprobe b43

# 5. 确保 b43 开机自启
if ! grep -q "^b43$" /etc/modules; then
  echo "b43" >> /etc/modules
  echo "✅ 已将 b43 添加到 /etc/modules（开机自启）"
else
  echo "ℹ️  b43 已在 /etc/modules 中，跳过添加"
fi

# 6. 屏蔽 bcma 驱动（防止冲突）
BLACKLIST_FILE="/etc/modprobe.d/blacklist-bcm43.conf"
if [ ! -f "$BLACKLIST_FILE" ]; then
  echo "blacklist bcma" > "$BLACKLIST_FILE"
  echo "blacklist brcmsmac" >> "$BLACKLIST_FILE"
  echo "✅ 已创建黑名单文件：$BLACKLIST_FILE"
else
  echo "ℹ️  黑名单文件已存在，跳过创建"
fi

# 7. 更新 initramfs
echo "🔄 正在更新 initramfs..."
update-initramfs -u

# 8. 验证
if lsmod | grep -q "^b43 "; then
  echo "🎉 驱动加载成功！无线网卡应已可用。"
  echo "💡 请前往飞牛 Web 界面 -> 网络 -> 无线网卡 进行连接。"
else
  echo "❌ 驱动未加载成功，请检查日志。"
  dmesg | grep -i b43
  exit 1
fi

echo "✅ 脚本执行完毕！重启后驱动将自动生效。"
