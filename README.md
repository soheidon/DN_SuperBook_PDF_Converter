# DN SuperBook PDF Converter（作業用リポジトリ）

スキャン PDF の画質改善（Real-ESRGAN 等）、傾き・オフセット補正、余白トリミング、論理ページ番号・見開き・縦書き向けメタデータの付与が主な機能です。オプションで [YomiToku](https://github.com/kotaro-kinoshita/yomitoku) による日本語 AI OCR（検索可能 PDF、HTML / Markdown / JSON 等）を実行できます。

本リポジトリは上流プロジェクトを整理・改修するための作業用ツリーです。詳細な背景説明や長い手順書は載せず、開発・実行に必要な情報だけをまとめています。

## 動作環境

- **OS**: Windows 10 / 11 x64（開発・検証は主に Windows）
- **開発**: Visual Studio 2022 / 2026、**.NET 6**
- **Python 3**（Real-ESRGAN / YomiToku 用 venv）
- **GPU**: Real-ESRGAN・YomiToku は CUDA 対応 GPU 推奨（CPU でも動くが非常に遅い）
- **メモリ**: PDF ページ数に応じて数 GB〜が必要になることがあります

## リポジトリの取得

サブモジュールを含める場合は `--recursive` でクローンしてください。

```bash
git clone --recursive <このリポジトリの URL>
```

パスにスペースや全角を含めないことを推奨します。

ルートの **`scripts/`** は `.gitignore` してあり、**Git には含めません**（手元の検証用 PowerShell やメモ用）。クローンだけでは存在しません。

## 外部ツールの配置

以下を **`external_tools\external_tools\image_tools\`** 配下に配置します（配布元のライセンスに従って各自入手してください）。

| ディレクトリ名 | 内容 |
|----------------|------|
| `exiftool-13.30_64` | [ExifTool](https://exiftool.org/)（`exiftool.exe` と `exiftool_files`） |
| `ImageMagick-portable-Q16-HDRI-x64` | [ImageMagick](https://imagemagick.org/) portable Q16-HDRI x64（`magick.exe` 等） |
| 同上フォルダ内 | Ghostscript x64 の `gsdll64.dll`, `gswin64c.exe` 等（[公式配布](https://www.ghostscript.com/releases/gsdnld.html)から取得しコピー） |
| `pdfcpu` | [pdfcpu](https://github.com/pdfcpu/pdfcpu/releases)（`pdfcpu.exe`） |
| `QPDF` | [qpdf](https://github.com/qpdf/qpdf/releases)（`bin\qpdf.exe` を含む構成） |
| `TesseractOCR_Data` | [tessdata_best](https://github.com/tesseract-ocr/tessdata_best) から `eng.traineddata`, `jpn.traineddata` |
| `RealEsrgan\RealEsrgan_Repo` | 下記「Real-ESRGAN」の venv とクローン |
| `yomitoku` | 下記「YomiToku」の venv（OCR を使う場合のみ） |

### Real-ESRGAN（概要）

1. `external_tools\external_tools\image_tools\RealEsrgan\RealEsrgan_Repo\` で Python venv を作成。
2. PyTorch（CUDA 版など環境に合わせて）をインストール。
3. [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) をクローンし、リポジトリが要求するコミット・`weights\RealESRGAN_x4plus.pth` を配置。
4. `pip install -r Real-ESRGAN\requirements.txt`
5. 環境によっては `basicsr` の `degradations.py` で `rgb_to_grayscale` の import を `torchvision.transforms.functional` に合わせる修正が必要です（従来手順どおり）。

### YomiToku（OCR を使う場合）

`external_tools\external_tools\image_tools\yomitoku\` に venv を作り、PyTorch に続けて例: `pip install "yomitoku==0.10.3"` 等、YomiToku 公式の推奨に従ってください。**ライセンス・商用利用**は [YomiToku README](https://github.com/kotaro-kinoshita/yomitoku) を必ず確認してください。

## ビルド

ソリューション `DN_SuperBook_PDF_Converter_VS2026.sln` を Visual Studio で開き、ビルドします。CLI からは例:

```bash
dotnet build DN_SuperBook_PDF_Converter_VS2026.sln -c Release
```

出力例: `SuperBookToolsApp\bin\Release\net6.0\SuperBookToolsApp.exe`

## 実行

- **対話コンソール**: `SuperBookToolsApp.exe` を起動し、プロンプトで `ConvertPdf` や `ConvertPdf --help`。
- **コマンドライン一発**（推奨）: ビルド出力の exe を直接指定します。  
  例: `SuperBookToolsApp.exe /cmd "ConvertPdf D:\in /dst:D:\out /ocr:yes"`
- 手元に `Run-ConvertPdf.ps1` などを置く場合は **`scripts/`**（Git 対象外）に置いても構いません。

`srcDir` と `dstDir` は**同一にできません**（上書き専用モードは不可）。

### ConvertPdf の主なオプション

| オプション | 説明 |
|------------|------|
| `/ocr:yes\|no` | YomiToku による OCR（要セットアップ） |
| `/recompressOcrPdf:yes` | OCR 後 PDF を Ghostscript で再圧縮（`/downscaleOcrPdf` は互換エイリアス） |
| `/ocrPdfTargetDpi:N` | 上記有効時、目標 DPI（1〜1200、省略時 200） |
| `/ocrPdfGrayscale:yes` | 上記有効時、グレースケール化 |
| `/ocrPdfJpegQuality:N` | 上記有効時、JPEG 品質 0=既定、1〜100 |

OCR 後 PDF と Ghostscript の組み合わせでは、元 PDF の解像度や画像フィルタによって効き方が変わります。補足メモは手元の `scripts` 等に置くか、`ConvertPdf --help` と実行ログを参照してください。

## ライセンス・免責

- 本リポジトリで公開されている作者によるアプリケーションソースのライセンスはリポジトリルートの **`LICENSE`**（AGPL v3）に従います。
- NuGet・サブモジュール・上記の外部実行ファイルは本リポジトリの配布物ではありません。各ソフトのライセンスに従ってください。
- YomiToku を `/ocr:yes` で利用する場合は、**YomiToku 側の利用条件**（非商用・研究と商用の区別等）を遵守してください。
- スキャンした著作物の取り扱いは著作権法およびご自身の利用許諾の範囲内に限ってください。本ツールは無保証です。

