$ErrorActionPreference = "Stop"
$SkillDir = (Resolve-Path (Split-Path -Parent $MyInvocation.MyCommand.Path)).Path
$VenvDir = Join-Path $SkillDir ".venv"
$UserSkillDir = Join-Path $HOME ".agents\skills\wechat-decrypt"
Write-Host "=== WeChat Decrypt 安装（Windows / Codex）==="

python -c "import sys; raise SystemExit(sys.version_info < (3, 10))"
if ($LASTEXITCODE -ne 0) { throw "需要 Python 3.10+" }

Write-Host "[1/5] 创建隔离 Python 环境..."
python -m venv $VenvDir
$Python = Join-Path $VenvDir "Scripts\python.exe"
& $Python -m pip install --upgrade pip

Write-Host "[2/5] 安装 Python 依赖..."
& $Python -m pip install "mcp[cli]>=1.0" frida pycryptodome pilk faster-whisper zstandard

Write-Host "[3/5] 注册用户 Skill..."
$Parent = Split-Path -Parent $UserSkillDir
New-Item -ItemType Directory -Force -Path $Parent | Out-Null
if (Test-Path $UserSkillDir) {
    $Existing = (Resolve-Path $UserSkillDir).Path.TrimEnd("\")
    if ($Existing -eq $SkillDir.TrimEnd("\")) {
        Write-Host "  已链接: $UserSkillDir"
    } else {
        Write-Warning "$UserSkillDir 已存在，未覆盖。"
    }
} else {
    New-Item -ItemType Junction -Path $UserSkillDir -Target $SkillDir | Out-Null
    Write-Host "  已链接: $UserSkillDir -> $SkillDir"
}

Write-Host "[4/5] 注册 Codex MCP Server..."
$Server = Join-Path $SkillDir "server.py"
if (Get-Command codex -ErrorAction SilentlyContinue) {
    codex mcp remove wechat 2>$null
    codex mcp add wechat -- $Python $Server
    if ($LASTEXITCODE -ne 0) { throw "Codex MCP 注册失败" }
} else {
    Write-Warning "未找到 Codex CLI；可先用 query.py，安装 Codex 后重跑 setup.ps1。"
}

Write-Host "[5/5] 验证基础依赖..."
& $Python -c "import mcp, frida, Crypto, pilk, faster_whisper, zstandard; print('dependencies OK')"

Write-Host ""
Write-Host "=== 完成。提取流程 ==="
Write-Host "  1. 登录微信"
Write-Host "  2. & '$Python' scripts\windows\extract_raw_key.py"
Write-Host "  3. & '$Python' scripts\windows\decrypt_all.py"
Write-Host "  4. & '$Python' scripts\common\doctor.py"
Write-Host "  5. 重启 Codex"
