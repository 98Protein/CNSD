# =============================================================================
# 银河麒麟桌面操作系统 V10 SP1 离线包下载容器
#
# 重要说明:
#   银河麒麟桌面 V10 SP1 是基于 Ubuntu 20.04 (focal) 二次发行的 apt/deb 系系统
#   （/etc/os-release 里 ID_LIKE=debian、UBUNTU_CODENAME=kylin、PROJECT_CODENAME=V10SP1）。
#   公开社区没有麒麟桌面版的 Docker 基础镜像，所以用 ubuntu:20.04 + 麒麟官方
#   apt 源作为下载环境。这样下载到的 .deb 与真实麒麟桌面 V10 SP1 完全一致，
#   产物拷到真实麒麟机器上可直接 dpkg -i / apt install。
#
#   注意: 跟服务器版（Kylin Linux Advanced Server V10）完全是两个产品 ——
#   服务器版是 dnf/rpm 系（基于 CentOS 8），桌面版是 apt/deb 系（基于 Ubuntu 20.04）。
# =============================================================================
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# 先用 Ubuntu 默认源装基础工具，再换麒麟源
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        apt-utils \
        dpkg-dev \
    && rm -rf /var/lib/apt/lists/*

# 替换为麒麟官方 apt 源
RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*.list
COPY sources.list /etc/apt/sources.list

# 启用 arm64 多架构支持
RUN dpkg --add-architecture arm64

# 拷入下载脚本
COPY download.sh /usr/local/bin/download.sh
RUN chmod +x /usr/local/bin/download.sh

# 默认输出目录（建议从宿主机挂载到这里持久化下载产物）
WORKDIR /downloads

CMD ["/bin/bash"]
