#Requires -Version 5.1
<#
.SYNOPSIS
  SuperBookToolsApp 経由で ConvertPdf を実行する。

.PARAMETER SrcDir
  入力 PDF を再帰列挙するルートディレクトリ。

.PARAMETER Rest
  /dst:... や /ocr:yes など ConvertPdf と同じ引数（可変長）。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $SrcDir,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Rest
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$exeRelease = Join-Path $repoRoot 'SuperBookToolsApp\bin\Release\net6.0\SuperBookToolsApp.exe'
$exeDebug = Join-Path $repoRoot 'SuperBookToolsApp\bin\Debug\net6.0\SuperBookToolsApp.exe'

$tail = @($Rest) | ForEach-Object { $_ }
$allParts = @('ConvertPdf', $SrcDir) + $tail
$cmdLine = $allParts -join ' '

Write-Host "[*] $cmdLine" -ForegroundColor Cyan

if (Test-Path -LiteralPath $exeRelease) {
    & $exeRelease /cmd $cmdLine
    exit $LASTEXITCODE
}
if (Test-Path -LiteralPath $exeDebug) {
    & $exeDebug /cmd $cmdLine
    exit $LASTEXITCODE
}

throw "SuperBookToolsApp.exe が見つかりません。先にビルドしてください: $exeRelease または $exeDebug"
