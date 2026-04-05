# image_tools レイアウト

アプリは `SuperBookToolsApp` から次の相対パスを参照します（リポジトリルート基準で `external_tools\external_tools\image_tools\`）。

| パス | Git に含める | 入手方法 |
|------|----------------|----------|
| `pdfcpu\pdfcpu.exe` | **はい（推奨）** | リポジトリ同梱、または [pdfcpu releases](https://github.com/pdfcpu/pdfcpu/releases) から手動配置 |
| `TesseractOCR_Data\*.traineddata` | **はい（推奨）** | [tessdata_best](https://github.com/tesseract-ocr/tessdata_best) から `eng` / `jpn` を手動配置 |
| `ImageMagick-portable-Q16-HDRI-x64\` | いいえ | ルート README の手動手順 |
| （同上に配置）`gswin64c.exe` 等 | いいえ | Ghostscript インストール後に手動コピー |
| `exiftool-13.30_64\` | いいえ | ルート README の手動手順 |
| `QPDF\bin\qpdf.exe` | いいえ | ルート README の手動手順 |
| `RealEsrgan\RealEsrgan_Repo\` | いいえ | ルート README の手動手順（venv・クローン・weights） |
| `yomitoku\`（venv 含む） | いいえ | ルート README の手動手順 |

`scripts/` は Git に含めないため、取得の自動化は手元のスクリプトで行ってください。

詳細はリポジトリルートの **README.md** を参照してください。
