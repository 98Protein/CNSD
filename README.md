# CNSD
> CNSD 为 China System Software Downloader 缩写，即国产操作系统软件包下载器
## 简介

用于离线下载常用国产系统**银河麒麟V10** **统信UOS20**  `.deb` 包的精简 Docker 容器：


| 容器                              | 基础镜像                  | 目标系统                | 包来源                                                  |
| --------------------------------- | ------------------------- | ----------------------- | ------------------------------------------------------- |
| `kylin-desktop-v10sp1-downloader` | `ubuntu:20.04` *(模拟)*   | 银河麒麟桌面 V10 SP1    | `archive2.kylinos.cn` 麒麟官方仓库                      |
| `uos-desktop-20-pro-downloader`   | `debian:10-slim` *(模拟)* | 统信 UOS 桌面专业版 V20 | UOS 官方仓库（可选授权）+ Debian 10 buster archive 兜底 |


每个容器都能在同一台 x86/arm 宿主机上下载 `amd64` **和** `arm64` 两种架构的包。

---

## 项目结构

```
CNSD/
├── kylin-desktop-v10sp1/
│   ├── Dockerfile
│   ├── sources.list                    # 麒麟官方 apt 源（amd64 + arm64 各一条）
│   └── download.sh						# 双架构包下载脚本
├── uos-desktop-20-pro/
│   ├── Dockerfile                      # 含 ENTRYPOINT，自动选择模式
│   ├── entrypoint.sh                   # 启动时检测授权文件并选择模式
│   ├── sources.list.uos-full           # 完整模式模板（UOS + Debian 兜底）
│   ├── sources.list.debian-only        # 兜底模式模板（仅 Debian buster）
│   ├── uos-os-version                  # UOS 桌面身份铭牌
│   ├── uos-auth/
│   │   ├── README.md                   # UOS 授权文件导出教程
│   │   └── uos.conf                    # UOS 授权文件，不放也能跑
│   └── download.sh                     # 双架构包下载脚本，授权 401 切换兜底模式
├── docker-compose.yml
├── .gitignore                          # git 提交过滤配置
└── output/                             # 下载产物挂载点（自动生成）
    ├── kylin-desktop-v10sp1/
    └── uos-desktop-20-pro/
```

---

## 项目原理

### 基础镜像选择

两个目标系统都没有公开的 ==桌面版== Docker 基础镜像，所以用「等价 Linux 发行版作为基础镜像 + 各自官方源」模拟：

- 银河麒麟桌面 V10 SP1 基于 Ubuntu 20.04 (focal)，`glibc>=2.31` `linux kernel>=5.4` 。
- UOS 桌面专业版 V20 基于 Debian 10 buster，`glibc>=2.28` `linux kernel>=4.19`。

下载到的 `.deb` 跟真实系统上 `apt-get download` 拉到的完全一致，可直接在目标系统上执行`dpkg -i` 进行安装。

### 多架构（两个容器共通）

1. `dpkg --add-architecture arm64` 让 apt 知道有第二个架构。
2. sources.list 用 `[arch=amd64,arm64]`（UOS 容器）或两条独立 `deb [arch=...]`（麒麟容器，因麒麟源按架构分仓库）声明双架构。
3. 下载用 `apt-cache depends --recurse :<arch>` 解析 + `apt-get download <pkg>:<arch>` 单包拉取。

### UOS 授权机制处理

UOS 桌面专业版的官方源 `professional-packages.chinauos.com` 需要授权，未授权会返回 401。本项目设计了三级降级方案：


| 启动状态                                    | 模式                 | 能下载的包范围                               |
| ------------------------------------------- | -------------------- | -------------------------------------------- |
| 检测到 `uos-auth/uos.conf`，服务端接受      | 完整模式             | dde-/deepin-/uos- 等 UOS 专有包 **+** 通用包 |
| 检测到 `uos.conf`，但 `apt update` 收到 401 | 自动降级到兜底模式   | 仅通用包                                     |
| 没有放 `uos.conf`                           | 启动直接进入兜底模式 | 仅通用包                                     |

所以 **`uos-auth/uos.conf` 是可选的**，没有也能跑，只是下不到 UOS 桌面专有包。

详细的授权文件导出步骤见 [`uos-desktop-20-pro/uos-auth/README.md`](uos-desktop-20-pro/uos-auth/README.md)。

