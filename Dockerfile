# ============================================================
# Dockerfile — yuos/ftp-server（基于 fauria/vsftpd 重构）
# 更新日期: 2026-07-10
# 基础镜像: Ubuntu 22.04 LTS (Jammy Jellyfish)
# ============================================================

FROM ubuntu:22.04

ARG USER_ID=14
ARG GROUP_ID=50

LABEL Description="vsftpd Docker 镜像，基于 Ubuntu 22.04。支持被动模式和虚拟用户。" \
      License="Apache License 2.0" \
      Usage="docker run -d -p 21:21 -v <FTP_HOME_DIR>:/home/vsftpd yuos/ftp-server" \
      Version="2.0"

# 避免 tzdata 等交互式安装时卡住
ENV DEBIAN_FRONTEND=noninteractive

# 更新软件源并安装依赖包（合并 RUN 以减少层数）
RUN apt-get update && apt-get install -y --no-install-recommends \
    vsftpd \
    db-util \
    iproute2 \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 调整 ftp 用户的 UID/GID
# 注意：Ubuntu 22.04 中 GID 50 被 staff 组占用，需先删除冲突组再修改
RUN groupdel staff 2>/dev/null; \
    groupmod -g ${GROUP_ID} ftp && \
    usermod -u ${USER_ID} ftp

# 创建必要的运行目录
RUN mkdir -p /home/vsftpd && \
    chown -R ftp:ftp /home/vsftpd && \
    mkdir -p /var/log/vsftpd /etc/vsftpd /usr/share/empty

# 环境变量（使用 KEY=value 格式）
ENV FTP_USER=**String**
ENV FTP_PASS=**Random**
ENV PASV_ADDRESS=**IPv4**
ENV PASV_ADDR_RESOLVE=NO
ENV PASV_ENABLE=YES
ENV PASV_MIN_PORT=21100
ENV PASV_MAX_PORT=21110
ENV XFERLOG_STD_FORMAT=NO
ENV LOG_STDOUT=**Boolean**
ENV FILE_OPEN_MODE=0666
ENV LOCAL_UMASK=077
ENV REVERSE_LOOKUP_ENABLE=YES
ENV PASV_PROMISCUOUS=NO
ENV PORT_PROMISCUOUS=NO

# 拷贝配置文件
COPY vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY vsftpd_virtual /etc/pam.d/vsftpd_virtual
COPY run-vsftpd.sh /usr/sbin/run-vsftpd.sh
RUN chmod +x /usr/sbin/run-vsftpd.sh

# 设置数据卷
VOLUME /home/vsftpd
VOLUME /var/log/vsftpd

# 暴露 FTP 控制端口和数据端口
EXPOSE 20 21

# 设置入口
CMD ["/usr/sbin/run-vsftpd.sh"]