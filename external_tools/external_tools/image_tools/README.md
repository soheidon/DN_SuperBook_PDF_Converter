# image_tools — 外部ツールの配置と入手

アプリ（`SuperBookToolsApp`）は、リポジトリルートから見て **`external_tools\external_tools\image_tools\`** 以下の相対パスで外部実行ファイルを参照します。

## 目次

1. [ディレクトリ一覧（何をどこに置くか）](#ディレクトリ一覧何をどこに置くか)
2. [Git に含めるもの / 含めないもの](#git-に含めるもの--含めないもの)
3. [自動セットアップ（推奨の流れ）](#自動セットアップ推奨の流れ)
4. [手動セットアップ（コンポーネント別）](#手動セットアップコンポーネント別)
5. [Real-ESRGAN・YomiToku（Python）](#real-esrganyomitokupython)
6. [トラブルシュート](#トラブルシュート)

---

## ディレクトリ一覧（何をどこに置くか）

| パス（`image_tools` 直下） | 必須ファイルの例 | アプリが期待するパス |
|----------------------------|------------------|----------------------|
| `ImageMagick-portable-Q16-HDRI-x64\` | `magick.exe`, `mogrify.exe` | 上記フォルダ |
| （同上） | `gswin64c.exe`, `gsdll64.dll` 等 | ImageMagick と**同じ**フォルダ |
| `exiftool-13.30_64\` | `exiftool.exe`, `exiftool_files\` | 上記フォルダ |
| `QPDF\` | `bin\qpdf.exe` | `QPDF\bin\qpdf.exe` |
| `pdfcpu\` | `pdfcpu.exe` | `pdfcpu\pdfcpu.exe` |
| `TesseractOCR_Data\` | `eng.traineddata`, `jpn.traineddata` | ディレクトリ直下 |
| `RealEsrgan\RealEsrgan_Repo\` | venv, `Real-ESRGAN\`, weights | 下記「Real-ESRGAN」参照 |
| `yomitoku\` | `venv\`, パッケージ | YomiToku 用（OCR 時のみ） |

参照実装: `SuperBookToolsApp` の `SuperBookExternalTools`（`ImageMagick` / `YomiToku` / `AiTask` のパス）。

---

## Git に含めるもの / 含めないもの

- **コミットしてよい（このリポジトリの方針）**  
  `pdfcpu\pdfcpu.exe`、`TesseractOCR_Data\*.traineddata`（容量に応じて Git LFS も可）、`pdfcpu\README.md`、`TesseractOCR_Data\README.md`、本ファイル、リポジトリルートの **`setup\image_tools\`**（自動取得スクリプト）。

- **通常はコミットしない（ルート `.gitignore`）**  
  `ImageMagick-portable-Q16-HDRI-x64\`、`exiftool-13.30_64\`、`QPDF\`、`RealEsrgan\RealEsrgan_Repo\`、`yomitoku\`。  
  実験用の作業物はルートの **`dev\`** または **`scripts\`**（いずれも無視）に置く。

---

## 自動セットアップ（推奨の流れ）

### 前提

- Windows PowerShell 5.1 以降（`Expand-Archive` が使えること）
- インターネット接続（ダウンロード）
- **Real-ESRGAN / YomiToku** を使う場合: **Python 3.10+**、`git` が PATH にあること
- Ghostscript のサイレントインストール: **管理者権限**が必要なことがあります

### スクリプトの場所

- **`setup\image_tools\Setup-ExternalTools.ps1`** … メイン
- **`setup\image_tools\ExternalTools-Versions.ps1`** … ダウンロード URL・固定バージョン（スクリプトから dot-source）

リポジトリルートで実行します（例）。

```powershell
# 1) ポータブル系まとめて（ImageMagick → Ghostscript コピー → QPDF → ExifTool → pdfcpu が無ければ取得）
.\setup\image_tools\Setup-ExternalTools.ps1 -AllPortable

# 2) 既に Ghostscript を手動インストール済みなら（Program Files\gs から ImageMagick フォルダへコピーのみ）
.\setup\image_tools\Setup-ExternalTools.ps1 -AllPortable -SkipGhostscriptInstall

# 3) tessdata をリポジトリに載せていない場合
.\setup\image_tools\Setup-ExternalTools.ps1 -TessData

# 4) Real-ESRGAN（GPU 向け torch の既定 index は ExternalTools-Versions.ps1 参照。CPU の例:）
.\setup\image_tools\Setup-ExternalTools.ps1 -RealEsrgan -TorchIndexUrl https://download.pytorch.org/whl/cpu

