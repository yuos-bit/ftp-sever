# yuos/ftp-server

![docker_logo](docker_139x115.png "Docker 标志")

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

### 方法二：从阿里云容器镜像服务（ACR）管理镜像

#### 登录阿里云 Registry

```bash
docker login --username=今年夏至仅我流连 crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com
```

> 按提示输入阿里云容器镜像服务密码（非登录密码，需在阿里云控制台 -> 容器镜像服务 -> 访问凭证中设置）。

#### 拉取镜像

```bash
# 拉取最新版本
docker pull crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:latest

# 拉取指定版本
docker pull crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0.0

# 拉取指定标签
docker pull crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:tag-name
```

#### 推送镜像

```bash
# 1. 为本地镜像打上阿里云 Registry 标签
#    方法一：通过 ImageId 打标签
docker tag <ImageId> crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0.0

#    方法二：通过已有镜像名打标签
docker tag yuos/ftp-server:latest crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:latest

# 2. 推送（按标签推送，每个标签需单独推送）
docker push crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0.0
docker push crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:latest
```

> **推送多标签示例**：构建后同时推送 `latest` 和版本号两个标签：
>
> ```bash
> docker build -t yuos/ftp-server:latest -t yuos/ftp-server:1.0.0 .
> docker tag yuos/ftp-server:latest crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:latest
> docker tag yuos/ftp-server:1.0.0 crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0.0
> docker push crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:latest
> docker push crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:1.0.0
> ```

### 方法三：本地构建

```bash
# 克隆仓库
git clone https://github.com/fauria/docker-vsftpd.git
cd docker-vsftpd

# 构建镜像（默认 latest 标签）
docker build -t yuos/ftp-server .

# 推荐：构建时指定版本号（同时打 latest 和版本标签）
docker build -t yuos/ftp-server:latest -t yuos/ftp-server:1.0.0 .
```

> **注意**：在 Windows（Docker Desktop）上构建时，请确保 `.dockerignore` 中已排除 `data/` 和 `logs/` 目录，避免构建上下文过大。

#### 版本号管理建议

| 方式 | 命令 |
|---|---|
| 基于 Git commit 自动生成版本 | `VERSION=$(git log --oneline -1 \| awk '{print $1}')`<br>`docker build -t yuos/ftp-server:${VERSION} -t yuos/ftp-server:latest .` |
| 基于日期自动生成版本 | `VERSION=$(date +%Y%m%d)`<br>`docker build -t yuos/ftp-server:${VERSION} -t yuos/ftp-server:latest .` |
| 基于 Git tag 自动生成版本 | `VERSION=$(git describe --tags --always)`<br>`docker build -t yuos/ftp-server:${VERSION} -t yuos/ftp-server:latest .` |
| 从 VERSION 文件读取版本 | 创建 `VERSION` 文件写入版本号（如 `1.0.0`）<br>`VERSION=$(cat VERSION)`<br>`docker build -t yuos/ftp-server:${VERSION} -t yuos/ftp-server:latest .` |

---

## 🐳 Docker Compose 部署（推荐）

项目根目录提供了开箱即用的 `docker-compose.yml`，直接启动即可：

```bash
docker compose up -d
```

### 完整配置参考

```yaml
services:

  vsftpd:
    build:
      context: .
      dockerfile: ./Dockerfile
    image: crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:latest
    container_name: vsftpd
    restart: unless-stopped
    # 允许 vsftpd 所需的系统调用（seccomp 沙箱）
    security_opt:
      - seccomp=unconfined
    ports:
      # FTP 控制端口（注意：宿主 2021 → 容器 21）
      - "2021:21"
      # FTP 数据端口（主动模式）
      - "2020:20"
      # 被动模式端口范围（保持与 PASV_MIN/MAX_PORT 一致）
      - "2030-2040:2030-2040"
    environment:
      # FTP 账户配置
      FTP_USER: admin
      FTP_PASS: ftpadmin..
      # 被动模式地址：必须设为宿主机真实 IP（客户端通过此 IP 连接数据端口）
      PASV_ADDRESS: 127.0.0.1
      PASV_MIN_PORT: 2030
      PASV_MAX_PORT: 2040
      # 启用混杂模式（NAT/端口映射环境下必须开启，否则数据连接被拒）
      PASV_PROMISCUOUS: "YES"
      PORT_PROMISCUOUS: "YES"
      # 其他配置（可按需修改）
      LOG_STDOUT: "YES"
    volumes:
      # FTP 数据目录（宿主目录映射）
      - "./data:/home/vsftpd"
      # 日志目录（可选）
      - "./logs:/var/log/vsftpd"
```

