#Requires -Version 5.1
# Setup: populate external_tools/external_tools/image_tools (see repo external_tools/.../image_tools/README.md).
[CmdletBinding()]
param(
    [switch] $AllPortable,
    [switch] $RealEsrgan,
    [switch] $Yomitoku,
    [switch] $TessData,
    [string] $PythonExe = '',
    [string] $TorchIndexUrl = '',
    [switch] $SkipGhostscriptInstall
)

$ErrorActionPreference = 'Stop'

if (-not $PSScriptRoot -and $PSCommandPath) {
    $PSScriptRoot = Split-Path -Parent -LiteralPath $PSCommandPath
}
if (-not $PSScriptRoot) {
    throw 'PSScriptRoot is empty; use: powershell -File Setup-ExternalTools.ps1'
}

# This script lives in repo/setup/image_tools
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$ImageTools = Join-Path $RepoRoot 'external_tools\external_tools\image_tools'
$Versions = & (Join-Path $PSScriptRoot 'ExternalTools-Versions.ps1')
if (-not $TorchIndexUrl) { $TorchIndexUrl = $Versions.TorchIndexUrlDefault }

if ([string]::IsNullOrWhiteSpace($RepoRoot) -or [string]::IsNullOrWhiteSpace($ImageTools)) {
    throw "Invalid paths: PSScriptRoot='$PSScriptRoot' RepoRoot='$RepoRoot' ImageTools='$ImageTools'"
}

Set-StrictMode -Version 2.0

