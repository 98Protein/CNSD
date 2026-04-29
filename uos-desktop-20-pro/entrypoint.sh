#!/bin/bash
# ----------------------------------------------------------------------------
# 容器启动时的模式选择:
#   - 检测到挂载的授权文件 (/host-uos-auth/uos.conf) 且非空 → 启用完整模式
#   - 否则 → 启用 Debian 兜底模式（只能下通用包）
#
# 注意: 即便启动时是完整模式，download.sh 第一次 apt update 若收到 401
# 仍会自动再降级到兜底模式 —— 所以本 entrypoint 只是给容器一个"初始倾向"。
# ----------------------------------------------------------------------------
set -e

AUTH_SRC="/host-uos-auth/uos.conf"
AUTH_DST="/etc/apt/auth.conf.d/uos.conf"

if [ -s "$AUTH_SRC" ]; then
    install -m 600 "$AUTH_SRC" "$AUTH_DST"
    cp /etc/apt/sources.list.uos-full /etc/apt/sources.list
    echo "[entrypoint] 已加载 UOS 授权文件，启用完整模式"
    echo "[entrypoint]   - UOS 桌面源（专有包：dde-/deepin-/uos-）"
    echo "[entrypoint]   - Debian buster archive（通用包兜底）"
else
    cp /etc/apt/sources.list.debian-only /etc/apt/sources.list
    echo "[entrypoint] 未检测到 UOS 授权文件，启用兜底模式（仅 Debian buster archive）"
    echo "[entrypoint] 此模式只能下载通用包；如需 UOS 桌面专有包，请先放置授权文件并重启容器"
fi

exec "$@"
