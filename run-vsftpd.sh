#!/bin/bash
# ============================================================
# run-vsftpd.sh — vsftpd 容器入口脚本
# 更新日期: 2026-07-10
# 功能: 初始化虚拟用户、配置被动模式、启动 vsftpd
# 日志: 初始化信息、传输日志、错误日志均输出到 STDOUT
# ============================================================

# 故意不使用 set -o errexit，因为某些命令可能失败（如 chmod 555 在挂载卷上）
# 但我们仍希望脚本继续执行。使用手动错误检查。
set -o nounset
set -o pipefail

# ---------- 0. 镜像版本号 ----------

IMAGE_VERSION="1.0.10"

# 日志函数：带时间戳输出到 STDOUT
log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*"; }
log_warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"; }

# ---------- 1. FTP 用户配置 ----------

# 如果未指定 FTP_USER，使用默认值 'admin'
if [ "${FTP_USER}" = "**String**" ]; then
    FTP_USER='admin'
    log_info "使用默认用户名: ${FTP_USER}"
fi

# 如果未指定 FTP_PASS，生成 16 位随机密码
if [ "${FTP_PASS}" = "**Random**" ]; then
    FTP_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
    log_info "已生成随机密码"
fi

# ---------- 2. 日志配置 ----------

# 默认不输出到 STDOUT
if [ "${LOG_STDOUT}" = "**Boolean**" ]; then
    LOG_STDOUT=''
fi

# 查找 vsftpd 配置中的日志文件路径
XFERLOG_FILE=$(grep '^xferlog_file=' /etc/vsftpd/vsftpd.conf | cut -d= -f2)
VSFTPD_LOG_FILE="/var/log/vsftpd/vsftpd.log"

# 如果配置中没有 xferlog_file，使用默认路径
if [ -z "${XFERLOG_FILE}" ]; then
    XFERLOG_FILE="/var/log/vsftpd/vsftpd.log"
fi

# ---------- 3. 创建用户目录和虚拟用户数据库 ----------

# vsftpd 要求 chroot 根目录不可写，但用户需要能够写入文件。
# 安全方案：chroot 根目录（用户主目录）设为不可写（555），
# 在内部创建可写子目录（755）供用户使用。

# 确保 vsftpd 所需的运行目录存在（挂载卷可能覆盖）
mkdir -p /var/run/vsftpd/empty 2>/dev/null || true

# 虚拟用户数据库文件路径
VIRTUAL_USERS_DB="/etc/vsftpd/virtual_users.db"
VIRTUAL_USERS_TXT="/etc/vsftpd/virtual_users.txt"

# 检查是否已存在虚拟用户数据库（持久化挂载的场景）
if [ -f "${VIRTUAL_USERS_DB}" ] && [ -s "${VIRTUAL_USERS_DB}" ]; then
    log_info "检测到已存在的虚拟用户数据库，跳过用户创建"

    # 但还是要确保 FTP_USER 的目录存在
    FTP_CHROOT="/home/vsftpd/${FTP_USER}"
    FTP_WRITABLE="${FTP_CHROOT}/files"
    mkdir -p "${FTP_WRITABLE}"
    chmod 555 "${FTP_CHROOT}" 2>/dev/null || true
    chmod 755 "${FTP_WRITABLE}" 2>/dev/null || true
    chown -R ftp:ftp /home/vsftpd/ 2>/dev/null || true

    # 如果指定了 ADDITIONAL_USERS，将其追加到数据库
    if [ -n "${ADDITIONAL_USERS:-}" ]; then
        log_info "检测到 ADDITIONAL_USERS，添加额外用户..."
        IFS=',' read -ra USER_LIST <<< "${ADDITIONAL_USERS}"
        for user_entry in "${USER_LIST[@]}"; do
            ADD_USER=$(echo "${user_entry}" | cut -d: -f1)
            ADD_PASS=$(echo "${user_entry}" | cut -d: -f2)
            if [ -n "${ADD_USER}" ] && [ -n "${ADD_PASS}" ]; then
                ADD_HASH=$(openssl passwd -6 "${ADD_PASS}" 2>/dev/null || echo "${ADD_PASS}")
                echo -e "${ADD_USER}\n${ADD_HASH}" >> "${VIRTUAL_USERS_TXT}"
                log_info "添加额外用户: ${ADD_USER}"
            fi
        done
        # 重新生成数据库
        /usr/bin/db_load -T -t hash -f "${VIRTUAL_USERS_TXT}" "${VIRTUAL_USERS_DB}"
        log_info "虚拟用户数据库已更新"
    fi