function Ensure-Dir([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function Get-DownloadPath([string] $Name) {
    $dir = Join-Path $env:TEMP 'DN_SuperBook_ext_dl'
    Ensure-Dir $dir
    Join-Path $dir $Name
}

function Invoke-Download([string] $Uri, [string] $OutFile) {
    Write-Host "[dl] $Uri" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
}

function Expand-Zip([string] $ZipPath, [string] $DestDir) {
    Ensure-Dir $DestDir
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $DestDir -Force
}

function Install-ImageMagickPortable {
    $dest = Join-Path $ImageTools $Versions.ImageMagickExtractDir
    if (Test-Path (Join-Path $dest 'magick.exe')) {
        Write-Host "[skip] ImageMagick: already present: $dest" -ForegroundColor Yellow
        return
    }
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    $zip = Get-DownloadPath 'imagemagick_portable.zip'
    Invoke-Download -Uri $Versions.ImageMagickZipUrl -OutFile $zip
    $stage = Join-Path $env:TEMP 'DN_SuperBook_im_stage'
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    Ensure-Dir $stage
    Expand-Zip -ZipPath $zip -DestDir $stage
    $top = Get-ChildItem -LiteralPath $stage -Directory | Select-Object -First 1
    if (-not $top) { throw "ImageMagick zip: no top-level directory" }
    Move-Item -LiteralPath $top.FullName -Destination $dest
    Write-Host "[ok] ImageMagick -> $dest" -ForegroundColor Green
}

function Install-GhostscriptIntoImageMagick {
    $imDir = Join-Path $ImageTools $Versions.ImageMagickExtractDir
    if (-not (Test-Path (Join-Path $imDir 'magick.exe'))) {
        throw "ImageMagick folder missing magick.exe. Run -AllPortable (ImageMagick step) first."
    }
    $gsExe = Join-Path $imDir 'gswin64c.exe'
    if (Test-Path -LiteralPath $gsExe) {
        Write-Host "[skip] Ghostscript binaries already beside ImageMagick" -ForegroundColor Yellow
        return
    }
    if (-not $SkipGhostscriptInstall) {
        $setup = Get-DownloadPath 'gs10051w64.exe'
        Invoke-Download -Uri $Versions.GhostscriptInstallerUrl -OutFile $setup
        Write-Host "[run] Ghostscript installer (silent /S). Administrator rights may be required." -ForegroundColor Cyan
        $p = Start-Process -FilePath $setup -ArgumentList '/S' -Wait -PassThru
        if ($p.ExitCode -ne 0) { Write-Warning "Installer exit code $($p.ExitCode)" }
    }
    $gsRoot = 'C:\Program Files\gs'
    if (-not (Test-Path -LiteralPath $gsRoot)) { throw "Ghostscript not found under $gsRoot. Install manually or run installer as admin." }
    $bin = Get-ChildItem -Path $gsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Join-Path $_.FullName 'bin'
    } | Where-Object { Test-Path (Join-Path $_ 'gswin64c.exe') } | Select-Object -First 1
    if (-not $bin) { throw "gswin64c.exe not found under $gsRoot" }
    foreach ($f in @('gsdll64.dll', 'gsdll64.lib', 'gswin64.exe', 'gswin64c.exe')) {
        $src = Join-Path $bin $f
        if (-not (Test-Path -LiteralPath $src)) { throw "Missing $src" }
        Copy-Item -LiteralPath $src -Destination (Join-Path $imDir $f) -Force
    }
    Write-Host "[ok] Ghostscript binaries copied to $imDir" -ForegroundColor Green
}

function Install-Qpdf {
    $dest = Join-Path $ImageTools 'QPDF'
    if (Test-Path (Join-Path $dest 'bin\qpdf.exe')) {
        Write-Host "[skip] QPDF already present" -ForegroundColor Yellow
        return
    }
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    $zip = Get-DownloadPath 'qpdf.zip'
    Invoke-Download -Uri $Versions.QpdfZipUrl -OutFile $zip
    $stage = Join-Path $env:TEMP 'DN_SuperBook_qpdf_stage'
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    Expand-Zip -ZipPath $zip -DestDir $stage
    $inner = Join-Path $stage $Versions.QpdfInnerTopDir
    if (-not (Test-Path -LiteralPath $inner)) { throw "qpdf zip layout unexpected" }
    Move-Item -LiteralPath $inner -Destination $dest
    Write-Host "[ok] QPDF -> $dest" -ForegroundColor Green
}

function Install-ExifTool {
    $dest = Join-Path $ImageTools $Versions.ExifToolExtractDir
    if (Test-Path (Join-Path $dest 'exiftool.exe')) {
        Write-Host "[skip] ExifTool already present" -ForegroundColor Yellow
        return
    }
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    $zip = Get-DownloadPath 'exiftool.zip'
    Invoke-Download -Uri $Versions.ExifToolZipUrl -OutFile $zip
    $stage = Join-Path $env:TEMP 'DN_SuperBook_exif_stage'
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    Expand-Zip -ZipPath $zip -DestDir $stage
    $top = Get-ChildItem -LiteralPath $stage -Directory | Select-Object -First 1
    if ($top) {
        Move-Item -LiteralPath $top.FullName -Destination $dest
    }
    elseif (Test-Path (Join-Path $stage 'exiftool.exe')) {
        New-Item -ItemType Directory -Path $dest | Out-Null
        Move-Item -Path (Join-Path $stage '*') -Destination $dest
    }
    else {
        throw "ExifTool zip: unexpected layout (no folder and no exiftool.exe)"
    }
    Write-Host "[ok] ExifTool -> $dest" -ForegroundColor Green
}

function Install-PdfcpuIfMissing {
    $destDir = Join-Path $ImageTools 'pdfcpu'
    $exe = Join-Path $destDir 'pdfcpu.exe'
    if (Test-Path -LiteralPath $exe) {
        Write-Host "[skip] pdfcpu.exe already present (repository copy)" -ForegroundColor Yellow
        return
    }
    Ensure-Dir $destDir
    $stage = Join-Path $env:TEMP 'DN_SuperBook_pdfcpu_stage'
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    Ensure-Dir $stage
    $zip = Get-DownloadPath 'pdfcpu.zip'
    Invoke-Download -Uri $Versions.PdfcpuZipUrl -OutFile $zip
    Expand-Zip -ZipPath $zip -DestDir $stage
    if (Test-Path (Join-Path $stage 'pdfcpu.exe')) {
        Move-Item -Path (Join-Path $stage 'pdfcpu.exe') -Destination (Join-Path $destDir 'pdfcpu.exe') -Force
    }
    else {
        $sub = Get-ChildItem -LiteralPath $stage -Directory | Select-Object -First 1
        if (-not $sub -or -not (Test-Path (Join-Path $sub.FullName 'pdfcpu.exe'))) {
            throw "pdfcpu zip: pdfcpu.exe not found"
        }
        Copy-Item -LiteralPath (Join-Path $sub.FullName 'pdfcpu.exe') -Destination (Join-Path $destDir 'pdfcpu.exe') -Force
    }
    Write-Host "[ok] pdfcpu -> $destDir" -ForegroundColor Green
}

function Resolve-PythonExe {
    if ($PythonExe -and (Test-Path -LiteralPath $PythonExe)) { return $PythonExe }
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) {
        $v = & py -3 -c "import sys; print(sys.executable)" 2>$null
        if ($v -and (Test-Path -LiteralPath $v.Trim())) { return $v.Trim() }
    }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) { return $python.Source }
    throw "Python not found. Install Python 3.10+ and/or set -PythonExe."
}

