# image_tools — 外部ツール配置ガイド（Windows 向け）

`SuperBookToolsApp` は **`external_tools\external_tools\image_tools\`** 以下の**決まった相対パス**だけを見に行きます。Windows に「入っているだけ」では不足しがちで、**ここに実体を置く**のが最大のポイントです。別マシンで迷いにくいよう、実際に詰まりやすかった点も含めています。

## 目次

1. [処理の流れ（ツール全体像）](#処理の流れツール全体像)
2. [開発環境・.NET 6・ビルドと日常運用](#開発環境net-6ビルドと日常運用)
3. [必要なもの（チェックリスト）](#必要なものチェックリスト)
4. [ディレクトリ一覧](#ディレクトリ一覧)
5. [自動セットアップ（`setup/image_tools`）](#自動セットアップsetupimage_tools)
6. [コンポーネント別（手動の要点とハマりどころ）](#コンポーネント別手動の要点とハマりどころ)
7. [動作確認と成功の目安](#動作確認と成功の目安)
8. [別マシンで特に注意すること（要約）](#別マシンで特に注意すること要約)
9. [Git に含める / 含めない](#git-に含める--含めない)
10. [関連リンク](#関連リンク)

---

## 処理の流れ（ツール全体像）

自炊 PDF をそのまま OCR するだけではなく、だいたい次の流れです。

1. PDF を画像化  
2. **Real-ESRGAN** で鮮明化  
3. 傾き補正・版面まわりなどの内部処理  
4. PDF を再構築  
5. （`/ocr:yes` 時）**YomiToku** で OCR  
6. 検索可能 PDF / HTML / Markdown / JSON などを出力  

内部では **Tesseract**（ページ処理側）や **ExifTool** / **pdfcpu** / **QPDF** なども使われます。

---

## 開発環境・.NET 6・ビルドと日常運用

### Visual Studio

- **ワークロード**: 「**.NET によるデスクトップ開発**」を入れる（VS 2022 / 2026 いずれでも可。ソリューションに合わせる）。
- **注意**: ビルドが通っても、**実行時に .NET 6 ランタイム不足**で止まることがあります。VS のワークロードだけで安心しないでください。

### .NET 6 ランタイムの確認

ターミナルで次を実行します。

```powershell
dotnet --list-runtimes
```

少なくとも **6.0.x** で、次のような行が出ていると安心しやすいです（名前は環境により多少異なります）。

- `Microsoft.AspNetCore.App 6.0.x`
- `Microsoft.NETCore.App 6.0.x`
- `Microsoft.WindowsDesktop.App 6.0.x`

.NET 6 のサポート期間は公式には終了していますが、「サポート有無」と「このアプリが今動かすために要るか」は別です。足りなければ **.NET 6 ランタイム**を別途入れてください。

### ビルド後の exe の場所（例）

```text
SuperBookToolsApp\bin\Debug\net6.0\SuperBookToolsApp.exe
SuperBookToolsApp\bin\Release\net6.0\SuperBookToolsApp.exe
```

### 日常運用で VS を毎回開く必要はない

- **Visual Studio**: 初回ビルド・ソース修正後の再ビルド向け。  
- **普段**: 上記フォルダの **`SuperBookToolsApp.exe` を直接起動**すればよいです。

```powershell
Set-Location "...\SuperBookToolsApp\bin\Debug\net6.0"
.\SuperBookToolsApp.exe
```

---

## 必要なもの（チェックリスト）

最低限、次を揃える必要が出ます（不足していると、ログ上で**順番に**別の箇所で落ちることがあります）。

| 区分 | 内容 |
|------|------|
| 開発 | Visual Studio（デスクトップ開発）、.NET 6 SDK/ランタイム |
| 共通 | **Git**（Real-ESRGAN クローン等） |
| `image_tools` 配下 | **ImageMagick**（portable + `magick.exe`）、**Ghostscript**（IM と同じフォルダへ DLL/EXE コピー） |
| | **QPDF**、**ExifTool**、**pdfcpu** |
| | **Tesseract** 学習データ（`eng` / `jpn`） |
| | **Real-ESRGAN**（専用 venv + リポジトリ + weights） |
| OCR 利用時 | **YomiToku**（専用 venv。Real-ESRGAN とは **venv を分ける**） |

**Python**: 依存の都合で **3.11 で専用 venv を作る**のが安定しやすいです。3.12 / 3.13 では Real-ESRGAN や周辺パッケージで不整合が出やすい、という報告があります（環境によります）。

---

## ディレクトリ一覧

| パス（`image_tools` 直下） | 役割・必須の例 |
|----------------------------|----------------|
| `ImageMagick-portable-Q16-HDRI-x64\` | `magick.exe`, `mogrify.exe`（**portable で magick.exe 付き**のものを使う） |
| （同上） | `gswin64c.exe`, `gsdll64.dll` 等（**IM と同じフォルダ**。Ghostscript 本体は通常 Program Files に入れ、ここへコピー） |
| `exiftool-13.30_64\` | `exiftool.exe` と **`exiftool_files\`**（後述） |
| `QPDF\` | `bin\qpdf.exe` |
| `pdfcpu\` | `pdfcpu.exe` |
| `TesseractOCR_Data\` | `eng.traineddata`, `jpn.traineddata` |
| `RealEsrgan\RealEsrgan_Repo\` | `venv\`, `Real-ESRGAN\`, `weights\` など |
| `yomitoku\` | `venv\` と、CLI が動く配置（後述） |

参照: `SuperBookToolsApp` の `SuperBookExternalTools` / `AiTask` / `PdfYomitokuLib` のパス。

---

## 自動セットアップ（`setup/image_tools`）

リポジトリルートから PowerShell で実行します。

| コマンド | 内容 |
|----------|------|
| `.\setup\image_tools\Setup-ExternalTools.ps1 -AllPortable` | ImageMagick ZIP、Ghostscript（サイレント `/S` のあと bin からコピー）、QPDF、ExifTool、pdfcpu（無い場合のみ） |
| 同じく `-SkipGhostscriptInstall` | 既に Ghostscript を入れ済みのときコピーのみ |
| `.\setup\image_tools\Setup-ExternalTools.ps1 -TessData` | `eng` / `jpn` の tessdata を `TesseractOCR_Data` に取得 |
| `.\setup\image_tools\Setup-ExternalTools.ps1 -RealEsrgan` | Real-ESRGAN 用 venv・クローン・weights・pip（`-TorchIndexUrl` で CPU/CUDA 切替） |
| `.\setup\image_tools\Setup-ExternalTools.ps1 -Yomitoku` | YomiToku 用 venv と pip（既定は `ExternalTools-Versions.ps1` のパッケージ指定） |

- ダウンロード URL のピン留めは **`setup\image_tools\ExternalTools-Versions.ps1`**。404 になったらここを更新してください。  
- **PyTorch の CUDA 版**はマシンの CUDA ドライバに合わせ、[PyTorch 公式](https://pytorch.org/get-started/locally/)の `pip` 用 `--index-url` を指定するのが確実です（下記「手動」参照）。  
- オプション無しで実行すると、英語の一行例が表示されます。

---

## コンポーネント別（手動の要点とハマりどころ）

### ImageMagick

- **用途**: PDF の画像化・再 PDF 化、deskew など。  
- **注意**: **portable 版でも `magick.exe` が付いている配布**を使うこと。ImageMagick 6 系の一部 portable には `magick.exe` が無いことがあります。  
- **ログ**: `delegates.xml` や `colors.xml` の**警告だけ**なら、環境によっては**処理は完走**します。すぐ致命的と決めつけない。

### Ghostscript

- **用途**: ImageMagick 経由で PDF を扱うために必要。  
- **注意**: ImageMagick だけ置いても、Ghostscript が無いと **PDF 展開で止まる**ことがあります。  
- **配置**: インストーラで入れた `gs*.dll` / `gswin64c.exe` 等を **ImageMagick のフォルダと同じ場所**へコピー（本リポジトリのアプリはそのパスを参照します）。

### QPDF

- [qpdf releases](https://github.com/qpdf/qpdf/releases) の Windows **msvc64** ZIP を展開し、トップフォルダを **`QPDF`** にして `image_tools` 直下へ（`QPDF\bin\qpdf.exe`）。

### ExifTool

- **用途**: PDF メタデータの整理。  
- **公式の注意**: Windows では `exiftool(-k).exe` を **`exiftool.exe` にリネーム**する運用が案内されることがあります。**`exiftool_files` フォルダごと**同じ階層に置く必要があります。  
- **ハマりどころ（実例）**  
  - `exiftool.exe` が無い  
  - `exiftool.exe` はあるが **`exiftool_files` が無い**、またはその中の **`perl5*.dll` が無い**  
- **正しい形の例**

```text
...\image_tools\exiftool-13.30_64\exiftool.exe
...\image_tools\exiftool-13.30_64\exiftool_files\   （中に perl5*.dll 等）
```

確認例:

```powershell
Test-Path "...\exiftool-13.30_64\exiftool.exe"
Test-Path "...\exiftool-13.30_64\exiftool_files"
Get-ChildItem "...\exiftool-13.30_64\exiftool_files" -Filter "perl5*.dll"
```

### pdfcpu

- **用途**: OCR 後の PDF に **viewer preferences** や **page layout**（例: 見開き・綴じ方向）を設定する処理で使われます。  
- **ハマりどころ**: **かなり最後の段階**まで進んでから `pdfcpu.exe` 不足で止まることがある。**初手で置いておく**のがおすすめです。  
- **配置**: `pdfcpu\pdfcpu.exe`  
- 確認: `& "...\pdfcpu\pdfcpu.exe" version`

### Tesseract（学習データ）

- **用途**: 内部のページ処理など（**YomiToku より前**の段階でも使われます）。  
- **必要ファイル**: `jpn.traineddata` と `eng.traineddata`  
- **配置**: `TesseractOCR_Data\` 直下  
- **ハマりどころ**: この 2 つが無いと **YomiToku 以前に Tesseract 初期化で落ちる**ことがあります。

```powershell
Test-Path "...\TesseractOCR_Data\jpn.traineddata"
Test-Path "...\TesseractOCR_Data\eng.traineddata"
```

### Real-ESRGAN

- **用途**: 画像鮮明化。  
- **実際の呼び出し例**（ログに近い形）:

```text
python Real-ESRGAN/inference_realesrgan.py -n RealESRGAN_x4plus -i dn_batch_in -o dn_batch_out --tile 512 --tile_pad 16 --outscale 2.00
```

- **Python**: **3.11 + 専用 venv** を推奨。  
- **PyTorch**: **CPU 版だけだと非常に遅い**。GPU がある場合は **CUDA 対応の torch** を入れる（ドライバと対応する `--index-url` は [PyTorch 公式](https://pytorch.org/get-started/locally/) を参照）。  
- **例**（環境に合わせてバージョン・ index は読み替え）:

```powershell
pip install torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 --index-url https://download.pytorch.org/whl/cu126
```

確認:

```powershell
python -c "import torch; print(torch.__version__); print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NO CUDA')"
```

- 手動で揃える場合のディレクトリは **`RealEsrgan\RealEsrgan_Repo\`**（venv・`Real-ESRGAN` クローン・`weights\RealESRGAN_x4plus.pth` 等）。自動スクリプトは `basicsr` の `degradations.py` の import 修正も試みます。

### YomiToku（OCR）

- **用途**: OCR 本体。PDF / HTML / Markdown / JSON 等の出力。  
- **ライセンス**: [YomiToku README](https://github.com/kotaro-kinoshita/yomitoku) を必ず確認（商用・非商用の区分など）。  
- **作業ディレクトリ**: アプリは **`...\image_tools\yomitoku`** をカレントにして **`yomitoku` コマンド**を実行します。通常はこのフォルダ直下の **`venv\Scripts`** に CLI が入っている必要があります。

**方法 A（リポジトリ付属スクリプト）**  
`Setup-ExternalTools.ps1 -Yomitoku` … `pip install` でパッケージを入れる方式（`ExternalTools-Versions.ps1` の版指定）。

**方法 B（手元でよく使われる editable インストールの例）**  
`yomitoku` フォルダ直下に venv を作り、リポジトリを `repo` などの名前で clone してから:

```powershell
Set-Location "...\image_tools\yomitoku"
git clone https://github.com/kotaro-kinoshita/yomitoku.git repo
# Python 3.11 推奨
& "...\Python311\python.exe" -m venv venv
.\venv\Scripts\Activate.ps1
Set-Location .\repo
python -m pip install --editable .
Set-Location ..
yomitoku --help
```

**GPU 化**: YomiToku 用 venv でも、**CPU 版 torch のまま**だと `CUDA is not available. Use CPU instead.` のような表示で遅くなります。**Real-ESRGAN 用 venvとは別**に、YomiToku 側 venv で CUDA 版 torch に入れ替えます（例は Real-ESRGAN と同様、公式の index-url に合わせる）。

```powershell
pip uninstall -y torch torchvision torchaudio
pip install torch==... torchvision==... torchaudio==... --index-url https://download.pytorch.org/whl/cu126
```

---

## 動作確認と成功の目安

### ConvertPdf の例

アプリ起動後、プロンプトで:

```text
ConvertPdf D:\OCR_IN /dst:D:\OCR_OUT /ocr:yes
```

OCR なしなら `/ocr:no`。

**注意**: `srcDir` と `dstDir` は**同一にできません**。

### テストの進め方

いきなり長い本 PDF で試さず、次の順が切り分けしやすいです。

1. **1 ページの PDF**  
2. 数ページの PDF  
3. 本番の長い PDF  

### ログで「一通り通った」目安（実例）

次のような行が出れば、少なくとも基本セットアップはできていると考えてよい例です。

- `Build '...\抽出したページ_1.pdf' OK.` のような **OK**  
- `Performing Japanese OCR completed.`（`/ocr:yes` 時）  
- `<< ConvertPdf Result >> numTotal = 1, numSkip = 0, numOk = 1, numError = 0`

---

## 別マシンで特に注意すること（要約）

1. **.NET 6**: VS を入れただけでは足りず、**実行時ランタイム**が別途必要なことがある。`dotnet --list-runtimes` で確認。  
2. **Python 3.11 推奨**: Real-ESRGAN / YomiToku まわりは 3.12・3.13 より安定しやすい。  
3. **venv はツールごとに分ける**: Real-ESRGAN 用と YomiToku 用は別。  
4. **torch**: 最初 CPU 版だけ入っていると遅い。**CUDA 版に入れ替え**て GPU を使う。  
5. **ExifTool**: **exe だけでは足りない**。`exiftool_files`（とその中身）が必須。  
6. **pdfcpu**: **後半で必要**になるので、早めに `pdfcpu\pdfcpu.exe` を置く。  
7. **所定パス**: ツールは **必ず `image_tools` 以下の期待パス**に置く（OS に入っているだけでは不十分なことが多い）。  
8. **ImageMagick の警告**: delegates / colors の警告だけなら、まずは最後まで様子を見る。

---

## Git に含める / 含めない

- **コミットしてよい例**: `pdfcpu.exe`、`TesseractOCR_Data\*.traineddata`（大きければ Git LFS）、`setup\image_tools\`、本 README。  
- **通常コミットしない（ルート `.gitignore`）**: `ImageMagick-portable-*`、`exiftool-*`、`QPDF`、`RealEsrgan\RealEsrgan_Repo`、`yomitoku`。  
- 実験用スクリプトはリポジトリルートの **`dev\`**（推奨）など、Git 対象外の場所へ。

---

## 関連リンク

- リポジトリルート **[README.md](../../../README.md)** … 全体のビルド・実行  
- **[setup/README.md](../../../setup/README.md)** … `setup` フォルダの役割、`Run-ConvertPdf.ps1`  
- 上流の公開リポジトリ例: [dnobori/DN_SuperBook_PDF_Converter](https://github.com/dnobori/DN_SuperBook_PDF_Converter)（Fork 利用時は `origin` / `upstream` を適宜）
