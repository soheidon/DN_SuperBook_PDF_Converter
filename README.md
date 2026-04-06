# DIY Book Scanning Toolkit

登大遊氏が開発した [DN_SuperBook_PDF_Converter](https://github.com/dnobori/DN_SuperBook_PDF_Converter) に対して、いくつかの機能を追加した派生版である。

## OCR 埋め込み済み PDF の圧縮

本派生版では、YomiToku により OCR テキストを埋め込んだ完成版 PDF に対し、追加で Ghostscript による再圧縮処理を行えるようにした。

元のツールである DN_SuperBook_PDF_Converter では、OCR 精度を高めるために、入力 PDF の画像を高解像度化・高画質化したうえで OCR を実行する。そのため、OCR 埋め込み後の完成版 PDF は、元の PDF より大幅にサイズが増加することがある。たとえば、ScanSnap でグレースケール・スーパーファイン設定で読み取った 150MB 程度の PDF が、処理後には約 530MB となり、3.5 倍前後に増加した例があった。

この増加の主な原因は、OCR 精度を高めるために画像を高画質化し、そのまま PDF に再構成している点にある。本派生版では、この OCR 後 PDF に対して再圧縮を加えることで、可読性や検索可能性を保ちながら、ファイルサイズを抑えやすくしている。

## 外部ツールの導入

元の DN_SuperBook_PDF_Converter でも本ツールでも、画像処理用の外部ツールをダウンロードし、所定のディレクトリに配置する必要がある。これらの取得と配置が煩雑であったため、本派生版では自動取得スクリプトを用意した。

## 元ツールの機能は維持

元プロジェクトの処理フローである、スキャン PDF の画質改善（Real-ESRGAN 等）、傾き・オフセット補正、余白トリミング、論理ページ番号・見開き・縦書き向けメタデータの付与といった主な機能は、そのまま維持している。オプションで [YomiToku](https://github.com/kotaro-kinoshita/yomitoku) による日本語 AI OCR（検索可能 PDF、HTML / Markdown / JSON 等）も引き続き利用できる。

## 動作環境

- **OS**: Windows 10 / 11 x64（開発・検証は Windows 11）
- **開発環境**: Visual Studio 2022 / 2026、**.NET 6**
- **Python 3.10 以上**（Real-ESRGAN / YomiToku 用 venv。パスが通っていること）
- **Git**（Real-ESRGAN のクローン用）
- **GPU**: Real-ESRGAN・YomiToku は CUDA 対応 GPU を推奨（CPU でも動作するが非常に遅い）
- **メモリ**: PDF のページ数に応じて数 GB 以上を要することがある

## リポジトリの取得

```
git clone --recursive <このリポジトリの URL>
````

パスには、スペースや全角文字を含めないことを推奨する。

---

### 外部ツールの配置先・入手手順（最重要）

**すべてのパス一覧、自動取得スクリプトの使い方、手動での配置手順の詳細は、次の 1 本にまとめている。**

**[external_tools/external_tools/image_tools/README.md](external_tools/external_tools/image_tools/README.md)**

---

## 外部ツールの入手（手動の概要）

自動化には、リポジトリ同梱の **`setup/image_tools/Setup-ExternalTools.ps1`** を利用できる。手動で配置する場合の要点のみを以下に示す。詳細は上記 **image_tools/README.md** を参照のこと。

* **Ghostscript**: [公式](https://www.ghostscript.com/releases/gsdnld.html) から Windows x64 版を取得し、`gsdll64.dll`、`gswin64c.exe` などを `external_tools\external_tools\image_tools\ImageMagick-portable-Q16-HDRI-x64\` にコピーする。
* **ImageMagick**: [バイナリ一覧](https://imagemagick.org/archive/binaries/) から **portable Q16-HDRI x64** の ZIP を取得・展開し、フォルダ名を `ImageMagick-portable-Q16-HDRI-x64` に変更して `image_tools` 直下に配置する。
* **ExifTool / QPDF / pdfcpu / Tesseract tessdata**: 各公式配布元または GitHub から取得し、**image_tools/README.md** のディレクトリ一覧どおりに配置する。
* **Real-ESRGAN / YomiToku**: venv、クローン、weights、pip の設定が必要である。詳細は **image_tools/README.md** を参照のこと。

**実験用スクリプト**（Ghostscript の比較実験など）は、混同を避けるため、リポジトリルートの **`dev/`** に置くことを推奨する（`.gitignore` 済み）。旧来の **`scripts/`** も同様に無視される。

**セットアップ用スクリプト（コミット対象）**については、**`setup/README.md`** を参照のこと（`Run-ConvertPdf.ps1`、`Run-RecompressPdf.ps1` など）。

## ビルド

```bash
dotnet build DN_SuperBook_PDF_Converter_VS2026.sln -c Release
```

出力例: `SuperBookToolsApp\bin\Release\net6.0\SuperBookToolsApp.exe`

## 実行

* **対話実行**: `SuperBookToolsApp.exe` を起動し、`ConvertPdf` / `RecompressPdf` または `--help` を利用する。
* **ワンショット実行**: `SuperBookToolsApp.exe /cmd "ConvertPdf D:\in /dst:D:\out /ocr:yes"`
* **ラッパースクリプト**: `.\setup\Run-ConvertPdf.ps1 "D:\in" /dst:"D:\out" /ocr:yes` または `.\setup\Run-RecompressPdf.ps1 "D:\in" /dst:"D:\out" ...`

`srcDir` と `dstDir` は**同一にできない**。

### ConvertPdf（フルパイプライン）

Real-ESRGAN、版面処理、必要に応じた OCR までを一括で実行する。

| オプション                   | 説明                                                          |
| ----------------------- | ----------------------------------------------------------- |
| `/ocr:yes\|no`          | YomiToku による OCR を実行する（要セットアップ）                             |
| `/recompressOcrPdf:yes` | OCR 後 PDF を Ghostscript で再圧縮する（`/downscaleOcrPdf` は互換エイリアス） |
| `/ocrPdfTargetDpi:N`    | 上記有効時の目標 DPI（1〜1200、省略時 200）                                |
| `/ocrPdfGrayscale:yes`  | 上記有効時にグレースケール化する                                            |
| `/ocrPdfJpegQuality:N`  | 上記有効時の JPEG 品質。0 は既定値、1〜100 を指定可能                           |

### RecompressPdf（Ghostscript 再圧縮のみ）

**既存の PDF** に対して、ImageMagick 経由で Ghostscript（`pdfwrite`）のみを適用する。**Real-ESRGAN、傾き補正、OCR は行わない。** 入力フォルダ以下の `.pdf` を再帰的に列挙し、出力先に**同じ相対パス**で書き出す。

| オプション                  | 説明                                                                              |
| ---------------------- | ------------------------------------------------------------------------------- |
| `/ocrPdfTargetDpi:N`   | 目標 DPI（1〜1200、**省略時 200**）。実効解像度と閾値の関係により、値を下げてもピクセル寸法が変わらず、ストリーム再圧縮にとどまることがある。 |
| `/ocrPdfGrayscale:yes` | 8bit グレースケール化を行う                                                                |
| `/ocrPdfJpegQuality:N` | 0 は Ghostscript 既定値、1〜100 は JPEG（DCT）品質の目安。数値が大きいほど高画質になり、ファイルサイズも大きくなりやすい。     |

OCR 済み PDF だけを軽量化したい場合は、`ConvertPdf` の出力フォルダ内の **`Post_OCR_Dir\pdf_ocred\`** など、対象 PDF が並んでいるフォルダを `srcDir` に指定して `RecompressPdf` を実行する。

**ページが 90° 回転してしまう場合:** Ghostscript `pdfwrite` の既定では、テキストの向きからページを自動回転する（`AutoRotatePages`）ことがある。OCR で付いたテキスト層の向きと見開きの見え方がずれると、本文が横倒しになることがある。**本ツールでは Ghostscript 呼び出しに `-dAutoRotatePages=/None` を付け、自動回転を抑止している**（`MiscUtil.CompressPdfWithGhostscriptAsync`）。古いビルドで再現する場合は、ソースを取り込んだうえで再ビルドする。

---

## PDF 再圧縮の目安（DPI・グレー・JPEG）

実際の効き方は、元 PDF の画像ラベル（effective ppi）やフィルタに依存する。次の表は、試行時の出発点として用いることを想定したものである。

### 圧縮度合いの目安

| 圧縮度合い | ねらい                 | 推奨設定（`RecompressPdf` の例）                              | 備考                            |
| ----- | ------------------- | ----------------------------------------------------- | ----------------------------- |
| 弱圧縮   | 見た目をあまり変えずに軽くする     | 既定 DPI（省略）＋グレーなし。必要に応じて `/ocrPdfJpegQuality:75` などを指定 | 主に JPEG の再エンコードであり、比較的安全である   |
| 中圧縮   | 読みやすさを保ちつつ、しっかり軽くする | `/ocrPdfGrayscale:yes /ocrPdfTargetDpi:72`            | 現時点で本命候補として試しやすい              |
| 強圧縮   | かなり軽くしたい            | `/ocrPdfGrayscale:yes /ocrPdfTargetDpi:50`            | 文字の見やすさは要確認であり、実測に応じて調整が必要である |

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

`ConvertPdf` で OCR 後に同等の圧縮を適用する場合は、従来どおり `/recompressOcrPdf:yes` と組み合わせる。たとえば中圧縮は次のようになる。

```powershell
.\setup\Run-ConvertPdf.ps1 "D:\OCR\TEST\OCR-IN" /dst:"D:\OCR\TEST\OUT_medium" /ocr:yes /recompressOcrPdf:yes /ocrPdfGrayscale:yes /ocrPdfTargetDpi:72
```

### 比較時の確認項目

* **ファイルサイズ**
* **見た目の読みやすさ**
* **OCR テキスト層が生きているか**（OCR 済み PDF を再圧縮する場合）

`ConvertPdf` と OCR を組み合わせる場合は、例として次のようなパスを比較対象とする。

* 再生成 PDF: `D:\OCR\TEST\OUT_xxx\（元と同じファイル名）.pdf`
* OCR 後 PDF: `D:\OCR\TEST\OUT_xxx\Post_OCR_Dir\pdf_ocred\（ファイル名） [ PDF_OCRED ].pdf`

`RecompressPdf` のみを使う場合は、`dst` 側に出力された PDF 同士を比較すればよい。

詳細な挙動については、`MiscUtil.CompressPdfWithGhostscriptAsync` の XML コメント（effective ppi とダウンサンプル条件）も参照のこと。

---

補足は `ConvertPdf --help`、`RecompressPdf --help`、および実行ログを参照のこと。

## ライセンス・免責

* アプリケーションソースのライセンスは、リポジトリルートの **`LICENSE`**（AGPL v3）に従う。
* NuGet、サブモジュール、外部ツール本体については、それぞれの配布元のライセンスに従うこと。
* YomiToku の利用条件（非商用・研究利用と商用利用の区別など）については、[YomiToku README](https://github.com/kotaro-kinoshita/yomitoku) を確認すること。
* スキャンした著作物の取り扱いは、著作権法および利用許諾の範囲内に限られる。本ツールは無保証である。