function Install-RealEsrganStack {
    $py = Resolve-PythonExe
    $rsRepoDir = Join-Path $ImageTools 'RealEsrgan\RealEsrgan_Repo'
    Ensure-Dir (Split-Path $rsRepoDir)
    Ensure-Dir $rsRepoDir
    $venvPy = Join-Path $rsRepoDir 'venv\Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $venvPy)) {
        Write-Host "[venv] $py -m venv (Real-ESRGAN)" -ForegroundColor Cyan
        & $py -m venv (Join-Path $rsRepoDir 'venv')
        $venvPy = Join-Path $rsRepoDir 'venv\Scripts\python.exe'
    }
    $pip = Join-Path $rsRepoDir 'venv\Scripts\pip.exe'
    & $pip install --upgrade pip
    Write-Host "[pip] torch (index: $TorchIndexUrl)" -ForegroundColor Cyan
    & $pip install torch torchvision torchaudio --index-url $TorchIndexUrl
    $rgDir = Join-Path $rsRepoDir 'Real-ESRGAN'
    if ((Test-Path -LiteralPath $rgDir) -and -not (Test-Path (Join-Path $rgDir '.git'))) {
        Remove-Item -LiteralPath $rgDir -Recurse -Force
    }
    if (-not (Test-Path (Join-Path $rgDir '.git'))) {
        $git = Get-Command git -ErrorAction SilentlyContinue
        if (-not $git) { throw "git is required to clone Real-ESRGAN" }
        Push-Location $rsRepoDir
        try {
            & git clone $Versions.RealEsrganRepoUrl
        } finally { Pop-Location }
    }
    Push-Location $rgDir
    try {
        & git fetch --all 2>$null
        & git checkout $Versions.RealEsrganCommit
    } finally { Pop-Location }
    $weightsDir = Join-Path $rgDir 'weights'
    Ensure-Dir $weightsDir
    $wfile = Join-Path $weightsDir 'RealESRGAN_x4plus.pth'
    if (-not (Test-Path -LiteralPath $wfile)) {
        Invoke-Download -Uri $Versions.RealEsrganWeightsUrl -OutFile $wfile
    }
    & $pip install -r (Join-Path $rgDir 'requirements.txt')
    $deg = Join-Path $rsRepoDir 'venv\Lib\site-packages\basicsr\data\degradations.py'
    if (Test-Path -LiteralPath $deg) {
        $c = Get-Content -LiteralPath $deg -Raw -Encoding UTF8
        $c2 = $c -replace 'from torchvision.transforms.functional_tensor import rgb_to_grayscale', 'from torchvision.transforms.functional import rgb_to_grayscale'
        if ($c2 -ne $c) {
            $enc = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($deg, $c2, $enc)
            Write-Host "[patch] basicsr degradations.py (rgb_to_grayscale import)" -ForegroundColor Green
        }
    } else {
        Write-Warning "basicsr degradations.py not found yet; if pip failed, fix manually."
    }
    $verFile = Join-Path $rgDir 'realesrgan\version.py'
    if (-not (Test-Path -LiteralPath $verFile)) {
        [System.IO.File]::WriteAllText($verFile, '')
    }
    Write-Host "[ok] Real-ESRGAN stack under $rsRepoDir" -ForegroundColor Green
}

function Install-TessData {
    $dest = Join-Path $ImageTools 'TesseractOCR_Data'
    Ensure-Dir $dest
    foreach ($pair in @(
            @{ Name = 'eng.traineddata'; Url = $Versions.TessdataEngUrl },
            @{ Name = 'jpn.traineddata'; Url = $Versions.TessdataJpnUrl }
        )) {
        $out = Join-Path $dest $pair.Name
        if (Test-Path -LiteralPath $out) {
            Write-Host "[skip] $($pair.Name) already present" -ForegroundColor Yellow
            continue
        }
        Invoke-Download -Uri $pair.Url -OutFile $out
        Write-Host "[ok] $($pair.Name)" -ForegroundColor Green
    }
}

function Install-YomitokuStack {
    $py = Resolve-PythonExe
    $root = Join-Path $ImageTools 'yomitoku'
    Ensure-Dir $root
    $venvPy = Join-Path $root 'venv\Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $venvPy)) {
        & $py -m venv (Join-Path $root 'venv')
        $venvPy = Join-Path $root 'venv\Scripts\python.exe'
    }
    $pip = Join-Path $root 'venv\Scripts\pip.exe'
    & $pip install --upgrade pip
    & $pip install torch torchvision torchaudio --index-url $TorchIndexUrl
    & $pip install $Versions.YomitokuPipSpec
    Write-Host "[ok] YomiToku venv under $root" -ForegroundColor Green
}

Ensure-Dir $ImageTools

if ($AllPortable) {
    Install-ImageMagickPortable
    Install-GhostscriptIntoImageMagick
    Install-Qpdf
    Install-ExifTool
    Install-PdfcpuIfMissing
}
if ($RealEsrgan) {
    Install-RealEsrganStack
}
if ($Yomitoku) {
    Install-YomitokuStack
}
if ($TessData) {
    Install-TessData
}

if (-not $AllPortable -and -not $RealEsrgan -and -not $Yomitoku -and -not $TessData) {
    $usage = @(
        ''
        'Examples (Japanese docs: repo external_tools/.../image_tools/README.md):'
        '  .\setup\image_tools\Setup-ExternalTools.ps1 -AllPortable'
        '  .\setup\image_tools\Setup-ExternalTools.ps1 -AllPortable -SkipGhostscriptInstall'
        '  .\setup\image_tools\Setup-ExternalTools.ps1 -RealEsrgan'
        '  .\setup\image_tools\Setup-ExternalTools.ps1 -RealEsrgan -TorchIndexUrl https://download.pytorch.org/whl/cpu'
        '  .\setup\image_tools\Setup-ExternalTools.ps1 -Yomitoku'
        '  .\setup\image_tools\Setup-ExternalTools.ps1 -TessData'
    ) -join [Environment]::NewLine
    Write-Host $usage -ForegroundColor Yellow
}