else
    # 首次启动：创建用户
    FTP_CHROOT="/home/vsftpd/${FTP_USER}"
    FTP_WRITABLE="${FTP_CHROOT}/files"

    log_info "创建用户目录: ${FTP_CHROOT}"

    # 创建目录结构（即使挂载了宿主机目录，子目录 files/ 也需要创建）
    mkdir -p "${FTP_WRITABLE}"

    # 修复挂载卷的根目录权限
    if [ "$(stat -c '%u:%g' /home/vsftpd)" != "${FTP_UID:-14}:${FTP_GID:-50}" ] 2>/dev/null; then
        chown ftp:ftp /home/vsftpd/ 2>/dev/null || log_warn "无法更改 /home/vsftpd 所有者（挂载卷限制，使用 userns 模式时正常）"
    fi
    chown ftp:ftp "${FTP_CHROOT}" 2>/dev/null || true
    chown ftp:ftp "${FTP_WRITABLE}" 2>/dev/null || true

    # 注意：必须先创建子目录，再修改根目录权限
    chmod 555 "${FTP_CHROOT}" 2>/dev/null || log_warn "无法设置 ${FTP_CHROOT} 为 555（挂载卷限制，忽略）"
    chmod 755 "${FTP_WRITABLE}" 2>/dev/null || log_warn "无法设置 ${FTP_WRITABLE} 为 755（挂载卷限制，忽略）"

    # 写入虚拟用户数据库
    log_info "生成密码哈希..."
    FTP_PASS_HASH=$(openssl passwd -6 "${FTP_PASS}" 2>/dev/null || echo "${FTP_PASS}")
    echo -e "${FTP_USER}\n${FTP_PASS_HASH}" > "${VIRTUAL_USERS_TXT}"

    # 如果指定了 ADDITIONAL_USERS，也添加进去
    if [ -n "${ADDITIONAL_USERS:-}" ]; then
        IFS=',' read -ra USER_LIST <<< "${ADDITIONAL_USERS}"
        for user_entry in "${USER_LIST[@]}"; do
            ADD_USER=$(echo "${user_entry}" | cut -d: -f1)
            ADD_PASS=$(echo "${user_entry}" | cut -d: -f2)
            if [ -n "${ADD_USER}" ] && [ -n "${ADD_PASS}" ]; then
                ADD_HASH=$(openssl passwd -6 "${ADD_PASS}" 2>/dev/null || echo "${ADD_PASS}")
                echo -e "${ADD_USER}\n${ADD_HASH}" >> "${VIRTUAL_USERS_TXT}"
                log_info "添加额外用户: ${ADD_USER}"
            fi
        done
    fi

    /usr/bin/db_load -T -t hash -f "${VIRTUAL_USERS_TXT}" "${VIRTUAL_USERS_DB}"
    log_info "虚拟用户数据库已创建"
fi

# ---------- 4. 被动模式配置 ----------

if [ "${PASV_ADDRESS}" = "**IPv4**" ]; then
    PASV_ADDRESS=$(/sbin/ip route | awk '/default/ { print $3 }')
    log_info "自动检测网关地址: ${PASV_ADDRESS}"
fi

# 将运行时参数追加到 vsftpd.conf（覆盖默认值）
{
    echo "pasv_address=${PASV_ADDRESS}"
    echo "pasv_max_port=${PASV_MAX_PORT}"
    echo "pasv_min_port=${PASV_MIN_PORT}"
    echo "pasv_addr_resolve=${PASV_ADDR_RESOLVE}"
    echo "pasv_enable=${PASV_ENABLE}"
    echo "file_open_mode=${FILE_OPEN_MODE}"
    echo "local_umask=${LOCAL_UMASK}"
    echo "xferlog_std_format=${XFERLOG_STD_FORMAT}"
    echo "pasv_promiscuous=${PASV_PROMISCUOUS}"
    echo "port_promiscuous=${PORT_PROMISCUOUS}"
} >> /etc/vsftpd/vsftpd.conf

