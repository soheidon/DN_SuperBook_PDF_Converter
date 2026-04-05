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

**セットアップ用（コミット対象）**: **`setup/README.md`** を参照（`Run-ConvertPdf.ps1` / `Run-RecompressPdf.ps1` など）。

## ビルド

```bash
dotnet build DN_SuperBook_PDF_Converter_VS2026.sln -c Release
```

出力例: `SuperBookToolsApp\bin\Release\net6.0\SuperBookToolsApp.exe`

## 実行

- **対話**: `SuperBookToolsApp.exe` を起動し、`ConvertPdf` / `RecompressPdf` や `--help`。
- **ワンショット**: `SuperBookToolsApp.exe /cmd "ConvertPdf D:\in /dst:D:\out /ocr:yes"`
- **ラッパー**: `.\setup\Run-ConvertPdf.ps1 "D:\in" /dst:"D:\out" /ocr:yes` ／ `.\setup\Run-RecompressPdf.ps1 "D:\in" /dst:"D:\out" ...`

`srcDir` と `dstDir` は**同一にできません**。

### ConvertPdf（フルパイプライン）

Real-ESRGAN・版面処理・（オプション）OCR まで一括で行います。

| オプション | 説明 |
|------------|------|
| `/ocr:yes\|no` | YomiToku による OCR（要セットアップ） |
| `/recompressOcrPdf:yes` | OCR 後 PDF を Ghostscript で再圧縮（`/downscaleOcrPdf` は互換エイリアス） |
| `/ocrPdfTargetDpi:N` | 上記有効時、目標 DPI（1〜1200、省略時 200） |
| `/ocrPdfGrayscale:yes` | 上記有効時、グレースケール化 |
| `/ocrPdfJpegQuality:N` | 上記有効時、JPEG 品質 0=既定、1〜100 |

### RecompressPdf（Ghostscript 再圧縮のみ）

**既存の PDF** に対して、ImageMagick 経由の Ghostscript（`pdfwrite`）だけをかけます。**Real-ESRGAN・傾き補正・OCR は行いません。** 入力フォルダ以下の `.pdf` を再帰列挙し、出力先に**同じ相対パス**で書き出します。

| オプション | 説明 |
|------------|------|
| `/ocrPdfTargetDpi:N` | 目標 DPI（1〜1200、**省略時 200**）。実効解像度と閾値の関係で、下げてもピクセル寸法が変わらずストリーム再圧縮に留まることがある。 |
| `/ocrPdfGrayscale:yes` | 8bit グレースケール化 |
| `/ocrPdfJpegQuality:N` | 0=Ghostscript 既定、1〜100=JPEG（DCT）品質の目安（大きいほど高画質・ファイルは大きくなりやすい） |

OCR 済み PDF だけを軽くしたい場合は、`ConvertPdf` の出力フォルダ内の **`Post_OCR_Dir\pdf_ocred\`** など、対象 PDF が並んでいるフォルダを `srcDir` に指定して `RecompressPdf` を実行してください。

---

## PDF 再圧縮の目安（DPI・グレー・JPEG）

実際の効き方は元 PDF の画像ラベル（effective ppi）やフィルタに依存します。次の表は**試すときの出発点**です。

### 圧縮度合いの目安

| 圧縮度合い | ねらい | 推奨設定（`RecompressPdf` の例） | 備考 |
|------------|--------|-----------------------------------|------|
| 弱圧縮 | 見た目をあまり変えずに軽くする | 既定 DPI（省略）＋グレーなし。必要なら `/ocrPdfJpegQuality:75` など | 主に JPEG 再エンコード。比較的安全 |
| 中圧縮 | 読みやすさを保ちつつしっかり軽くする | `/ocrPdfGrayscale:yes /ocrPdfTargetDpi:72` | 現時点の本命候補として試しやすい |
| 強圧縮 | かなり軽くしたい | `/ocrPdfGrayscale:yes /ocrPdfTargetDpi:50` | 文字の見やすさは要確認。実測で調整 |

### コマンド例（入力 `D:\OCR\TEST\OCR-IN` の場合）

**弱圧縮**（既定 DPI、カラー維持）

```powershell
.\setup\Run-RecompressPdf.ps1 "D:\OCR\TEST\OCR-IN" /dst:"D:\OCR\TEST\OUT_weak"
```

**中圧縮**

```powershell
.\setup\Run-RecompressPdf.ps1 "D:\OCR\TEST\OCR-IN" /dst:"D:\OCR\TEST\OUT_medium" /ocrPdfGrayscale:yes /ocrPdfTargetDpi:72
```

**強圧縮**

```powershell
.\setup\Run-RecompressPdf.ps1 "D:\OCR\TEST\OCR-IN" /dst:"D:\OCR\TEST\OUT_strong" /ocrPdfGrayscale:yes /ocrPdfTargetDpi:50
```

`ConvertPdf` で OCR 後に同じ強さをかける場合は、従来どおり `/recompressOcrPdf:yes` と組み合わせます（例: 中圧縮）。

```powershell
.\setup\Run-ConvertPdf.ps1 "D:\OCR\TEST\OCR-IN" /dst:"D:\OCR\TEST\OUT_medium" /ocr:yes /recompressOcrPdf:yes /ocrPdfGrayscale:yes /ocrPdfTargetDpi:72
```

### 比較の見方

- **ファイルサイズ**
- **見た目の読みやすさ**
- **OCR テキスト層が生きているか**（OCR 済み PDF を触る場合）

`ConvertPdf` + OCR の場合は、例として次のようなパスを比較します。

- 再生成 PDF: `D:\OCR\TEST\OUT_xxx\（元と同じファイル名）.pdf`
- OCR 後 PDF: `D:\OCR\TEST\OUT_xxx\Post_OCR_Dir\pdf_ocred\（ファイル名） [ PDF_OCRED ].pdf`

`RecompressPdf` だけの場合は、`dst` 側に出力された PDF 同士を比較します。

詳細な挙動の注意は `MiscUtil.CompressPdfWithGhostscriptAsync` の XML コメント（effective ppi・ダウンサンプル条件）も参照してください。

---

補足は `ConvertPdf --help` / `RecompressPdf --help` と実行ログを参照してください。

## ライセンス・免責

- アプリケーションソースのライセンスはリポジトリルートの **`LICENSE`**（AGPL v3）に従います。
- NuGet・サブモジュール・外部ツール本体は各配布元のライセンスに従ってください。
- YomiToku の利用条件（非商用・研究と商用の区別等）は [YomiToku README](https://github.com/kotaro-kinoshita/yomitoku) を確認してください。
- スキャンした著作物の取り扱いは著作権法および利用許諾の範囲内に限ってください。本ツールは無保証です。
