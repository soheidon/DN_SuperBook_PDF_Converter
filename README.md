# DN SuperBook PDF Converter（作業用リポジトリ）

スキャン PDF の画質改善（Real-ESRGAN 等）、傾き・オフセット補正、余白トリミング、論理ページ番号・見開き・縦書き向けメタデータの付与が主な機能です。オプションで [YomiToku](https://github.com/kotaro-kinoshita/yomitoku) による日本語 AI OCR（検索可能 PDF、HTML / Markdown / JSON 等）を実行できます。

## 動作環境

- **OS**: Windows 10 / 11 x64（開発・検証は主に Windows）
- **開発**: Visual Studio 2022 / 2026、**.NET 6**
- **Python 3.10+**（Real-ESRGAN / YomiToku 用 venv。パスが通っていること）
- **Git**（Real-ESRGAN クローン用）
- **GPU**: Real-ESRGAN・YomiToku は CUDA 対応 GPU 推奨（CPU でも動くが非常に遅い）
- **メモリ**: PDF ページ数に応じて数 GB〜が必要になることがあります

## リポジトリの取得

```bash
git clone --recursive <このリポジトリの URL>
```

パスにスペースや全角を含めないことを推奨します。

ルートの **`scripts/`** は **`.gitignore` 済みで Git に含みません**。検証用 PowerShell や個人用の取得スクリプトは手元の作業コピーにだけ置いてください（クローン直後はフォルダが無くても問題ありません）。

## 外部ツール方針（Git に含める / 含めない）

| 種別 | 内容 |
|------|------|
| **リポジトリに含める（候補）** | `pdfcpu.exe`、`TesseractOCR_Data`（`eng.traineddata` / `jpn.traineddata` 等）、本 README、`external_tools/.../image_tools/README.md` |
| **同梱しない（.gitignore）** | `scripts/`、ImageMagick portable、ExifTool、QPDF、Ghostscript バイナリ、Real-ESRGAN クローン・weights・venv、YomiToku venv、一般的なポータブル一式・学習済みモデル |

配置先の一覧は **`external_tools/external_tools/image_tools/README.md`** を参照してください。

### 外部ツールの入手（手動）

各配布元のライセンスに従って入手し、次のパスに配置します。

- **Ghostscript**: [公式](https://www.ghostscript.com/releases/gsdnld.html)から Windows x64 をインストールし、`gsdll64.dll` / `gswin64c.exe` 等を `external_tools\external_tools\image_tools\ImageMagick-portable-Q16-HDRI-x64\` にコピー（アプリは ImageMagick と同じフォルダの `gswin64c.exe` を参照します）。
- **ImageMagick**: [バイナリ一覧](https://imagemagick.org/archive/binaries/)から **portable Q16-HDRI x64** の ZIP を展開し、フォルダ名を `ImageMagick-portable-Q16-HDRI-x64` にして `image_tools` 直下へ。
- **ExifTool**: [ExifTool](https://exiftool.org/) の Windows 版を `exiftool-13.30_64\`（`exiftool.exe` と `exiftool_files`）として配置。
- **QPDF**: [qpdf releases](https://github.com/qpdf/qpdf/releases) の Windows msvc64 ZIP を展開し、トップフォルダを `QPDF` にリネームして `image_tools` 直下へ（`QPDF\bin\qpdf.exe` になること）。
- **pdfcpu**: [pdfcpu releases](https://github.com/pdfcpu/pdfcpu/releases) から `pdfcpu.exe` を `pdfcpu\` に配置（リポジトリ同梱を推奨）。
- **Tesseract データ**: [tessdata_best](https://github.com/tesseract-ocr/tessdata_best) から `eng.traineddata` と `jpn.traineddata` を `TesseractOCR_Data\` に配置。
- **Real-ESRGAN**: `RealEsrgan\RealEsrgan_Repo\` に Python venv を作成し、[Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) を所定のコミットでクローン、`weights\RealESRGAN_x4plus.pth` を配置、`pip install -r requirements.txt`。環境によっては `basicsr` の `degradations.py` で `rgb_to_grayscale` の import を `torchvision.transforms.functional` に合わせる修正が必要です。
- **YomiToku（OCR）**: `yomitoku\` に venv を作成し、PyTorch に続けて `pip install yomitoku` 等、公式 README に従ってください。**ライセンス**は [YomiToku README](https://github.com/kotaro-kinoshita/yomitoku) を確認してください。

自動ダウンロード用の PowerShell は **リポジトリには含めない**方針のため、必要なら手元の `scripts\` に独自のスクリプトを置いてください。

## ビルド

```bash
dotnet build DN_SuperBook_PDF_Converter_VS2026.sln -c Release
```

出力例: `SuperBookToolsApp\bin\Release\net6.0\SuperBookToolsApp.exe`

## 実行

- **対話**: `SuperBookToolsApp.exe` を起動し、`ConvertPdf` や `ConvertPdf --help`。
- **ワンショット**: `SuperBookToolsApp.exe /cmd "ConvertPdf D:\in /dst:D:\out /ocr:yes"`
- 手元にラッパーを置く場合の例: `SuperBookToolsApp.exe /cmd "ConvertPdf $($args -join ' ')"` を `.ps1` で呼び出すなど（`scripts/` は Git 対象外）。

`srcDir` と `dstDir` は**同一にできません**。

### ConvertPdf の主なオプション

| オプション | 説明 |
|------------|------|
| `/ocr:yes\|no` | YomiToku による OCR（要セットアップ） |
| `/recompressOcrPdf:yes` | OCR 後 PDF を Ghostscript で再圧縮（`/downscaleOcrPdf` は互換エイリアス） |
| `/ocrPdfTargetDpi:N` | 上記有効時、目標 DPI（1〜1200、省略時 200） |
| `/ocrPdfGrayscale:yes` | 上記有効時、グレースケール化 |
| `/ocrPdfJpegQuality:N` | 上記有効時、JPEG 品質 0=既定、1〜100 |

補足は `ConvertPdf --help` と実行ログを参照してください。

## ライセンス・免責

- アプリケーションソースのライセンスはリポジトリルートの **`LICENSE`**（AGPL v3）に従います。
- NuGet・サブモジュール・外部ツール本体は各配布元のライセンスに従ってください。
- YomiToku の利用条件（非商用・研究と商用の区別等）は [YomiToku README](https://github.com/kotaro-kinoshita/yomitoku) を確認してください。
- スキャンした著作物の取り扱いは著作権法および利用許諾の範囲内に限ってください。本ツールは無保証です。