# 5) YomiToku（OCR）
.\setup\image_tools\Setup-ExternalTools.ps1 -Yomitoku
```

オプションを付けずに実行すると、上記に相当する英語の一行ヘルプが表示されます。

### `-AllPortable` が行うこと（概要）

1. ImageMagick portable ZIP を `ExternalTools-Versions.ps1` の URL から取得し、フォルダ名 **`ImageMagick-portable-Q16-HDRI-x64`** で展開。
2. Ghostscript インストーラをダウンロードし **`/S`** でサイレント実行（`-SkipGhostscriptInstall` 時は省略）。その後 `C:\Program Files\gs\...\bin` から `gswin64c.exe` 等 4 ファイルを ImageMagick フォルダへコピー。
3. QPDF の ZIP を展開し、内側フォルダを **`QPDF`** に配置（`QPDF\bin\qpdf.exe`）。
4. ExifTool の ZIP を **`exiftool-13.30_64`** に展開。
5. **`pdfcpu\pdfcpu.exe` が無いときだけ** pdfcpu の ZIP から `pdfcpu.exe` を配置（既に Git 同梱がある場合はスキップ）。

一時ファイルは `%TEMP%` 配下に保存されます。

---

## 手動セットアップ（コンポーネント別）

URL やファイル名はバージョンアップで変わることがあります。失敗したら **`ExternalTools-Versions.ps1`** の URL を更新するか、以下の公式から入手してください。

### ImageMagick（portable Q16-HDRI x64）

1. [ImageMagick バイナリ一覧](https://imagemagick.org/archive/binaries/) から **portable** かつ **Q16-HDRI** の **64-bit** ZIP を入手。
2. 展開してできたフォルダ全体を、名前を **`ImageMagick-portable-Q16-HDRI-x64`** にして `image_tools` 直下へ置く（`magick.exe` がその直下にあること）。

### Ghostscript

1. [Ghostscript ダウンロード](https://www.ghostscript.com/releases/gsdnld.html) から Windows x64 用をインストール。
2. インストール先の `bin` から少なくとも次を **ImageMagick フォルダと同じ場所**へコピー:  
   `gsdll64.dll`, `gsdll64.lib`, `gswin64.exe`, `gswin64c.exe`

### ExifTool

- [ExifTool](https://exiftool.org/) の Windows 版 ZIP を展開し、**`exiftool-13.30_64`** というフォルダ名で `image_tools` 直下に配置（`exiftool.exe` と `exiftool_files` がその中にあること）。

### QPDF

- [qpdf releases](https://github.com/qpdf/qpdf/releases) から **msvc64** の ZIP を入手し、展開後のトップフォルダを **`QPDF`** にリネームして `image_tools` 直下へ（`QPDF\bin\qpdf.exe`）。

### pdfcpu

- [pdfcpu releases](https://github.com/pdfcpu/pdfcpu/releases) から Windows x64 の `pdfcpu.exe` を **`pdfcpu\`** に配置。リポジトリに同梱する運用でもよい。

### Tesseract（tessdata）

- [tessdata_best](https://github.com/tesseract-ocr/tessdata_best) から **`eng.traineddata`** と **`jpn.traineddata`** を **`TesseractOCR_Data\`** に配置。  
  または `Setup-ExternalTools.ps1 -TessData`。

---

## Real-ESRGAN・YomiToku（Python）

### Real-ESRGAN

自動スクリプト **`-RealEsrgan`** は概ね次を行います。

1. `RealEsrgan\RealEsrgan_Repo\` に venv を作成。
2. `pip install torch torchvision torchaudio`（`-TorchIndexUrl` で CUDA / CPU を切り替え）。
3. `git clone` [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) を同フォルダ内に取得し、**固定コミット**にチェックアウト（バージョンは `ExternalTools-Versions.ps1`）。
4. `weights\RealESRGAN_x4plus.pth` をダウンロード。
5. `pip install -r Real-ESRGAN\requirements.txt`
6. `basicsr` の `degradations.py` 内の `rgb_to_grayscale` の import を、環境に応じて `torchvision.transforms.functional` に置換（スクリプトが自動試行）。

手動で行う場合も、上記と同じディレクトリ構成にすればアプリの `AiTest_RealEsrgan_BaseDir` と整合します。

### YomiToku（OCR）

- **`-Yomitoku`**: `yomitoku\venv` を作成し、PyTorch の後に `yomitoku==0.10.3`（`ExternalTools-Versions.ps1`）を pip インストール。
- **ライセンス・商用利用**は [YomiToku README](https://github.com/kotaro-kinoshita/yomitoku) を必ず確認してください。

---

## トラブルシュート

| 現象 | 対処 |
|------|------|
| ImageMagick の ZIP URL が 404 | `ExternalTools-Versions.ps1` の `ImageMagickZipUrl` を [公式一覧](https://imagemagick.org/archive/binaries/) の現行ファイルに更新。 |
| Ghostscript がコピーできない | 管理者でインストーラを実行するか、`Program Files\gs` の実際のバージョンフォルダを確認。 |
| Real-ESRGAN の pip が失敗 | Python バージョン、CUDA 有無に合わせて `-TorchIndexUrl` を変更（CPU なら `https://download.pytorch.org/whl/cpu` 等）。 |
| PowerShell で日本語スクリプトが壊れる | 本リポジトリの `Setup-ExternalTools.ps1` のヘルプは ASCII 中心。詳細は本 README（UTF-8）を参照。 |

---

## 関連ドキュメント

- リポジトリルート **[README.md](../../../README.md)** … ビルド・実行・本 README への導線
- **[setup/README.md](../../../setup/README.md)** … `setup` フォルダの役割、`Run-ConvertPdf.ps1`
- 個人用・実験用スクリプト … ルートの **`dev/`**（推奨）または **`scripts/`**（レガシー、いずれも Git 無視）