### 一级 docker-compose.override.yml（开发/调试用，不提交到 Git）

```yaml
services:
  vsftpd:
    environment:
      LOG_STDOUT: "YES"
    # 开发时如需调试，可取消下方注释以覆盖入口
    # entrypoint: ["/bin/bash", "-c", "trap : TERM INT; sleep infinity & wait"]
```

---

## ⚙️ 环境变量说明

### 账户认证

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `FTP_USER` | `admin` | FTP 登录用户名，避免使用空格和特殊字符 |
| `FTP_PASS` | 随机 16 位字符串 | FTP 登录密码，未设置时可通过 `docker logs` 查看 |

### 被动模式（PASV）

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `PASV_ADDRESS` | Docker 宿主机 IP | **关键配置**：客户端连接数据端口时使用的 IP。NAT/端口映射环境下必须设为宿主机公网 IP 或域名 |
| `PASV_ADDR_RESOLVE` | `NO` | 是否将 `PASV_ADDRESS` 解析为主机名（`YES`/`NO`） |
| `PASV_ENABLE` | `YES` | 是否启用被动模式（`YES`/`NO`） |
| `PASV_MIN_PORT` | `21100` | 被动模式端口范围下限 |
| `PASV_MAX_PORT` | `21110` | 被动模式端口范围上限 |
| `PASV_PROMISCUOUS` | `NO` | 禁用被动模式 IP 安全检查。**NAT/端口映射环境必须设为 `YES`**，否则数据连接被拒 |

### 主动模式（PORT）

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `PORT_PROMISCUOUS` | `NO` | 禁用主动模式 IP 安全检查。FXP 或 NAT 环境下需设为 `YES` |

### 日志与权限

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `LOG_STDOUT` | 空 | 设为任意值（如 `"YES"`）将日志输出到 STDOUT，可通过 `docker logs` 查看 |
| `XFERLOG_STD_FORMAT` | `NO` | 是否使用标准 xferlog 日志格式（`YES`/`NO`） |
| `FILE_OPEN_MODE` | `0666` | 上传文件的创建权限（结合 umask 使用） |
| `LOCAL_UMASK` | `077` | 本地用户的 umask 值（注意八进制前缀 `0`） |

---

## 🚀 使用示例

### 1. 创建临时测试容器

```bash
docker run --rm yuos/ftp-server
```

### 2. 默认账户 + 绑定数据目录

```bash
docker run -d -p 21:21 -v /my/data/directory:/home/vsftpd --name ftp-server yuos/ftp-server
# 查看日志获取凭据:
docker logs ftp-server
```

### 3. 生产环境部署（自定义端口映射 + 自定义账户）

```bash
docker run -d \
  -v /my/data/directory:/home/vsftpd \
  -v /my/log/directory:/var/log/vsftpd \
  -p 2021:21 -p 2020:20 -p 2030-2040:2030-2040 \
  -e FTP_USER=myuser \
  -e FTP_PASS=mypassword \
  -e PASV_ADDRESS=192.168.1.100 \
  -e PASV_MIN_PORT=2030 \
  -e PASV_MAX_PORT=2040 \
  -e PASV_PROMISCUOUS=YES \
  -e PORT_PROMISCUOUS=YES \
  -e LOG_STDOUT=YES \
  --name ftp-server --restart=unless-stopped \
  yuos/ftp-server
```

