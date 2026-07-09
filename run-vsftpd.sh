#!/bin/bash
# ============================================================
# run-vsftpd.sh — vsftpd 容器入口脚本
# 更新日期: 2026-07-09
# 功能: 初始化虚拟用户、配置被动模式、启动 vsftpd
# ============================================================

set -o errexit
set -o nounset
set -o pipefail

# ---------- 1. FTP 用户配置 ----------

# 如果未指定 FTP_USER，使用默认值 'admin'
if [ "${FTP_USER}" = "**String**" ]; then
    FTP_USER='admin'
fi

# 如果未指定 FTP_PASS，生成 16 位随机密码
if [ "${FTP_PASS}" = "**Random**" ]; then
    FTP_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
fi

# ---------- 2. 日志配置 ----------

# 默认不输出到 STDOUT
if [ "${LOG_STDOUT}" = "**Boolean**" ]; then
    LOG_STDOUT=''
fi

# ---------- 3. 创建用户目录（安全 chroot 结构）和虚拟用户数据库 ----------

# vsftpd 要求 chroot 根目录不可写，但用户需要能够写入文件。
# 安全方案：chroot 根目录（用户主目录）设为不可写（555），
# 在内部创建可写子目录（755）供用户使用。
FTP_CHROOT="/home/vsftpd/${FTP_USER}"
FTP_WRITABLE="${FTP_CHROOT}/files"

mkdir -p "${FTP_WRITABLE}"

# chroot 根目录设为不可写（vsftpd chroot 安全检查要求）
chmod 555 "${FTP_CHROOT}"
# 用户实际可写目录
chmod 755 "${FTP_WRITABLE}"
chown -R ftp:ftp /home/vsftpd/

# 在用户登录时自动切换到可写子目录（可选）
# 用户可以使用 "cd files" 进入可写区域

# 生成密码哈希（SHA-512，即 $6$ 格式）
# 使用 openssl passwd 生成兼容 /etc/shadow 的哈希
FTP_PASS_HASH=$(openssl passwd -6 "${FTP_PASS}")

# 写入虚拟用户文件（格式: 用户名\n密码哈希\n）
echo -e "${FTP_USER}\n${FTP_PASS_HASH}" > /etc/vsftpd/virtual_users.txt
/usr/bin/db_load -T -t hash -f /etc/vsftpd/virtual_users.txt /etc/vsftpd/virtual_users.db

# ---------- 4. 被动模式配置 ----------

if [ "${PASV_ADDRESS}" = "**IPv4**" ]; then
    PASV_ADDRESS=$(/sbin/ip route | awk '/default/ { print $3 }')
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
    echo "reverse_lookup_enable=${REVERSE_LOOKUP_ENABLE}"
    echo "pasv_promiscuous=${PASV_PROMISCUOUS}"
    echo "port_promiscuous=${PORT_PROMISCUOUS}"
} >> /etc/vsftpd/vsftpd.conf

# ---------- 5. 日志文件处理 ----------

LOG_FILE=$(grep '^xferlog_file=' /etc/vsftpd/vsftpd.conf | cut -d= -f2)

# 输出服务器信息
if [ -z "${LOG_STDOUT}" ]; then
    cat << EOB
====================================================

    Docker 镜像: yuos/ftp-server
    GitHub: https://github.com/fauria/docker-vsftpd
    更新日期: 2026-07-09

====================================================
    服务器配置
    -----------------------------------------------
    · FTP 用户名: ${FTP_USER}
    · FTP 密码:   ${FTP_PASS}
    · 密码加密:   SHA-512 ($6$)
    · 日志文件:   ${LOG_FILE}
    · 日志输出到 STDOUT: 否
    · 沙箱保护:   已启用
    · chroot 安全: 已加固
EOB
else
    # 将日志重定向到 STDOUT（用于 docker logs）
    if [ -n "${LOG_FILE}" ]; then
        ln -sf /dev/stdout "${LOG_FILE}"
    fi
fi

# ---------- 6. 启动 vsftpd ----------

# 前台运行（background=NO），保持容器不退出
exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf