# =============================================================================
# 统信 UOS 桌面专业版 V20 离线包下载容器（带授权降级）
#
# 工作模式（由 entrypoint 决定）:
#   1. 完整模式：检测到 /host-uos-auth/uos.conf 时启用，UOS 官方源 + Debian 兜底
#                 → 能下专有包(dde-/deepin-/uos-) + 通用包
#   2. 兜底模式：未检测到授权文件，仅启用 Debian 10 buster archive
#                 → 只能下通用包
#   3. 自动降级：启动是完整模式，但 download.sh 首次 apt update 收到 401 时，
#                 自动切回兜底模式（authorization 被服务端拒绝）
#
# 基础镜像选 debian:10-slim 的原因：
#   UOS 桌面专业版本质是 Deepin v20 (基于 Debian 10 buster + DDE) 的商业化分支，
#   下到的 .deb 与真实 UOS 桌面机器一致，可直接 dpkg -i 装到目标机器。
# =============================================================================
FROM debian:10-slim

ENV DEBIAN_FRONTEND=noninteractive

# Debian 10 (buster) 已 EOL，archive 不再更新签名时间戳，关闭 Valid-Until 校验
RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

# 先用容器自带的 Debian 默认源装基础工具（这一步在 sources.list 还没换前完成）
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        apt-utils \
        dpkg-dev \
    && rm -rf /var/lib/apt/lists/*

# 拷入两份 sources.list 模板（entrypoint 按需选择）
COPY sources.list.uos-full     /etc/apt/sources.list.uos-full
COPY sources.list.debian-only  /etc/apt/sources.list.debian-only

# 启用 arm64 多架构支持
RUN dpkg --add-architecture arm64

# UOS 桌面身份铭牌
COPY uos-os-version /etc/os-version

# 提前创建授权目录（entrypoint 会写入）
RUN mkdir -p /etc/apt/auth.conf.d

# 拷入入口脚本与下载脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY download.sh   /usr/local/bin/download.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/download.sh

WORKDIR /downloads

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
