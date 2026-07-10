# yuos/ftp-server

![docker_logo](docker_139x115.png "Docker 标志") ![docker_fauria_logo](docker_fauria_161x115.png "FTP 服务器标志")

## 📋 项目概述

本项目基于 [fauria/vsftpd](https://github.com/fauria/docker-vsftpd) 进行重构，是一款安全加固的 **vsftpd**（Very Secure FTP Daemon）Docker 镜像，支持虚拟用户认证和被动模式传输。

### 主要特性

- **基础镜像**：Ubuntu 22.04 LTS（Jammy Jellyfish）
- **FTP 服务器**：vsftpd 3.0.5+
- **虚拟用户**：使用 PAM + Berkeley DB 进行虚拟用户认证
- **被动模式**：支持可配置的被动端口范围
- **密码加密**：使用 SHA-512（`$6$`）哈希存储密码
- **安全增强**：启用 seccomp 沙箱保护
- **chroot 加固**：安全的 chroot 环境，无需 `allow_writeable_chroot`
- **日志输出**：支持日志输出到文件或 STDOUT（`docker logs`）

---

## 🔄 与 fauria/vsftpd 的差异

| 项目 | fauria/vsftpd（原版） | yuos/ftp-server（本版） |
|---|---|---|
| 基础镜像 | CentOS 7（已 EOL） | Ubuntu 22.04 LTS |
| 密码存储 | 明文 | SHA-512 哈希加密 |
| seccomp 沙箱 | 禁用（`seccomp_sandbox=NO`） | 启用（`seccomp_sandbox=YES`） |
| chroot 安全性 | `allow_writeable_chroot=YES` | 不可写根目录 + 可写子目录 |
| 构建效率 | 无 `.dockerignore` | 有 `.dockerignore`，构建上下文更小 |
| 脚本健壮性 | 有变量引用缺陷 | `set -o nounset pipefail`，全引用保护 |
| 文档语言 | 英文 | 简体中文 |

---

## 🔄 更新历史

### 2026-07-09 — 初始版本 1.0

| 变更 | 说明 |
|---|---|
| 🚀 **基础镜像升级** | 从 CentOS 7（已 EOL）迁移至 Ubuntu 22.04 LTS |
| 🔐 **密码哈希加密** | 密码不再明文存储，使用 SHA-512（`$6$`）加密 |
| 🛡️ **seccomp 沙箱** | 启用 seccomp 沙箱保护（`seccomp_sandbox=YES`） |
| 🔒 **chroot 安全加固** | 移除 `allow_writeable_chroot=YES`，采用不可写 chroot 根 + 可写子目录方案 |
| 🏗️ **构建效率** | 添加 `.dockerignore` 减少构建上下文体积 |
| 🐛 **脚本修复** | 修复变量引用缺陷，启用 `set -o nounset` 和 `set -o pipefail` |
| 📝 **文档重构** | 全部文档以简体中文重写 |

---

## 📦 安装与构建

### 方法一：从 Docker Hub 拉取

```bash
docker pull yuos/ftp-server
```

### 方法二：从阿里云 Registry 拉取

```bash
docker pull crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0
```

### 方法二：本地构建

```bash
# 克隆仓库
git clone https://github.com/fauria/docker-vsftpd.git
cd docker-vsftpd

# 构建镜像
docker build -t yuos/ftp-server .
```

### 方法三：使用 Docker Compose

```bash
docker-compose up -d
```

---

## 🚀 推送到阿里云 Registry

构建镜像后，您可以将其推送到阿里云容器镜像服务（ACR），让其他人也能拉取使用。

### 前置条件

1. 在 [阿里云容器镜像服务](https://cr.console.aliyun.com/) 创建命名空间 `yuos-data` 和仓库 `ftp-sever`
2. 仓库类型选择**公开（Public）**

### 推送步骤

```bash
# 1. 登录阿里云 Registry
docker login --username=今年夏至仅我流连 crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com

# 2. 构建镜像
docker build -t yuos/ftp-server .

# 3. 标记镜像为阿里云 Registry 地址
docker tag yuos/ftp-server:latest crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0

# 4. 推送到阿里云
docker push crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0
```

### 使用 Docker Compose 构建并推送

```bash
# 构建镜像
docker-compose build

# 标记并推送
docker tag yuos/ftp-server:latest crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0
docker push crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0
```

### 验证推送结果

```bash
# 从阿里云 Registry 拉取测试
docker pull crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0

# 运行测试
docker run --rm crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0
```

---

## ⚙️ 环境变量

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `FTP_USER` | `admin` | FTP 账户用户名，避免使用空格和特殊字符 |
| `FTP_PASS` | 随机 16 位字符串 | FTP 账户密码，可通过 `docker logs` 查看 |
| `PASV_ADDRESS` | Docker 宿主机 IP | 被动模式使用的 IP 地址或主机名 |
| `PASV_ADDR_RESOLVE` | `NO` | 是否解析 `PASV_ADDRESS` 为主机名（`YES`/`NO`） |
| `PASV_ENABLE` | `YES` | 是否启用被动模式（`YES`/`NO`） |
| `PASV_MIN_PORT` | `21100` | 被动模式端口范围下限 |
| `PASV_MAX_PORT` | `21110` | 被动模式端口范围上限 |
| `XFERLOG_STD_FORMAT` | `NO` | 是否使用标准 xferlog 日志格式（`YES`/`NO`） |
| `LOG_STDOUT` | 空 | 设置任意值将日志输出到 STDOUT（`docker logs` 可见） |
| `FILE_OPEN_MODE` | `0666` | 上传文件的创建权限（结合 umask 使用） |
| `LOCAL_UMASK` | `077` | 本地用户的 umask 值（注意八进制前缀 `0`） |
| `REVERSE_LOOKUP_ENABLE` | `YES` | 是否启用反向 DNS 查询（网络慢时设为 `NO`） |
| `PASV_PROMISCUOUS` | `NO` | 禁用被动模式 IP 安全检查（仅 FXP 或隧道时启用） |
| `PORT_PROMISCUOUS` | `NO` | 禁用主动模式 IP 安全检查（仅 FXP 时启用） |

---

## 🚀 使用示例

### 1. 创建临时测试容器

```bash
docker run --rm yuos/ftp-server
```

### 2. 使用默认账户和绑定数据目录

```bash
docker run -d -p 21:21 -v /my/data/directory:/home/vsftpd --name ftp-server yuos/ftp-server
# 查看日志获取凭据:
docker logs ftp-server
```

### 3. 生产环境部署（自定义用户 + 主动 + 被动模式）

```bash
docker run -d \
  -v /my/data/directory:/home/vsftpd \
  -p 20:20 -p 21:21 -p 21100-21110:21100-21110 \
  -e FTP_USER=myuser \
  -e FTP_PASS=mypassword \
  -e PASV_ADDRESS=192.168.1.100 \
  -e PASV_MIN_PORT=21100 \
  -e PASV_MAX_PORT=21110 \
  --name ftp-server --restart=unless-stopped \
  yuos/ftp-server
```

### 4. 使用 Docker Compose

创建 `docker-compose.yml`：

```yaml
version: "3.8"

services:
  ftp-server:
    image: yuos/ftp-server
    container_name: ftp-server
    restart: unless-stopped
    ports:
      - "20:20"
      - "21:21"
      - "21100-21110:21100-21110"
    environment:
      FTP_USER: user1
      FTP_PASS: ftp-password-123
      PASV_ADDRESS: 127.0.0.1
      PASV_MIN_PORT: 21100
      PASV_MAX_PORT: 21110
    volumes:
      - "./data:/home/vsftpd"
```

然后启动：

```bash
docker-compose up -d
```

### 5. 手动添加新用户到已有容器

```bash
docker exec -it ftp-server bash

# 创建用户主目录（安全的 chroot 结构）
mkdir -p /home/vsftpd/newuser/files
chmod 555 /home/vsftpd/newuser
chmod 755 /home/vsftpd/newuser/files

# 生成密码哈希并更新数据库
FTP_PASS_HASH=$(openssl passwd -6 "newpassword")
echo -e "newuser\n${FTP_PASS_HASH}" >> /etc/vsftpd/virtual_users.txt
/usr/bin/db_load -T -t hash -f /etc/vsftpd/virtual_users.txt /etc/vsftpd/virtual_users.db

exit
docker restart ftp-server
```

---

## 🔒 安全说明

### 密码安全

密码使用 SHA-512（`$6$`）哈希加密后存储在 Berkeley DB 中，不再明文保存。即使数据库文件泄露，也无法直接获取原始密码。

### chroot 安全

采用安全的 chroot 方案：

- **chroot 根目录**（`/home/vsftpd/<user>`）：权限 `555`（不可写）
- **可写子目录**（`/home/vsftpd/<user>/files`）：权限 `755`（可写）

这遵循了 vsftpd 的安全建议——chroot 后的根目录不可写，防止 chroot 逃逸攻击。

### seccomp 沙箱

启用了 seccomp 沙箱保护（`seccomp_sandbox=YES`）。seccomp（Secure Computing Mode）限制 vsftpd 进程可使用的系统调用，在被攻击时显著降低攻击面。此功能需要 Linux 内核 3.5+（Ubuntu 22.04 内核为 5.15+，完全兼容）。

### 端口映射建议

- **公网部署**：`PASV_ADDRESS` 必须设置为宿主机公网 IP 或域名
- **防火墙**：确保开放端口 20（主动模式数据）、21（控制）、21100-21110（被动模式数据）
- **最小权限**：仅在必要时启用 `PASV_PROMISCUOUS` 和 `PORT_PROMISCUOUS`

---

## 📂 目录结构

```
docker-vsftpd/
├── Dockerfile          # 镜像构建文件（Ubuntu 22.04）
├── docker-compose.yml  # Docker Compose 配置
├── .dockerignore       # 构建上下文忽略规则
├── .gitignore          # Git 忽略规则
├── run-vsftpd.sh       # 容器入口脚本
├── vsftpd.conf         # vsftpd 服务器配置
├── vsftpd_virtual      # PAM 虚拟用户认证配置
├── README.md           # 本文档
└── LICENSE             # Apache License 2.0
```

---

## 🐳 暴露端口与卷

### 端口

| 端口 | 协议 | 说明 |
|---|---|---|
| `20` | TCP | FTP 数据端口（主动模式） |
| `21` | TCP | FTP 控制端口 |
| `21100-21110` | TCP | 被动模式数据端口范围 |

### 卷

| 容器路径 | 说明 |
|---|---|
| `/home/vsftpd` | 用户主目录（FTP 数据） |
| `/var/log/vsftpd` | vsftpd 日志目录 |

> **注意**：挂载宿主机目录时，FTP 用户的 UID/GID 应为 `14/50`（容器内 ftp 用户的默认 ID）。

---

## 📄 许可证

本项目基于 [Apache License 2.0](LICENSE) 开源。

---

## 🤝 致谢

- 原项目：[fauria/vsftpd](https://github.com/fauria/docker-vsftpd) — Fer Uria 维护的原始 vsftpd Docker 镜像