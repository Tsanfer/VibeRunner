# ================== 基础镜像配置 ==================
# 定义参数 UBUNTU_VER，默认值为 24.04
ARG UBUNTU_VER=24.04

# 使用参数拼接镜像标签
FROM ghcr.io/catthehacker/ubuntu:act-${UBUNTU_VER}
# ================================================
# 重新定义参数，使其在构建阶段可用
ARG NODE_VER=24

# 设置环境变量，避免安装过程中出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装 OpenSSH 服务器并创建运行目录
RUN apt-get update && apt-get install -y openssh-server && \
    mkdir -p /var/run/sshd

# 配置 SSH 服务
# 1. 允许 root 用户登录 (PermitRootLogin yes)
# 2. 启用公钥认证 (PubkeyAuthentication yes)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config

# 创建 .ssh 目录并设置权限
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# 复制构建上下文中的公钥到容器内（如果存在）
# 本地使用：构建时脚本会自动把 id_rsa.pub 放在 Dockerfile 同级目录
# GitHub Actions：使用 GitHub 提供的 SSH 密钥
COPY --chown=root:root id_rsa.pub* /tmp/ssh_keys/

# 处理 SSH 密钥配置
RUN if [ -f "/tmp/ssh_keys/id_rsa.pub" ]; then \
        cp /tmp/ssh_keys/id_rsa.pub /root/.ssh/authorized_keys && \
        chmod 600 /root/.ssh/authorized_keys; \
    elif [ -n "$SSH_PUBLIC_KEY" ]; then \
        echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys && \
        chmod 600 /root/.ssh/authorized_keys; \
    else \
        echo "Warning: No SSH public key provided" && \
        touch /root/.ssh/authorized_keys && \
        chmod 600 /root/.ssh/authorized_keys; \
    fi && \
    rm -rf /tmp/ssh_keys

# 安装必要的依赖包（fnm 和 Node.js 安装需要）
RUN apt-get update && \
    apt-get install -y curl unzip tar gzip xz-utils ca-certificates

# 直接下载并安装 fnm（使用特定版本，避免交互式安装）
RUN mkdir -p ~/.local/share/fnm && \
    curl -fsSL https://github.com/Schniz/fnm/releases/latest/download/fnm-linux.zip -o ~/.local/share/fnm/fnm.zip && \
    unzip ~/.local/share/fnm/fnm.zip -d ~/.local/share/fnm && \
    rm ~/.local/share/fnm/fnm.zip && \
    chmod +x ~/.local/share/fnm/fnm

# 设置 fnm 环境变量并安装 Node.js 24
RUN export PATH="$HOME/.local/share/fnm:$PATH" && \
    eval "$($HOME/.local/share/fnm/fnm env)" && \
    # 安装 Node.js 24
    $HOME/.local/share/fnm/fnm install $NODE_VER && \
    # 设置 Node.js 24 为默认版本
    $HOME/.local/share/fnm/fnm default $NODE_VER && \
    # 验证 Node.js 版本
    node -v && \
    # 启用 corepack 并安装 pnpm
    corepack enable pnpm && \
    # 验证 pnpm 版本
    pnpm -v

# 全局安装 opencode-ai
RUN export PATH="$HOME/.local/share/fnm:$PATH" && \
    eval "$($HOME/.local/share/fnm/fnm env)" && \
    # 设置 shell 类型以避免 pnpm 错误
    export SHELL=/bin/bash && \
    # 手动设置 pnpm 环境变量
    export PNPM_HOME="$HOME/.pnpm" && \
    export PATH="$PNPM_HOME:$PATH" && \
    # 创建 pnpm 全局目录
    mkdir -p "$PNPM_HOME" && \
    # 使用 pnpm 全局安装 opencode-ai
    pnpm install -g opencode-ai --dangerously-allow-all-builds

# 设置 fnm 和 pnpm 环境变量（确保 SSH 会话也能使用）
RUN echo 'export PATH="$HOME/.local/share/fnm:$PATH"' >> ~/.bashrc && \
    echo 'eval "$($HOME/.local/share/fnm/fnm env)"' >> ~/.bashrc && \
    echo 'export PNPM_HOME="$HOME/.pnpm"' >> ~/.bashrc && \
    echo 'export PATH="$PNPM_HOME:$PATH"' >> ~/.bashrc

# 直接运行 opencode 命令生成缓存（非交互模式）
RUN export PATH="$HOME/.local/share/fnm:$PATH" && \
    eval "$($HOME/.local/share/fnm/fnm env)" && \
    export PNPM_HOME="$HOME/.pnpm" && \
    export PATH="$PNPM_HOME:$PATH" && \
    echo "exit" | opencode || true
  
# 启动 SSH 服务并保持容器运行
CMD /usr/sbin/sshd -D & sleep infinity
