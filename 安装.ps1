<#
.SYNOPSIS
    安装 over the hill - Mini Map（右上角圆形小地图）。
.DESCRIPTION
    需要游戏目录里已经安装 BepInEx 6（Unity IL2CPP）。
    本脚本只复制插件和默认配置，不会修改游戏本体，也不会安装/删除 BepInEx。
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\安装.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\安装.ps1 -GamePath "D:\SteamLibrary\steamapps\common\over the hill"
#>
param(
    [string]$GamePath = '',
    [switch]$ResetConfig
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginDll = Join-Path $Root 'BepInEx\plugins\OverTheHill.MiniMap.dll'
$DefaultConfig = Join-Path $Root 'BepInEx\config\com.dsh.overthehill.minimap.cfg'
$LoaderZip = Join-Path $Root 'Loader\BepInEx-Unity.IL2CPP-win-x64-6.0.0-be.789.zip'
$UnityLibsZip = Join-Path $Root 'Loader\unity-libs\6000.0.75.zip'

function Write-Step([string]$Text) { Write-Host "==> $Text" -ForegroundColor Cyan }

function Find-GamePath {
    if ($GamePath) {
        $exe = Join-Path $GamePath 'over the hill.exe'
        if (-not (Test-Path $exe)) { throw "指定目录里没有 over the hill.exe：$GamePath" }
        return (Resolve-Path $GamePath).Path
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        $steamPath = (Get-ItemProperty $key -ErrorAction SilentlyContinue).SteamPath
        if (-not $steamPath) { continue }
        $candidates.Add((Join-Path $steamPath 'steamapps\common\over the hill'))
        $vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            $text = Get-Content $vdf -Raw
            foreach ($m in [regex]::Matches($text, '"path"\s*"([^"]+)"')) {
                $lib = $m.Groups[1].Value -replace '\\\\', '\'
                $candidates.Add((Join-Path $lib 'steamapps\common\over the hill'))
            }
        }
    }

    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c 'over the hill.exe')) { return (Resolve-Path $c).Path }
    }

    throw '没有自动找到游戏目录。请用 -GamePath "…\steamapps\common\over the hill" 指定。'
}

if (-not (Test-Path $PluginDll)) { throw "安装包里缺少插件：$PluginDll" }
if (-not (Test-Path $DefaultConfig)) { throw "安装包里缺少默认配置：$DefaultConfig" }

$running = Get-Process -Name 'over the hill' -ErrorAction SilentlyContinue
if ($running) {
    throw '游戏正在运行。请先完全退出游戏，再运行安装脚本；装好后重新启动游戏。'
}

$game = Find-GamePath
Write-Step "游戏目录：$game"

$bepInExCore = Join-Path $game 'BepInEx\core\BepInEx.Core.dll'
$bepInExIl2Cpp = Join-Path $game 'BepInEx\core\BepInEx.Unity.IL2CPP.dll'
$hasBepInEx = (Test-Path $bepInExCore) -and (Test-Path $bepInExIl2Cpp)
if (-not $hasBepInEx) {
    if ((Test-Path $bepInExCore) -and -not (Test-Path $bepInExIl2Cpp)) {
        throw '检测到旧版/不完整的 BepInEx（缺少 BepInEx.Unity.IL2CPP.dll）。请先清理旧 BepInEx，再使用完整包。'
    }

    if (-not (Test-Path $LoaderZip)) {
        throw '没有检测到 BepInEx 6（IL2CPP）。当前是 Lite 包，请先安装 BepInEx 6 Unity IL2CPP；或下载带 Loader 的 Full 懒人包。'
    }

    Write-Step '没有检测到 BepInEx，正在解压包内自带的加载器……'
    Expand-Archive -LiteralPath $LoaderZip -DestinationPath $game -Force

    $hasBepInEx = (Test-Path $bepInExCore) -and (Test-Path $bepInExIl2Cpp)
    if (-not $hasBepInEx) {
        throw '自带加载器解压后仍没有找到 BepInEx 6，请检查游戏目录权限或压缩包是否完整。'
    }
}
else {
    Write-Step '检测到已安装 BepInEx 6，跳过加载器安装。'
}

if (Test-Path $UnityLibsZip) {
    $libsDir = Join-Path $game 'BepInEx\unity-libs'
    New-Item -ItemType Directory -Force -Path $libsDir | Out-Null
    $libsTarget = Join-Path $libsDir '6000.0.75.zip'
    if (-not (Test-Path $libsTarget)) {
        Copy-Item $UnityLibsZip $libsTarget -Force
        Write-Step '已放入 Unity 基础库（离线生成 IL2CPP 程序集）。'
    }
}

$pluginDir = Join-Path $game 'BepInEx\plugins'
New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
Copy-Item $PluginDll $pluginDir -Force
Write-Step "已安装插件：$pluginDir\OverTheHill.MiniMap.dll"

$configDir = Join-Path $game 'BepInEx\config'
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
$configPath = Join-Path $configDir 'com.dsh.overthehill.minimap.cfg'
if ($ResetConfig -or -not (Test-Path $configPath)) {
    Copy-Item $DefaultConfig $configPath -Force
    Write-Step '已写入默认配置（右上角 240px、半径 300m、显示图标和迷雾、退出备份存档）。'
}
else {
    Write-Step '配置已存在，保留原设置（如需恢复默认，加 -ResetConfig）。'
}

Write-Host ''
Write-Host '安装完成！' -ForegroundColor Green
Write-Host '请从 Steam 正常启动游戏。游戏正在运行时不会加载新 Mod。'
if ($hasBepInEx -and (Test-Path $LoaderZip) -and -not (Test-Path (Join-Path $game 'BepInEx\interop\Assembly-CSharp.dll'))) {
    Write-Host '首次启动需要生成 IL2CPP 程序集，可能等待 1～3 分钟，请不要强制关闭。' -ForegroundColor Yellow
}
Write-Host "日志：$game\BepInEx\LogOutput.log"
Write-Host '正常应看到：Mini Map v1.3.0 loaded / 小地图 UI 已创建 / 小地图已就绪。'
Write-Host '如果小地图前后方向反了，把配置里的 FlipMapY 改成 true。'
Write-Host '正常退出游戏后，存档会备份到 文档\My Games\over the hill\Backups。'
