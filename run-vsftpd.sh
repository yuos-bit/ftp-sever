#!/bin/bash
# ============================================================
# run-vsftpd.sh — vsftpd 容器入口脚本
# 更新日期: 2026-07-10
# 功能: 初始化虚拟用户（pam_pwdfile）、配置被动模式、启动 vsftpd
# 日志: 初始化信息、传输日志、错误日志均输出到 STDOUT
# ============================================================

# 故意不使用 set -o errexit，因为某些命令可能失败（如 chmod 555 在挂载卷上）
# 但我们仍希望脚本继续执行。使用手动错误检查。
set -o nounset
set -o pipefail

# ---------- 0. 镜像版本号 ----------

IMAGE_VERSION="1.1.1"

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

# ---------- 3. 创建系统用户和目录 ----------

# 使用系统本地用户（pam_unix）进行认证，替代虚拟用户模式
# 这样无需依赖 pam_userdb.so 或 pam_pwdfile.so 等额外 PAM 模块
# 系统用户密码直接由 chpasswd 设置，使用 SHA-512 加密

# 确保 vsftpd 所需的运行目录存在（挂载卷可能覆盖）
mkdir -p /var/run/vsftpd/empty 2>/dev/null || true

# 定义函数：创建或更新 FTP 系统用户
create_ftp_user() {
    local USERNAME="$1"
    local PASSWORD="$2"

    # 用户主目录路径
    local FTP_CHROOT="/home/vsftpd/${USERNAME}"
    local FTP_WRITABLE="${FTP_CHROOT}/files"

    # 创建目录结构
    mkdir -p "${FTP_WRITABLE}"

    # 检查用户是否已存在
    if id "${USERNAME}" &>/dev/null; then
        log_info "用户 ${USERNAME} 已存在，更新密码"
        # 更新密码（chpasswd 接受明文，自动使用 SHA-512 加密）
        echo "${USERNAME}:${PASSWORD}" | /usr/sbin/chpasswd -c SHA512 2>/dev/null || \
        echo "${USERNAME}:${PASSWORD}" | /usr/sbin/chpasswd 2>/dev/null
    else
        log_info "创建系统用户: ${USERNAME}"
        # 创建系统用户（-d 指定家目录，-s 指定 shell，-G ftp 加入 ftp 组）
        # 使用 --no-log-init 避免生成大量的日志条目
        useradd --no-log-init -M -d "${FTP_CHROOT}" -s /usr/sbin/nologin -G ftp "${USERNAME}" 2>/dev/null || \
        useradd -M -d "${FTP_CHROOT}" -s /usr/sbin/nologin -G ftp "${USERNAME}"
        # 设置密码
        echo "${USERNAME}:${PASSWORD}" | /usr/sbin/chpasswd -c SHA512 2>/dev/null || \
        echo "${USERNAME}:${PASSWORD}" | /usr/sbin/chpasswd
    fi

    # 设置目录权限
    # 注意：必须先创建子目录，再修改根目录权限
    chmod 555 "${FTP_CHROOT}" 2>/dev/null || log_warn "无法设置 ${FTP_CHROOT} 为 555（挂载卷限制，忽略）"
    chmod 755 "${FTP_WRITABLE}" 2>/dev/null || log_warn "无法设置 ${FTP_WRITABLE} 为 755（挂载卷限制，忽略）"
    chown -R "${USERNAME}:ftp" "${FTP_CHROOT}" 2>/dev/null || log_warn "无法更改 ${FTP_CHROOT} 所有者（挂载卷限制，忽略）"

    log_info "用户 ${USERNAME} 设置完成"
}

# 修复挂载卷的根目录权限
if [ "$(stat -c '%u:%g' /home/vsftpd)" != "${FTP_UID:-14}:${FTP_GID:-50}" ] 2>/dev/null; then
    chown ftp:ftp /home/vsftpd/ 2>/dev/null || log_warn "无法更改 /home/vsftpd 所有者（挂载卷限制，使用 userns 模式时正常）"
fi

# 创建主用户
create_ftp_user "${FTP_USER}" "${FTP_PASS}"

# 如果指定了 ADDITIONAL_USERS，也创建
if [ -n "${ADDITIONAL_USERS:-}" ]; then
    log_info "检测到 ADDITIONAL_USERS，添加额外用户..."
    IFS=',' read -ra USER_LIST <<< "${ADDITIONAL_USERS}"
    for user_entry in "${USER_LIST[@]}"; do
        ADD_USER=$(echo "${user_entry}" | cut -d: -f1)
        ADD_PASS=$(echo "${user_entry}" | cut -d: -f2)
        if [ -n "${ADD_USER}" ] && [ -n "${ADD_PASS}" ]; then
            create_ftp_user "${ADD_USER}" "${ADD_PASS}"
        fi
    done
fi

# 验证密码
log_info "验证密码..."
if command -v python3 &>/dev/null; then
    python3 -c "
import crypt, subprocess
password = '${FTP_PASS}'
import spwd
try:
    sp = spwd.getspnam('${FTP_USER}')
    stored_hash = sp.sp_pwd
    if crypt.crypt(password, stored_hash) == stored_hash:
        print('密码验证成功: SHA-512 哈希匹配')
    else:
        print('警告: 密码验证失败！哈希不匹配')
        print(f'用户: ${FTP_USER}')
        print(f'哈希: {stored_hash}')
except KeyError:
    print('警告: 无法读取 shadow 密码（容器可能无权限）')
" 2>/dev/null || log_warn "无法使用 python3 验证密码"
fi

# ---------- 4. 被动模式配置 ----------

if [ "${PASV_ADDRESS}" = "**IPv4**" ]; then
    PASV_ADDRESS=$(/sbin/ip route | awk '/default/ { print $3 }')
    log_info "自动检测网关地址: ${PASV_ADDRESS}"
fi

# 将运行时参数追加到 vsftpd.conf（覆盖默认值）
# 注意：pasv_promiscuous=YES 在使用 NAT/防火墙时是必需的
# 否则 vsftpd 会验证数据连接源 IP 与控制连接源 IP 一致，导致数据连接失败
# 注意：先 echo 一个空行，防止 vsftpd.conf 末尾无换行导致第一行配置被拼接到注释行
{
    echo ""
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
    echo "seccomp_sandbox=NO"
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
    · 密码加密:   SHA-512 (pam_unix)
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