### 4. 使用 Docker Compose

项目根目录已包含 `docker-compose.yml`，直接启动：

```bash
docker compose up -d
```

查看运行状态：

```bash
docker compose ps
docker compose logs -f
```

停止并删除容器：

```bash
docker compose down
```

### 5. 手动添加新用户到已有容器

```bash
docker exec -it ftp-server bash

# 创建用户主目录（安全的 chroot 结构）
mkdir -p /home/vsftpd/newuser/files
chmod 555 /home/vsftpd/newuser
chmod 755 /home/vsftpd/newuser/files

# 创建系统用户（使用 pam_unix 认证）
useradd -M -d /home/vsftpd/newuser -s /usr/sbin/nologin -G ftp newuser
# 设置密码（chpasswd 自动使用 SHA-512 加密）
echo "newuser:newpassword" | chpasswd -c SHA512
# 设置目录所有者
chown -R newuser:ftp /home/vsftpd/newuser
/usr/bin/db_load -T -t hash -f /etc/vsftpd/virtual_users.txt /etc/vsftpd/virtual_users.db

exit
docker restart ftp-server
```

---

## 🔌 FTP 客户端连接示例

### FileZilla（推荐）

| 参数 | 值 |
|---|---|
| 主机 | 宿主机 IP 或域名 |
| 端口 | `2021`（控制端口） |
| 协议 | **FTP**（非 SFTP） |
| 加密 | 只使用普通 FTP（不安全） |
| 登录类型 | 正常 |
| 用户 | `admin`（或自定义的 `FTP_USER`） |
| 密码 | 对应的 `FTP_PASS` |
| 传输模式 | **被动模式**（默认） |

> 使用被动模式时，FileZilla 会自动连接 `2030-2040` 端口范围，请确保防火墙放行。

### 命令行（`ftp` 命令）

```bash
# 安装 ftp 客户端（Windows 需在"启用或关闭 Windows 功能"中开启"Telnet 客户端"）
# 或使用 curl：

# 列出目录
curl ftp://192.168.1.100:2021/ --user admin:ftpadmin.. --ftp-pasv

# 下载文件
curl ftp://192.168.1.100:2021/file.txt --user admin:ftpadmin.. --ftp-pasv -o file.txt

# 上传文件
curl -T localfile.txt ftp://192.168.1.100:2021/ --user admin:ftpadmin.. --ftp-pasv
```

### Windows 资源管理器

在地址栏输入：

```
ftp://admin:ftpadmin..@192.168.1.100:2021/
```

> ⚠️ 注意：Windows 资源管理器对 FTP 支持有限，传输大文件或大量文件时建议使用 FileZilla 等专业客户端。

---

## 🛠 Docker 常用命令速查

### 镜像管理

```bash
# 构建镜像
docker build -t yuos/ftp-server .

# 推送镜像到阿里云 Registry
docker tag yuos/ftp-server crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:latest
docker push crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:latest

# 查看本地镜像
docker images
```

### 容器管理

```bash
# 启动容器（后台运行）
docker compose up -d

# 查看运行中的容器
docker ps

# 查看容器日志
docker logs vsftpd
docker logs -f vsftpd    # 持续跟踪日志

# 进入容器内部
docker exec -it vsftpd bash

# 停止容器
docker compose down

# 重启容器
docker restart vsftpd

# 查看容器详细信息（IP、端口映射、挂载等）
docker inspect vsftpd
```

### 数据管理

```bash
# 查看数据目录结构
ls -la ./data/

# 备份数据目录
tar -czf ftp-data-backup-$(date +%Y%m%d).tar.gz ./data/

# 从容器拷贝文件到宿主机
docker cp vsftpd:/home/vsftpd/admin/files ./backup/
```

---

## 🔒 安全说明

### 密码安全

