# ASCII-named wrapper so .bat launchers work on all Windows code pages.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '卸载.ps1') @args
