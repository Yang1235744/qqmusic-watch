# QQ音乐手表版 - 构建打包脚本
# 前提：已安装 DevEco Studio 并配置好 HarmonyOS SDK
# 使用：右键 -> 使用 PowerShell 运行，或在 DevEco Studio 终端执行

$ErrorActionPreference = "Stop"

# 项目根目录（脚本所在目录）
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QQ音乐手表版 - 构建打包脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "项目路径: $ProjectRoot"
Write-Host ""

# 检查是否存在签名文件
$signDir = Join-Path $ProjectRoot "sign"
$hasP12 = Test-Path (Join-Path $signDir "qqmusic_watch.p12")
$hasCer = Test-Path (Join-Path $signDir "qqmusic_watch.cer")
$hasP7b = Test-Path (Join-Path $signDir "qqmusic_watch.p7b")

if (-not ($hasP12 -and $hasCer -and $hasP7b)) {
    Write-Host "[警告] 未检测到完整的签名文件" -ForegroundColor Yellow
    Write-Host "  需要: qqmusic_watch.p12, qqmusic_watch.cer, qqmusic_watch.p7b"
    Write-Host "  请将签名文件放入 sign 目录后再进行 release 构建"
    Write-Host "  当前可进行 debug 构建（使用自动签名）"
    Write-Host ""
}

# 查找 hvigorw
$hvigorw = Join-Path $ProjectRoot "hvigorw.bat"
if (-not (Test-Path $hvigorw)) {
    Write-Host "[错误] 未找到 hvigorw.bat，请在 DevEco Studio 中打开项目后重试" -ForegroundColor Red
    Write-Host "  DevEco Studio 会自动生成 hvigorw 等构建脚本"
    Read-Host "按回车键退出"
    exit 1
}

# 选择构建模式
Write-Host "请选择构建模式：" -ForegroundColor Green
Write-Host "  1. Debug 构建（调试用，自动签名）"
Write-Host "  2. Release 构建（发布用，需手动签名）"
Write-Host "  3. 清理构建产物"
$choice = Read-Host "请输入选项 (1/2/3)"

switch ($choice) {
    "1" {
        Write-Host "开始 Debug 构建..." -ForegroundColor Cyan
        & $hvigorw assembleHap --mode module -p product=default --no-daemon
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "[成功] Debug 构建完成！" -ForegroundColor Green
            $hapPath = Get-ChildItem -Path (Join-Path $ProjectRoot "entry\build\default\outputs\default") -Filter "*.hap" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hapPath) {
                Write-Host "HAP 文件: $($hapPath.FullName)" -ForegroundColor Green
            }
        } else {
            Write-Host "[失败] Debug 构建失败，错误码: $LASTEXITCODE" -ForegroundColor Red
        }
    }
    "2" {
        if (-not ($hasP12 -and $hasCer -and $hasP7b)) {
            Write-Host "[错误] 缺少签名文件，无法进行 Release 构建" -ForegroundColor Red
            Read-Host "按回车键退出"
            exit 1
        }
        Write-Host "开始 Release 构建..." -ForegroundColor Cyan
        & $hvigorw assembleHap --mode module -p product=default buildMode=release --no-daemon
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "[成功] Release 构建完成！" -ForegroundColor Green
            $hapPath = Get-ChildItem -Path (Join-Path $ProjectRoot "entry\build\default\outputs\default") -Filter "*.hap" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hapPath) {
                Write-Host "HAP 文件: $($hapPath.FullName)" -ForegroundColor Green
                Write-Host "此文件可用于上架腕连社区" -ForegroundColor Green
            }
        } else {
            Write-Host "[失败] Release 构建失败，错误码: $LASTEXITCODE" -ForegroundColor Red
        }
    }
    "3" {
        Write-Host "清理构建产物..." -ForegroundColor Cyan
        & $hvigorw clean --no-daemon
        Write-Host "[完成] 清理完成" -ForegroundColor Green
    }
    default {
        Write-Host "无效选项" -ForegroundColor Red
    }
}

Write-Host ""
Read-Host "按回车键退出"
