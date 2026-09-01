#!/bin/bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd -P)"
VENV_DIR="$SKILL_DIR/.venv"
USER_SKILL_DIR="$HOME/.agents/skills/wechat-decrypt"

if [[ "$(uname)" != "Darwin" ]]; then
    echo "此脚本仅适用于 macOS。Windows 请用: powershell -File setup.ps1"
    exit 1
fi

echo "=== WeChat Decrypt 安装（macOS / Codex）==="
echo "目录: $SKILL_DIR"
echo ""

BOOTSTRAP_PYTHON="$(command -v python3 || true)"
if [ -z "$BOOTSTRAP_PYTHON" ]; then
    echo "ERROR: 需要 Python 3.10+"
    exit 1
fi
if ! "$BOOTSTRAP_PYTHON" -c 'import sys; raise SystemExit(sys.version_info < (3, 10))'; then
    echo "ERROR: 需要 Python 3.10+"
    exit 1
fi

echo "[1/6] 创建隔离 Python 环境..."
"$BOOTSTRAP_PYTHON" -m venv "$VENV_DIR"
PYTHON="$VENV_DIR/bin/python"
echo "  $PYTHON ($("$PYTHON" --version))"

echo "[2/6] 检查 SQLCipher..."
if ! command -v sqlcipher &>/dev/null; then
    if ! command -v brew &>/dev/null; then
        echo "ERROR: 未找到 sqlcipher 或 Homebrew。先安装 Homebrew，再重跑 setup.sh。"
        exit 1
    fi
    brew install sqlcipher
fi
echo "  sqlcipher: $(command -v sqlcipher)"

echo "[3/6] 安装 Python 依赖..."
"$PYTHON" -m pip install --upgrade pip
"$PYTHON" -m pip install "mcp[cli]>=1.0" frida-tools zstandard cryptography requests pilk
if [ "$(uname -m)" = "arm64" ]; then
    "$PYTHON" -m pip install mlx-whisper
else
    echo "  Intel Mac 跳过 mlx-whisper；查询和普通导出仍可用。"
fi

echo "[4/6] 注册用户 Skill..."
mkdir -p "$(dirname "$USER_SKILL_DIR")"
if [ -e "$USER_SKILL_DIR" ] || [ -L "$USER_SKILL_DIR" ]; then
    if "$BOOTSTRAP_PYTHON" -c 'import os,sys; sys.exit(0 if os.path.samefile(sys.argv[1], sys.argv[2]) else 1)' "$USER_SKILL_DIR" "$SKILL_DIR" 2>/dev/null; then
        echo "  已链接: $USER_SKILL_DIR"
    else
        echo "  WARN: $USER_SKILL_DIR 已存在，未覆盖。"
    fi
else
    ln -s "$SKILL_DIR" "$USER_SKILL_DIR"
    echo "  已链接: $USER_SKILL_DIR -> $SKILL_DIR"
fi

echo "[5/6] 注册 Codex MCP Server..."
if command -v codex &>/dev/null; then
    codex mcp remove wechat >/dev/null 2>&1 || true
    codex mcp add wechat -- "$PYTHON" "$SKILL_DIR/server.py"
    echo "  Codex MCP 已注册"
else
    echo "  WARN: 未找到 Codex CLI；可先用 query.py，安装 Codex 后重跑 setup.sh。"
fi

echo "[6/6] 验证基础依赖..."
"$PYTHON" -c "import mcp, frida, zstandard, cryptography, pilk; print('  dependencies OK')"

echo ""
echo "=== 安装完成 ==="
echo "后续步骤:"
echo "  1. sudo codesign --force --deep --sign - /Applications/WeChat.app"
echo "  2. bash scripts/macos/extract_key.sh"
echo "  3. $PYTHON scripts/common/doctor.py"
echo "  4. 重启 Codex"
echo ""
echo "只在提取密钥时重签名；完成后按 references/macos.md 恢复官方签名。"
