#!/bin/bash

# AuriMyth Foundation Kit - PyPI 发布脚本（使用 uv）
#
# 使用方法:
#   ./publish.sh [test|prod]
#
# 参数说明:
#   test: 发布到测试 PyPI (https://test.pypi.org)
#   prod: 发布到正式 PyPI (https://pypi.org) - 默认
#
# 版本管理:
#   版本号通过 Git 标签自动管理（hatch-vcs）
#   创建新版本: git tag v0.1.0 && git push --tags
#
# Token 配置 (PyPI 已不支持密码登录，必须使用 API Token):
#   方式 1: 环境变量 UV_PUBLISH_TOKEN
#   方式 2: keyring set https://upload.pypi.org/legacy/ __token__

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认参数
TARGET="${1:-prod}"

# 打印函数
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查 uv
check_uv() {
    if ! command -v uv &> /dev/null; then
        error "未找到 uv，请先安装:"
        echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
    success "uv $(uv --version | head -1)"
}

# 检查 Git 状态
check_git() {
    info "检查 Git 状态..."
    
    # 检查是否在 Git 仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "当前目录不是 Git 仓库"
        exit 1
    fi
    
    # 获取当前版本（从 git describe）
    if git describe --tags --always > /dev/null 2>&1; then
        VERSION=$(git describe --tags --always --dirty)
        info "当前版本: ${CYAN}${VERSION}${NC}"
    else
        warning "未找到 Git 标签，将使用 0.0.0.devN 格式版本"
        VERSION="0.0.0.dev$(git rev-list --count HEAD)"
        info "开发版本: ${CYAN}${VERSION}${NC}"
    fi
    
    # 检查是否有未提交的更改
    if [[ -n $(git status --porcelain) ]]; then
        warning "存在未提交的更改，版本号将带有 +dirty 后缀"
    fi
}

# 清理构建产物
clean() {
    info "清理旧的构建文件..."
    rm -rf build/ dist/ *.egg-info aurimyth/*.egg-info aurimyth/foundation_kit/_version.py
    success "清理完成"
}

# 构建包
build() {
    info "构建包..."
    uv build
    
    # 显示构建产物
    echo ""
    info "构建产物:"
    ls -lh dist/
    success "构建完成"
}

# 检查构建产物
check() {
    info "检查构建产物..."
    
    if [ ! -d "dist" ] || [ -z "$(ls -A dist)" ]; then
        error "dist/ 目录不存在或为空"
        exit 1
    fi
    
    # 使用 uvx 运行 twine check
    uvx twine check dist/*
    success "检查通过"
}

# 配置 Token
setup_token() {
    if [ -z "$UV_PUBLISH_TOKEN" ]; then
        info "Token 配置方式 (PyPI 必须使用 API Token):"
        echo "  1. 环境变量: export UV_PUBLISH_TOKEN='pypi-xxxx...'"
        echo "  2. keyring: keyring set https://upload.pypi.org/legacy/ __token__"
        echo ""
        info "获取 Token: https://pypi.org/manage/account/token/"
    fi
}

# 发布
publish() {
    local pypi_name pypi_url
    
    if [ "$TARGET" = "test" ]; then
        pypi_name="测试 PyPI (test.pypi.org)"
        pypi_url="https://test.pypi.org/legacy/"
    else
        pypi_name="正式 PyPI (pypi.org)"
        pypi_url=""
    fi
    
    echo ""
    echo "=========================================="
    warning "即将发布到 $pypi_name"
    echo "=========================================="
    echo ""
    info "构建产物:"
    ls -lh dist/
    echo ""
    
    read -p "确认发布? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        info "已取消发布"
        exit 0
    fi
    
    info "开始上传..."
    if [ "$TARGET" = "test" ]; then
        uv publish --publish-url "$pypi_url" --username __token__
    else
        uv publish --username __token__
    fi
    
    success "发布完成！"
    echo ""
    if [ "$TARGET" = "test" ]; then
        echo "测试安装命令:"
        echo "  uv add --index-url https://test.pypi.org/simple/ aurimyth-foundation-kit"
    else
        echo "安装命令:"
        echo "  uv add aurimyth-foundation-kit"
    fi
}

# 显示帮助
show_help() {
    echo "AuriMyth Foundation Kit - PyPI 发布工具"
    echo ""
    echo "使用方法: ./publish.sh [test|prod]"
    echo ""
    echo "参数:"
    echo "  test    发布到测试 PyPI"
    echo "  prod    发布到正式 PyPI (默认)"
    echo ""
    echo "版本管理 (通过 Git 标签):"
    echo "  git tag v0.1.0          创建标签"
    echo "  git push --tags         推送标签"
    echo "  git tag -d v0.1.0       删除本地标签"
    echo ""
echo "Token 配置 (PyPI 必须使用 API Token):"
    echo "  export UV_PUBLISH_TOKEN='pypi-xxxx...'              环境变量"
    echo "  keyring set https://upload.pypi.org/legacy/ __token__  keyring 方式"
    echo ""
    echo "获取 Token: https://pypi.org/manage/account/token/"
}

# 主流程
main() {
    # 帮助信息
    if [ "$TARGET" = "-h" ] || [ "$TARGET" = "--help" ]; then
        show_help
        exit 0
    fi
    
    # 验证参数
    if [ "$TARGET" != "test" ] && [ "$TARGET" != "prod" ]; then
        error "无效参数: $TARGET"
        echo "使用 ./publish.sh --help 查看帮助"
        exit 1
    fi
    
    echo ""
    echo "=========================================="
    echo "  AuriMyth Foundation Kit - PyPI 发布"
    echo "  使用 uv + hatch-vcs"
    echo "=========================================="
    echo ""
    
    if [ "$TARGET" = "test" ]; then
        info "目标: ${YELLOW}测试 PyPI${NC}"
    else
        info "目标: ${GREEN}正式 PyPI${NC}"
    fi
    echo ""
    
    check_uv
    check_git
    echo ""
    
    clean
    echo ""
    
    build
    echo ""
    
    check
    echo ""
    
    setup_token
    publish
    
    echo ""
    success "发布流程完成！"
}

main
