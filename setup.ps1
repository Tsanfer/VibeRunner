<#
.SYNOPSIS
    VibeRunner 开发环境管理脚本
.DESCRIPTION
    1. 构建/检查 VibeRunner 镜像。
    2. 启动容器，将 C:\Code 挂载到容器的 /workspace。
    3. 输出 SSH 连接信息供 IDE 使用。
#>

param(
    [string]$UbuntuVer = "24.04",
    [string]$NodeVer = "24",
    [int]$Port = 2222
)

# ================= 路径定义 =================
# 当前目录 (C:\Code\VibeRunner)
$ENV_ROOT = $PSScriptRoot
# 上级目录 (C:\Code)
$CODE_ROOT = Split-Path $ENV_ROOT -Parent

$IMAGE_NAME = "vibe-runner"
$CONTAINER_NAME = "vibe-runner"
# ===========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   VibeRunner 开发环境管理" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. 🔑 检查 SSH 密钥
$SSH_DIR = "$env:USERPROFILE\.ssh"
$PRIV_KEY_PATH = "$SSH_DIR\id_rsa"
$PUB_KEY_PATH = "$SSH_DIR\id_rsa.pub"

if (!(Test-Path $PRIV_KEY_PATH)) {
    Write-Host "⚠️  未检测到 SSH 密钥，正在生成..." -ForegroundColor Yellow
    ssh-keygen -t rsa -b 4096 -f $PRIV_KEY_PATH -N "" | Out-Null
    Write-Host "✅ 密钥已生成。" -ForegroundColor Green
}

# 2. 🔨 构建镜像 (总是构建，确保 Dockerfile 更改被应用)
Set-Location $ENV_ROOT
Copy-Item -Path $PUB_KEY_PATH -Destination "$ENV_ROOT\id_rsa.pub" -Force

Write-Host "🏗️  正在构建镜像 [$IMAGE_NAME] (确保 Dockerfile 更改被应用)..." -ForegroundColor Cyan

# 构建 podman 命令参数
$buildArgs = "--format docker --build-arg UBUNTU_VER=$UbuntuVer --build-arg NODE_VER=$NodeVer"
if (-not [string]::IsNullOrEmpty($NpmVer)) {
    $buildArgs += " --build-arg NPM_VER=$NpmVer"
}

# 执行构建命令
$buildCommand = "podman build $buildArgs -t $IMAGE_NAME ."
Invoke-Expression $buildCommand

# 清理构建临时文件
Remove-Item "$ENV_ROOT\id_rsa.pub" -Force

# 3. 🚀 启动容器
# 逻辑：如果容器在运行 -> 提示信息
#       如果容器停止了 -> 重启
#       如果容器不存在 -> 创建并运行

$containerExists = podman ps -a -q -f name=$CONTAINER_NAME
$isRunning = podman ps -q -f name=$CONTAINER_NAME

# 检查并移除旧容器（如果存在）
if ($containerExists) {
    Write-Host "🔄 移除旧容器 [$CONTAINER_NAME]..." -ForegroundColor Yellow
    podman rm -f $CONTAINER_NAME
}

# 创建并启动新容器
Write-Host "🚀 正在创建并启动新容器..." -ForegroundColor Cyan
podman run -d --name $CONTAINER_NAME `
  -v ${CODE_ROOT}:/workspace `
  -w /workspace `
  -p ${Port}:22 `
  $IMAGE_NAME

# 4. 📋 输出连接指南
Write-Host "========================================" -ForegroundColor Green
Write-Host "   🎉 环境就绪！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "📂 容器内代码路径: /workspace"
Write-Host "   (对应宿主机路径: $CODE_ROOT)"
Write-Host ""
Write-Host "🔌 请在 IDE 中配置 SSH Remote 连接:" -ForegroundColor White
Write-Host "   Host: localhost" -ForegroundColor Yellow
Write-Host "   Port: $Port" -ForegroundColor Yellow
Write-Host "   User: root" -ForegroundColor Yellow
Write-Host ""
Write-Host "👉 连接成功后，请在 IDE 中打开文件夹:" -ForegroundColor White
Write-Host "   /workspace/ProjectA (或你的其他项目名)" -ForegroundColor Yellow
Write-Host "========================================"
