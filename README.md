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

---

### 外部ツールの配置先・入手手順（最重要）

**すべてのパス表・自動取得スクリプトの使い方・手動手順の詳細は、次の 1 本にまとめています。**

**[external_tools/external_tools/image_tools/README.md](external_tools/external_tools/image_tools/README.md)**

---

## 外部ツールの入手（手動の概要）

自動化は **`setup/image_tools/Setup-ExternalTools.ps1`**（リポジトリ同梱）を使えます。手で置く場合の要点だけ以下に示します。細部は上記 **image_tools/README.md** を参照してください。

- **Ghostscript**: [公式](https://www.ghostscript.com/releases/gsdnld.html)から Windows x64 をインストールし、`gsdll64.dll` / `gswin64c.exe` 等を `external_tools\external_tools\image_tools\ImageMagick-portable-Q16-HDRI-x64\` にコピー。
- **ImageMagick**: [バイナリ一覧](https://imagemagick.org/archive/binaries/)から **portable Q16-HDRI x64** の ZIP を展開し、フォルダ名を `ImageMagick-portable-Q16-HDRI-x64` にして `image_tools` 直下へ。
- **ExifTool / QPDF / pdfcpu / Tesseract tessdata**: 各公式・GitHub から取得し、**image_tools/README.md** のディレクトリ表どおりに配置。
- **Real-ESRGAN / YomiToku**: venv・クローン・weights・pip。詳細は **image_tools/README.md**。

**実験用スクリプト**（Ghostscript の比較実験など）は、混同を避けるためリポジトリルートの **`dev/`** に置いてください（`.gitignore` 済み）。旧来の **`scripts/`** も同様に無視されます。

**セットアップ用（コミット対象）**: **`setup/README.md`** を参照（`Run-ConvertPdf.ps1` など）。

## ビルド

```bash
dotnet build DN_SuperBook_PDF_Converter_VS2026.sln -c Release
```

出力例: `SuperBookToolsApp\bin\Release\net6.0\SuperBookToolsApp.exe`

## 実行

- **対話**: `SuperBookToolsApp.exe` を起動し、`ConvertPdf` や `ConvertPdf --help`。
- **ワンショット**: `SuperBookToolsApp.exe /cmd "ConvertPdf D:\in /dst:D:\out /ocr:yes"`
- **ラッパー**: `.\setup\Run-ConvertPdf.ps1 "D:\in" /dst:"D:\out" /ocr:yes`

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
