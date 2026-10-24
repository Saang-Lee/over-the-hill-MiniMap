# ASCII-named wrapper so .bat launchers work on all Windows code pages.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '安装.ps1') @args