密码使用 SHA-512（`$6$`）哈希加密后存储在系统 shadow 文件中（`pam_unix.so`），不再明文保存。即使文件泄露，也无法直接获取原始密码。

### chroot 安全

采用安全的 chroot 方案：

- **chroot 根目录**（`/home/vsftpd/<user>`）：权限 `555`（不可写）
- **可写子目录**（`/home/vsftpd/<user>/files`）：权限 `755`（可写）

这遵循了 vsftpd 的安全建议——chroot 后的根目录不可写，防止 chroot 逃逸攻击。

### seccomp 沙箱

启用了 seccomp 沙箱保护（`seccomp_sandbox=YES`）。seccomp（Secure Computing Mode）限制 vsftpd 进程可使用的系统调用，在被攻击时显著降低攻击面。此功能需要 Linux 内核 3.5+（Ubuntu 22.04 内核为 5.15+，完全兼容）。

### 端口映射建议

- **公网部署**：`PASV_ADDRESS` 必须设置为宿主机公网 IP 或域名
- **防火墙**：确保开放控制端口（如 `2021`）和被动模式端口范围（如 `2030-2040`）
- **最小权限**：仅在必要时启用 `PASV_PROMISCUOUS` 和 `PORT_PROMISCUOUS`
- **避免使用默认密码**：`docker-compose.yml` 中的 `ftpadmin..` 仅用于测试，生产环境请务必修改

### 安全配置清单

| 检查项 | 推荐值 | 说明 |
|---|---|---|
| `FTP_PASS` | 强密码（≥12 位，含大小写/数字/特殊字符） | 避免使用默认密码 |
| `PASV_PROMISCUOUS` | 仅在 NAT 环境下设为 `YES` | 同网段直连时保持 `NO` |
| `PORT_PROMISCUOUS` | 仅在需要时设为 `YES` | 非必要勿开启 |
| 防火墙 | 仅放行必要端口 | 控制端口 + 被动端口范围 |
| 数据目录备份 | 定期备份 `./data/` | 防止数据丢失 |

---

## 📂 目录结构

```
docker-vsftpd/
├── Dockerfile              # 镜像构建文件（Ubuntu 22.04）
├── docker-compose.yml      # Docker Compose 配置（含自定义端口映射）
├── .dockerignore           # 构建上下文忽略规则
├── .gitignore              # Git 忽略规则
├── run-vsftpd.sh           # 容器入口脚本
├── vsftpd.conf             # vsftpd 服务器配置
├── vsftpd_virtual          # PAM 虚拟用户认证配置
├── README.md               # 本文档
├── data/                   # FTP 数据目录（映射到 /home/vsftpd）
├── logs/                   # 日志目录（映射到 /var/log/vsftpd，可选）
└── LICENSE                 # Apache License 2.0
```

---

## 🐳 暴露端口与卷

### 端口

| 端口（宿主:容器） | 协议 | 说明 |
|---|---|---|
| `2021:21` | TCP | FTP 控制端口（宿主 2021 → 容器 21） |
| `2020:20` | TCP | FTP 数据端口（主动模式） |
| `2030-2040:2030-2040` | TCP | 被动模式数据端口范围 |

> 以上为 `docker-compose.yml` 的默认映射。你可以根据实际需求修改宿主端口，避免与现有服务冲突。

### 卷

| 宿主路径 | 容器路径 | 说明 |
| :--- | :--- | :--- |
| `./data` | `/home/vsftpd` | 用户主目录（FTP 数据），必须映射 |
| `./logs` | `/var/log/vsftpd` | vsftpd 日志目录，可选映射 |

> **注意**：挂载宿主机目录时，FTP 用户的 UID/GID 应为 `14/50`（容器内 ftp 用户的默认 ID）。

---

## 📄 许可证

本项目基于 [Apache License 2.0](LICENSE) 开源。

---

## 🤝 致谢

- 原项目：[fauria/vsftpd](https://github.com/fauria/docker-vsftpd) — Fer Uria 维护的原始 vsftpd Docker 镜像