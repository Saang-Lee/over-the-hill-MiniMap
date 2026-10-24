<#
.SYNOPSIS
    卸载 over the hill - Mini Map。
.DESCRIPTION
    只删除本 Mod 的插件；默认保留配置文件。不会删除 BepInEx 或其它 Mod。
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\卸载.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\卸载.ps1 -RemoveConfig
#>
param(
    [string]$GamePath = '',
    [switch]$RemoveConfig
)

$ErrorActionPreference = 'Stop'

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

$running = Get-Process -Name 'over the hill' -ErrorAction SilentlyContinue
if ($running) { throw '游戏正在运行。请先完全退出游戏，再运行卸载脚本。' }

$game = Find-GamePath
$plugin = Join-Path $game 'BepInEx\plugins\OverTheHill.MiniMap.dll'
if (Test-Path $plugin) {
    Remove-Item $plugin -Force
    Write-Step "已删除插件：$plugin"
}
else {
    Write-Step '插件文件不存在，可能已经卸载。'
}

if ($RemoveConfig) {
    $config = Join-Path $game 'BepInEx\config\com.dsh.overthehill.minimap.cfg'
    if (Test-Path $config) {
        Remove-Item $config -Force
        Write-Step "已删除配置：$config"
    }
}

Write-Host ''
Write-Host '卸载完成。BepInEx 和其它 Mod 未被修改。' -ForegroundColor Green
