# UOS 授权目录（可选）

这是 UOS 桌面专业版授权文件 `uos.conf` 的存放位置。**放与不放都能跑**：


| 是否放 `uos.conf` | 容器进入的模式                      | 能下载的包范围                           |
| -------------- | ---------------------------- | --------------------------------- |
| 放了，且服务端接受      | 完整模式                         | UOS 桌面专有包（dde-/deepin-/uos-）+ 通用包 |
| 放了，但服务端拒绝（401） | 启动是完整模式，首次 `apt update` 自动降级 | 只能下通用包                            |
| 没放             | 启动直接进入兜底模式                   | 只能下通用包                            |


如果你只下载 nginx / curl / openssl 这类通用包，**整个目录留空就行**，无需任何配置。

---

## 怎么从授权机器导出 `uos.conf`

在你那台已激活的 UOS 桌面专业版机器上执行：

```bash
sudo cat /etc/apt/auth.conf.d/uos.conf
# 应该能看到形如:
#   machine professional-packages.chinauos.com
#   login uos-https://license.chinauos.com-apt
#   password a=...&aa=...&...
# 这样的内容（password 那一长串里包含本机硬件指纹）

sudo cp /etc/apt/auth.conf.d/uos.conf /tmp/uos.conf
sudo chown $USER /tmp/uos.conf

# 然后通过 scp / U 盘 / 任何方式把 /tmp/uos.conf 拷到 Docker 宿主机的本目录:
#   CNSD/uos-desktop-20-pro/uos-auth/uos.conf
```

放好后重启 UOS 容器：

```bash
docker compose restart uos-desktop-20-pro-downloader
```

容器启动日志会显示当前进入的是完整模式还是兜底模式。

## 注意事项

- **`uos.conf` 含本机硬件指纹**，UOS 服务端可能校验来源 IP / 心跳，跨机器复用不一定成功。
- 即便服务端拒绝，下载脚本会自动降级到 Debian 通用包模式，不会让你的下载流程整个挂掉。

