<#
.SYNOPSIS
    VibeRunner 开发环境管理脚本（云端镜像版）
.DESCRIPTION
    1. 拉取云端镜像 ghcr.io/tsanfer/viberunner。
    2. 检查并生成本地 SSH 密钥（用于连接容器）。
    3. 启动容器，挂载 C:\Code 到 /workspace，并注入本机公钥。
    4. 输出 SSH 连接信息供 IDE 使用。
#>

param(
    [string]$Image = "ghcr.io/tsanfer/viberunner",
    [int]$Port = 2222
)

# ================= 路径定义 =================
$ENV_ROOT = $PSScriptRoot
$CODE_ROOT = Split-Path $ENV_ROOT -Parent
$CONTAINER_NAME = "vibe-runner"
$SSH_DIR = "$env:USERPROFILE\.ssh"
$PRIV_KEY_PATH = "$SSH_DIR\id_rsa"
$PUB_KEY_PATH = "$SSH_DIR\id_rsa.pub"
# ===========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   VibeRunner 开发环境（云端镜像）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. 🔑 检查并生成 SSH 密钥（用于连接容器）
if (!(Test-Path $PRIV_KEY_PATH)) {
    Write-Host "⚠️  未检测到 SSH 密钥，正在生成..." -ForegroundColor Yellow
    ssh-keygen -t rsa -b 4096 -f $PRIV_KEY_PATH -N "" | Out-Null
    Write-Host "✅ 密钥已生成。" -ForegroundColor Green
}

# 2. 📥 拉取云端镜像
Write-Host "📥 正在拉取镜像: $Image" -ForegroundColor Cyan
podman pull $Image

# 3. 🚀 启动容器
# 先清理旧容器
if (podman ps -a -q -f name=$CONTAINER_NAME) {
    Write-Host "🔄 移除旧容器 [$CONTAINER_NAME]..." -ForegroundColor Yellow
    podman rm -f $CONTAINER_NAME | Out-Null
}

# 启动新容器：
# - 挂载代码目录
# - 挂载公钥到容器的 authorized_keys（关键！）
# - 映射 SSH 端口
Write-Host "🚀 正在启动容器..." -ForegroundColor Cyan
podman run -d --name $CONTAINER_NAME `
  -v "${CODE_ROOT}:/workspace" `
  -v "${PUB_KEY_PATH}:/root/.ssh/authorized_keys:ro" `
  -w /workspace `
  -p ${Port}:22 `
  $Image

# 4. 🧪 可选：测试连接（简单验证端口是否监听）
Start-Sleep -Seconds 2
$test = $(try { Test-NetConnection localhost -Port $Port -WarningAction SilentlyContinue } catch { $null })
if ($test -and $test.TcpTestSucceeded) {
    Write-Host "✅ 容器 SSH 服务已就绪！" -ForegroundColor Green
} else {
    Write-Host "⚠️  容器可能启动较慢，请稍后手动测试连接。" -ForegroundColor Yellow
}

# 5. 📋 输出连接指南
Write-Host "========================================" -ForegroundColor Green
Write-Host "   🎉 环境就绪！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "📂 容器内代码路径: /workspace"
Write-Host "   (对应宿主机路径: $CODE_ROOT)"
Write-Host ""
Write-Host "🔧 使用的镜像: $Image"
Write-Host ""
Write-Host "🔌 请在 IDE 中配置 SSH Remote 连接:" -ForegroundColor White
Write-Host "   Host: localhost" -ForegroundColor Yellow
Write-Host "   Port: $Port" -ForegroundColor Yellow
Write-Host "   User: root" -ForegroundColor Yellow
Write-Host "   IdentityFile: $PRIV_KEY_PATH" -ForegroundColor Yellow
Write-Host ""
Write-Host "👉 连接成功后，请在 IDE 中打开文件夹:" -ForegroundColor White
Write-Host "   /workspace/YourProject" -ForegroundColor Yellow
Write-Host "========================================"