> **注意**：授权文件含授权机的硬件指纹（MAC、磁盘序列号），UOS 服务端可能校验来源。一般同一组织内可用，但若服务端拒绝，那就只能下载通用包，当前下载脚本已对授权 401 自动降级兜底处理。

---

## 启动

```bash
git clone git@github.com:98Protein/CNSD.git
cd CNSD
# 可选：把 UOS 授权文件放到 uos-desktop-20-pro/uos-auth 目录下
#      不放也行，只是 UOS 容器会直接进入兜底模式（只下载通用包）

docker compose up -d --build

# 看一下 UOS 容器进入的是哪个模式：
docker logs uos-desktop-20-pro-downloader | head -10
# 期待看到:
#   [entrypoint] 已加载 UOS 授权文件，启用完整模式
#   或
#   [entrypoint] 未检测到 UOS 授权文件，启用兜底模式（仅 Debian buster archive）
```

---

## 使用

```bash
# 下载包及其全部依赖
docker exec -it <docker name> download.sh <package> <arch>
```

### 银河麒麟桌面 V10 SP1（无需授权）

```bash
docker exec -it kylin-desktop-v10sp1-downloader download.sh nginx amd64
docker exec -it kylin-desktop-v10sp1-downloader download.sh nginx arm64
docker exec -it kylin-desktop-v10sp1-downloader download.sh ukui-control-center,ukui-panel arm64 ukui-arm
```

### 统信 UOS 桌面专业版 V20

**通用包（任意模式都能下）：**

```bash
docker exec -it uos-desktop-20-pro-downloader download.sh nginx amd64
docker exec -it uos-desktop-20-pro-downloader download.sh nginx arm64
docker exec -it uos-desktop-20-pro-downloader download.sh curl,wget,vim arm64 cli-tools-arm
```

**UOS 桌面专有包（需授权才能下）：**

```bash
docker exec -it uos-desktop-20-pro-downloader download.sh dde-control-center amd64
docker exec -it uos-desktop-20-pro-downloader download.sh deepin-terminal,deepin-screenshot arm64 deepin-tools-arm
```

如果跑专有包时进入了兜底模式，脚本会输出类似下面的提示：

```bash
[错误] 未解析到任何依赖。可能原因：
  - 包名拼写错误
  - 当前是兜底模式（仅 Debian buster archive），目标包可能是 UOS 桌面专有包
    （dde-/deepin-/uos- 等），需要有效的 UOS 授权才能下载。
  - 该包在当前启用的源中不存在
```

### 下载位置

```bash
./output/kylin-desktop-v10sp1/<package>_<arch>/*.deb
./output/uos-desktop-20-pro/<package>_<arch>/*.deb
```

每个目录附带：

- `.dep-list.txt` — 解析出的完整依赖清单
- `.failed.log` — 下载失败的包（空文件 => 全成功）

---

## 验证下载

```bash
# 验证下载到的包架构是否正确

dpkg-deb -f ./output/kylin-desktop-v10sp1/nginx_arm64/nginx_*.deb Architecture
# 应输出: arm64

dpkg-deb -f ./output/uos-desktop-20-pro/dde-control-center_arm64/dde-control-center_*.deb Architecture
# 应输出: arm64
```

---

## 进入容器手动操作

```bash
docker exec -it kylin-desktop-v10sp1-downloader bash
docker exec -it uos-desktop-20-pro-downloader bash

# 查当前 UOS 容器跑的是什么模式：
cat /etc/apt/sources.list | head -3
# 含 chinauos.com 行 → 完整模式
# 仅 archive.debian.org → 兜底模式
```

---

## 清理

```bash
docker compose down
rm -rf ./output
```

---

## 注意事项

- **网络**：
  - 麒麟容器需能够访问 `archive.kylinos.cn` / `archive2.kylinos.cn`
  - UOS 容器需能够访问 `professional-packages.chinauos.com` / `professional-store-packages.chinauos.com` / `archive.debian.org`
- **GPG 校验**：麒麟源使用 `[trusted=yes]` 跳过校验；UOS 源默认签名，授权文件已包含验证所需信息。
- **磁盘**：复杂依赖树可能增长到 GB 级，注意 `output/` 所在分区空间大小。