log_info "被动模式配置已写入"

# ---------- 5. 日志文件重定向到 STDOUT ----------

# 始终将 vsftpd 日志重定向到 STDOUT，确保 docker logs 可见
if [ -n "${XFERLOG_FILE}" ]; then
    # 确保日志目录存在
    mkdir -p "$(dirname "${XFERLOG_FILE}")" 2>/dev/null || true
    # 使用 tail -f 方式替代软链接，避免 chroot 后无法访问 /proc/self/fd/1
    # 在后台启动 tail 监听日志文件并输出到 STDOUT
    touch "${XFERLOG_FILE}" 2>/dev/null || true
    tail -f "${XFERLOG_FILE}" &
    log_info "传输日志已重定向到 STDOUT（tail 方式）"
fi

# 如果配置了单独的 vsftpd 日志文件，也重定向到 STDOUT
if [ -n "${VSFTPD_LOG_FILE}" ] && [ "${VSFTPD_LOG_FILE}" != "${XFERLOG_FILE}" ]; then
    mkdir -p "$(dirname "${VSFTPD_LOG_FILE}")" 2>/dev/null || true
    touch "${VSFTPD_LOG_FILE}" 2>/dev/null || true
    tail -f "${VSFTPD_LOG_FILE}" &
fi

# 将 vsftpd 的 syslog 输出也重定向到 STDOUT
VSFTPD_SYSLOG_FILE="/var/log/vsftpd/vsftpd_syslog.log"
mkdir -p "$(dirname "${VSFTPD_SYSLOG_FILE}")" 2>/dev/null || true
touch "${VSFTPD_SYSLOG_FILE}" 2>/dev/null || true
tail -f "${VSFTPD_SYSLOG_FILE}" 2>/dev/null &

# ---------- 6. 输出服务器信息（Banner） ----------

# 获取监听端口（从 vsftpd.conf 中读取，默认 21）
LISTEN_PORT=$(grep '^listen_port=' /etc/vsftpd/vsftpd.conf | cut -d= -f2)
if [ -z "${LISTEN_PORT}" ]; then
    LISTEN_PORT=21
fi

cat << EOB
====================================================

    Docker 镜像: crpi-p23ba2t3b53i8v8p.cn-chengdu.personal.cr.aliyuncs.com/yuos-data/ftp-sever:${IMAGE_VERSION}
    GitHub: https://github.com/yuos-bit/ftp-sever
    更新日期: 2026-07-10  版本号: ${IMAGE_VERSION}

====================================================
    服务器配置
    -----------------------------------------------
    · FTP 用户名: ${FTP_USER}
    · FTP 密码:   ${FTP_PASS}
    · 密码加密:   SHA-512 (\$6\$)
    · 日志文件:   ${XFERLOG_FILE}
    · 日志输出:   已重定向到 STDOUT（docker logs 可见）
    · 沙箱保护:   已禁用（seccomp_sandbox=NO）
    · chroot 安全: 已加固
    · 被动模式地址: ${PASV_ADDRESS}
    · 被动模式端口: ${PASV_MIN_PORT}-${PASV_MAX_PORT}
====================================================

EOB

# ---------- 7. 启动 vsftpd ----------

log_info "初始化完成，正在启动 vsftpd 服务..."
log_info "启动 vsftpd..."

# 先在后台启动，确认启动成功后再转前台
/usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf &
VSFTPD_PID=$!
sleep 1

# 检查 vsftpd 是否成功启动（仍在运行）
if kill -0 ${VSFTPD_PID} 2>/dev/null; then
    log_info "ftp服务已成功启动"
    # 等待后台进程，保持容器运行
    wait ${VSFTPD_PID}
else
    # 获取退出码
    wait ${VSFTPD_PID}
    EXIT_CODE=$?
    log_error "ftp服务启动失败，退出码: ${EXIT_CODE}"
    exit ${EXIT_CODE}
fi