# DN_SuperBook_PDF_Converter 改修仕様書（修正版・統合版）

## 1. 背景

現行の DN_SuperBook_PDF_Converter は、入力 PDF を画像化し、Real-ESRGAN 等で補正したうえで画像固定 PDF を作成し、その後に別工程で YomiToku により OCR 済み PDF / HTML / Markdown / JSON を生成する構成になっている。
この構成は、1 文献に対して複数形式の成果物をまとめて保持する用途には合理性がある。

一方で、現在の利用目的は次の通りである。

* OCR 埋め込み PDF を主成果物として得たい
* 必要に応じて画像固定 PDF も得たい
* 黄色マーカーや注釈等が OCR の邪魔になる場合、OCR 前にオブジェクト除去したい
* HTML / Markdown / JSON の出力可否を利用時に選びたい
* 階層構造を維持するモードに加え、同一ディレクトリへ平置き出力するモードもほしい
* GUI から設定したい
* 一括処理だけでなく、各工程を独立して実行したい
* 最終的に整った EPUB も得たい
* OCR 精度を優先しつつ、最終成果物の PDF サイズは必要に応じて軽量化したい
* OCR 由来テキストの整形では、ページまたぎ結合や OCR 誤認識候補の抽出を行いたい
* LLM は全面自動校正ではなく、候補判定補助として使いたい

---

## 2. 改修の目的

本改修の目的は、現行の画像固定 PDF 中心の挙動を維持しつつ、以下を可能にすることである。

1. 画像固定 PDF と OCR 埋め込み PDF の出力を分離し、どちらを出力するか選択可能にする
2. OCR 処理前に、PDF 注釈やマーカー等のオブジェクト除去を選択可能にする
3. HTML / Markdown / JSON の出力を選択可能にする
4. 階層構造を作るモードと、同一ディレクトリへ平置き出力するモードを選択可能にする
5. 上記設定を GUI から操作可能にする
6. 一括処理に加え、画像化・高画質化・PDF 化・OCR・軽量化などを個別工程としても実行可能にする
7. OCR 後に PDF を軽量化する工程を追加可能にする
8. OCR 由来の Markdown / JSON などをもとに EPUB を生成可能にする
9. EPUB 生成時に、ページまたぎ結合や OCR 誤り検出を補助する後処理基盤を設ける
10. LLM を局所判定補助に限定して用い、本文全面書き換えを避ける

---

## 3. 前提と制約

### 3.1 注釈除去が有効なのは「PDF オブジェクトとして存在する場合」に限る

`pdfcpu annot remove` による除去が有効なのは、黄色マーカー等が PDF 注釈や描画オブジェクトとして存在する場合に限る。画像に焼き付いているマーカーには効果がない。

### 3.2 注釈除去は必ず「画像化前」または「OCR 前」に行う

OCR の邪魔になるマーカー等を避けたい場合、注釈除去は PDF 画像化や OCR の前段階で行う必要がある。画像化後の PDF や画像に対して `annot remove` をかけても意味がない。

### 3.3 画像固定版と OCR 版は別入力を許容する

* 画像固定版は元 PDF から生成してよい
* OCR 版は注釈除去後 PDF から生成してよい

このとき、OCR は注釈除去後 PDF に対して 1 回のみ行えばよい。

### 3.4 現行設計では OCR は PDF 直接入力である

現時点の設計では、OCR は画像固定 PDF を経由せず、元 PDF または注釈除去後 PDF を YomiToku に直接渡す前提とする。
したがって、画像固定版用の DPI 設定は、そのままでは OCR 経路には影響しない。

### 3.5 EPUB 化の難所は本文整形である

OCR 由来 Markdown / JSON から EPUB を得ること自体は可能であるが、品質上の難所は次の通りである。

* ページ末尾と次ページ先頭をつなぐかどうかの判定
* OCR 由来の誤字脱字・誤認識の検出
* 柱・ページ番号・メタ情報の除去
* 見出しと本文の区別
* 自然な改行・段落構造の再構成

### 3.6 LLM は全面自動校正器としては扱わない

LLM は、ページまたぎ結合候補や OCR 誤認識候補の判定補助には有用であるが、本文全体を自動で自然文に書き換える用途には使わない。
原文改変や過剰補正を避けるため、LLM は候補抽出・局所判定・要確認箇所提示に限定して利用する。

---

## 4. 現行の問題点

### 4.1 主出力が画像固定 PDF である

現行では出力先 PDF がまず画像固定版として作られ、その後に OCR 済み PDF が別途生成される。このため、検索可能 PDF を主成果物として使いたい場合に分かりにくい。

### 4.2 OCR とビューアー用出力の目的が分離されていない

閲覧用に意味のある画像固定 PDF と、RAG / 検索用に意味のある OCR 出力が、一つのコマンドの中で一律に生成されている。

### 4.3 マーカーや注釈が OCR を阻害しうる

現行の YomiToku 呼び出しでは `--figure --figure_letter` が固定で付いており、図形や強調要素を認識対象にしやすい。

### 4.4 出力階層が固定

現行では Post_OCR_Dir 以下の階層に出力されるが、RAG 用途では文献単位管理よりも、指定出力先へフラットに出したい場合がある。

### 4.5 CLI のみでは設定が煩雑

出力形式・除去有無・画像固定版要否などが多く、チェックボックス型 GUI が適している。

### 4.6 高画質化と最終ファイルサイズ調整が分離されていない

高画質で作った PDF が大きすぎる場合、最終成果物に応じて後から軽量化したい需要があるが、現行では最初から最後まで再実行する必要がある。

### 4.7 全工程一括実行しか想定していない

実運用では「高画質化までは済んだ」「OCR だけやり直したい」「軽量化だけしたい」といった場面があるが、現行仕様ではそうした再利用がしにくい。

### 4.8 EPUB 生成を前提とした後処理仕様がない

OCR 出力から EPUB を作るには、Markdown / JSON の再構成、ページまたぎの結合、誤認識候補抽出などが必要だが、その仕様が未整備である。

### 4.9 工程別コマンドの入出力定義が不足している

工程別実行を許容する場合、各コマンドがどの入力を受け、何を出力するかを明示しないと実装上の混乱が生じる。

---

## 5. 要求仕様

### 5.1 出力モード

#### 新規オプション

`OutputMode`

候補値:

* `ViewOnly`
* `OcrOnly`
* `Both`

#### 意味

* `ViewOnly`
  画像固定 PDF のみ生成する。YomiToku OCR は行わない。
* `OcrOnly`
  OCR 埋め込み PDF および選択された OCR 派生出力のみ生成する。画像固定 PDF は最終出力として生成しない。
* `Both`
  画像固定 PDF と OCR 系出力の両方を生成する。

#### 重要な内部処理定義

##### ViewOnly

1. 元 PDF を入力
2. 画像化
3. Real-ESRGAN
4. 補正
5. 画像固定 PDF 生成
6. 選択された出力構造に従って保存

##### OcrOnly

1. 元 PDF を入力
2. `StripAnnotationsBeforeOcr = true` の場合、pdfcpu で注釈除去版 PDF を生成
3. 注釈除去後 PDF または元 PDF を YomiToku に直接渡す
4. `PDF_OCRED / HTML / MD / JSON` のうち選択されたものを保存
5. 画像固定 PDF は生成しない
6. 画像固定版生成のための処理系列、すなわち **PDF の画像化 → Real-ESRGAN → 画像固定 PDF 再構築** は実行しない

##### Both

1. 元 PDF を入力
2. 画像固定版は元 PDF から ViewOnly フローで生成
3. OCR 用には必要なら注釈除去版 PDF を生成
4. OCR は注釈除去後 PDF または元 PDF に対して 1 回のみ実行
5. 選択された OCR 派生出力を保存

#### 備考

既定値は `Both` とする。

---

### 5.2 OCR 前オブジェクト除去

#### 新規オプション

`StripAnnotationsBeforeOcr : bool`

#### 挙動

* `true` の場合、OCR 対象 PDF に対して pdfcpu の `annot remove` を画像化前または OCR 前に実行し、一時的な注釈除去版 PDF を生成する
* OCR はその一時 PDF に対して行う
* `Both` または `ViewOnly` で画像固定版を生成する場合、画像固定版は元 PDF から生成する
* `false` の場合、OCR は元 PDF に対して行う

#### 制約

* 注釈や描画オブジェクトとして存在するマーカーには有効
* 画像に焼き付いたマーカーには無効

---

### 5.3 OCR 派生出力の選択

#### 新規オプション

* `ExportOcrPdf : bool`
* `ExportHtml : bool`
* `ExportMarkdown : bool`
* `ExportJson : bool`

#### 挙動

各出力形式について、選択されたもののみ生成する。

#### 既定値

* `ExportOcrPdf = true`
* `ExportHtml = true`
* `ExportMarkdown = true`
* `ExportJson = true`

#### 実効挙動マトリクス

| OutputMode | ExportOcrPdf | ExportHtml | ExportMarkdown | ExportJson | 実際の OCR 実行 |
| ---------- | ------------ | ---------- | -------------- | ---------- | ---------- |
| ViewOnly   | true/false   | true/false | true/false     | true/false | 実行しない      |
| OcrOnly    | true のとき出力   | true のとき出力 | true のとき出力     | true のとき出力 | 実行する       |
| Both       | true のとき出力   | true のとき出力 | true のとき出力     | true のとき出力 | 実行する       |

備考: `ViewOnly` では Export 系フラグの値にかかわらず OCR 系成果物は生成されない。

---

### 5.4 Figure 系オプション

#### 新規オプション

* `IncludeFigures : bool`
* `IncludeFigureLetters : bool`

#### 挙動

YomiToku 呼び出し時に

* `IncludeFigures = true` のときのみ `--figure` を付与
* `IncludeFigureLetters = true` のときのみ `--figure_letter` を付与

#### 既定値

* `IncludeFigures = false`
* `IncludeFigureLetters = false`

#### 理由

RAG / OCR 重視では、マーカーや図形の誤認識を減らしたいためである。

---

### 5.5 出力構造

#### 新規オプション

`OutputLayoutMode`

候補値:

* `Hierarchical`
* `Flat`

#### Hierarchical

文献単位の整理や将来的なビューアー連携を考慮し、用途別のサブフォルダを作成する。

例:

```text
Post_OCR_Dir/
  pdf_ocred/
  html/
  md/
  json/
  epub/
```

#### Flat

選択された成果物を、指定出力先ディレクトリ直下に出力する。

#### Flat モードの命名規則

機械処理しやすい命名規則を標準とする。サフィックスはアンダースコア + 小文字を採用する。

例:

```text
高橋隆一「不登校の類型分類」_view.pdf
高橋隆一「不登校の類型分類」_ocr.pdf
高橋隆一「不登校の類型分類」_html.html
高橋隆一「不登校の類型分類」_md.md
高橋隆一「不登校の類型分類」_json.json
高橋隆一「不登校の類型分類」_epub.epub
```

#### 同名ファイル衝突時の仕様

同一出力先に同名の入力 PDF が存在しうるため、衝突時は連番付与とする。

* 既存ファイルがある場合は `(1), (2)` などを末尾に付与して保存する
* 上書きはしない
* エラー停止もしない

例:

```text
高橋隆一「不登校の類型分類」_md.md
高橋隆一「不登校の類型分類」_md (1).md
```

#### 日本語ファイル名の扱い

* 日本語ファイル名は許容する
* ただし、外部ツール連携（例: YomiToku, pdfcpu, Ghostscript, ImageMagick 等）において日本語パスが問題なく扱えることを受け入れ試験で確認する
* Windows の長いパスや特殊文字による失敗を避けるため、必要に応じて内部処理では短縮一時パスを使用してよい
* OS 非互換な禁止文字や末尾空白・末尾ピリオドなどは保存前にサニタイズする

---

### 5.6 画像固定版 DPI 設定

#### 新規オプション

`ImageDpi`

候補値例:

* `200`
* `240`
* `300`

#### 挙動

* `ViewOnly` および `Both` における **画像固定版生成の PDF 展開と再構築時の解像度** に反映する
* `OcrOnly` では、画像固定版を生成しないため、この設定は画像固定版には影響しない
* 現時点では OCR は元 PDF または注釈除去後 PDF を YomiToku に直接渡す想定であるため、`ImageDpi` は主としてビューアー用画像固定版の容量と画質に影響する
* 将来的に OCR 側でもラスタライズ前処理を行う場合に備え、内部設計上は OCR 側にも拡張しやすいよう分離しておくこと

#### GUI 既定値

* 初期値は `240` とする
* `300` までは選択可能とする

#### 備考

* `200` は軽量化寄りの選択肢である
* `240` は画質と容量の均衡を取る既定値である
* `300` は高画質寄りの選択肢である

---

### 5.7 OCR 後軽量化

#### 新規オプション

* `DownscaleOcrPdfAfterRecognition : bool`
* `OcrPdfTargetDpi : int`
* `CompressViewPdfAfterGeneration : bool`
* `ViewPdfTargetDpi : int`

候補値例:

* `200`
* `240`
* `300`

#### 挙動

* `DownscaleOcrPdfAfterRecognition = true` の場合、OCR 埋め込み PDF 生成後に、画像部分を指定 DPI 相当に再サンプリング・再圧縮する
* テキストレイヤーが存在する場合は保持する
* 認識自体は元 PDF または高品質入力に対して先に完了させる
* 最終成果物として保存するのは軽量化後の OCR 埋め込み PDF とする
* `CompressViewPdfAfterGeneration = true` の場合、画像固定 PDF に対しても同様に後処理圧縮を行えるようにする

#### 目的

* OCR 精度と最終ファイルサイズ調整を分離する
* 高品質で OCR した後、納品用 PDF を軽量化できるようにする
* DPI 比較を最終工程だけで試行しやすくする

---

### 5.8 `/ocr` オプションと `/mode` オプションの関係

現行互換性のため `/ocr:yes|no` は残してよいが、意味を明確化する。

#### 定義

* `/ocr:no`

  * OCR を一切行わない
  * `OutputMode` は強制的に `ViewOnly` 相当として扱う
* `/ocr:yes`

  * OCR 実行を許可する
  * `OutputMode` に従って `OcrOnly` または `Both` が有効になる

#### 矛盾時の扱い

* `/ocr:no` かつ `/mode:ocr`
* `/ocr:no` かつ `/mode:both`

のような矛盾は許容しない。この場合は、明示的にエラーメッセージを出して停止する。

#### 逆方向の組み合わせ

* `/ocr:yes` かつ `/mode:view`

この組み合わせは矛盾とはみなさない。
この場合、`/mode:view` を優先し、実際の挙動は `ViewOnly` とする。すなわち OCR は実行しない。
ただし、ログまたは標準出力に「`/ocr:yes` は `/mode:view` により実質的に無効化された」旨の警告を出してよい。

#### 将来的な整理

理想的には `/ocr` を廃止して `/mode` のみに統一してよいが、今回の改修では互換性維持を優先する。

---

### 5.9 工程別実行モード

#### 目的

一括処理とは別に、画像化・高画質化・PDF 化・OCR・軽量化・EPUB 化などの各工程を独立して実行できるようにする。

#### 理由

* 途中成果物を再利用したい場合がある
* 高負荷工程を何度も繰り返したくない
* OCR 後や PDF 化後に軽量化だけやりたい場合がある
* デバッグや検証がしやすくなる
* EPUB の本文整形だけをやり直したい場合がある

#### 想定コマンド

* `ConvertPdf`
* `RenderPdfToImages`
* `EnhanceImages`
* `ImagesToPdf`
* `StripAnnotations`
* `RunOcr`
* `CompressPdf`
* `NormalizeOcrText`
* `BuildEpub`

#### 基本原則

* 各コマンドは単独で実行可能とする
* 一括モードは、内部的にはこれら工程別処理を組み合わせて実現してもよい
* 工程別実行時は、入力が PDF / 画像群 / 中間 PDF / Markdown / JSON のいずれであるかを明示する
* 中間成果物の保存場所と命名規則を統一する

### 5.9.1 工程別コマンドの入出力定義

| コマンド              | 主入力             | 主出力                        | 主な関連オプション                                                                                              |
| ----------------- | --------------- | -------------------------- | ------------------------------------------------------------------------------------------------------ |
| RenderPdfToImages | PDF             | 画像群                        | `RenderDpi`                                                                                            |
| EnhanceImages     | 画像群             | 高画質化画像群                    | `RealEsrganModel`, `Tile`, `Outscale`                                                                  |
| ImagesToPdf       | 画像群             | 画像固定 PDF                   | `ImageDpi`, `PdfCompression`                                                                           |
| StripAnnotations  | PDF             | 注釈除去後 PDF                  | `StripAnnotationsBeforeOcr`                                                                            |
| RunOcr            | PDF             | OCR PDF / HTML / MD / JSON | `IncludeFigures`, `IncludeFigureLetters`, `ExportOcrPdf`, `ExportHtml`, `ExportMarkdown`, `ExportJson` |
| CompressPdf       | PDF             | 軽量化後 PDF                   | `TargetDpi`, `CompressionProfile`                                                                      |
| NormalizeOcrText  | MD / JSON       | 正規化済み MD / HTML / 要確認リスト   | `UseLlmForJoinDecision`, `UseLlmForOcrErrorDetection`                                                  |
| BuildEpub         | 正規化済み MD / HTML | EPUB                       | `EpubSourceMode`, `EpubNormalizeText`                                                                  |

#### DPI オプションの分離

* `RenderPdfToImages` におけるラスタライズ解像度は `RenderDpi` とする
* 画像固定 PDF の再構築時に用いる解像度は `ImageDpi` とする
* 両者は将来的に別値を取りうるため、内部実装上も分離して扱う

---

### 5.10 PDF 軽量化コマンド

#### 新規コマンド

`CompressPdf`

#### 目的

既存の画像固定 PDF または OCR 埋め込み PDF に対して、画像部分を再サンプリングし、ファイルサイズを削減する。

#### 想定ユースケース

* 高 DPI で作成済みの閲覧用 PDF を軽量版にしたい
* OCR 後の PDF が大きすぎるので、検索性は保ったまま軽くしたい
* 全工程を再実行せず、最終成果物だけ調整したい

#### 例

```text
CompressPdf D:\OCR_OUT\book_view.pdf /dst:D:\OCR_OUT\book_view_240.pdf /dpi:240
CompressPdf D:\OCR_OUT\book_ocr.pdf /dst:D:\OCR_OUT\book_ocr_200.pdf /dpi:200
```

#### 挙動

* 入力 PDF 内の画像を目標 DPI 相当に再圧縮・再サンプリングする
* テキストレイヤーが存在する場合は保持する
* 元ファイルは上書きしない
* 出力先未指定時はサフィックス付きで保存する
  例: `_240dpi`, `_200dpi`

---

### 5.11 EPUB 生成

#### 新規オプション

* `ExportEpub : bool`
* `EpubSourceMode`
* `EpubNormalizeText : bool`

#### `EpubSourceMode` 候補値

* `FromMarkdownCombined`
* `FromMarkdownPaged`
* `FromJson`
* `Hybrid`

#### 基本方針

* EPUB 自体は最終出力の一形式として扱う
* ただし品質確保のため、単純変換ではなく本文整形工程を挟む
* 既定では `Hybrid` を推奨する

#### 各モードの意味

* `FromMarkdownCombined`
  MD_COMBINED をそのまま元にする
* `FromMarkdownPaged`
  MD_PAGED を元に、ページ境界情報を保持して整形する
* `FromJson`
  JSON の paragraph / order / role を元に再構成する
* `Hybrid`
  MD_COMBINED を本文ベースとしつつ、MD_PAGED と JSON を補助情報として用いる

#### 推奨方針

既定では `Hybrid` とし、以下を組み合わせる。

* 本文ベース: MD_COMBINED
* ページ境界情報: MD_PAGED
* 段落順序・見出し候補・補助判定: JSON

#### Hybrid モードの依存関係

`Hybrid` は以下を優先的に参照する。

1. MD_COMBINED
2. MD_PAGED
3. JSON

挙動は次の通りとする。

* 3 つすべてが利用可能な場合
  `Hybrid` を完全機能で実行する
* MD_COMBINED と MD_PAGED はあるが JSON がない場合
  JSON 依存機能を無効化して縮退実行する
* MD_COMBINED はあるが MD_PAGED または JSON が欠ける場合
  欠損入力に応じて縮退実行する
* MD_COMBINED 自体がない場合
  `Hybrid` はエラーとするか、明示設定により `FromJson` または `FromMarkdownPaged` にフォールバックしてよい

#### Export 系フラグとの関係

`Hybrid` 実行に必要な中間成果物が未生成である場合、以下のいずれかとする。

* 必要な中間成果物を内部的に一時生成する
* または不足入力を明示して停止する

既定では、**内部的一時生成を優先**する。

---

### 5.12 OCR テキスト正規化

#### 新規コマンド

`NormalizeOcrText`

#### 目的

OCR 由来の Markdown / JSON をもとに、EPUB 用に本文を整形する。

#### 処理対象

* ページ番号
* 柱
* ScanPageInfo
* 区切り線
* 明らかな OCR メタ情報
* 不要改行
* ページまたぎの文切れ
* OCR 誤認識候補

#### 処理段階

##### 第1段階: 規則ベース除去

* ページ番号除去
* 柱除去
* `ScanPageInfo` 除去
* 区切り線除去

##### 第2段階: JSON による再構成

* `paragraphs[].order` を用いて段落順を再構成
* 見出し候補や本文候補を区別する
* 縦書き OCR の読み順補助に用いる

##### 第3段階: ページまたぎ結合

規則ベースでまず候補抽出する。

例:

* 前ページ末尾が `。` `！` `？` などで終わっていない
* 次ページ先頭が助詞・接続語・活用語尾・文中始まりである
* 見出し・柱・ページ番号ではない
* 両者をつなぐと自然な一文になる

##### 第4段階: OCR 誤り候補抽出

* 文脈上不自然な漢字
* 低頻度で不自然な混入
* 同一文脈での表記揺れ
* 不自然な記号列
* 明らかな誤認識候補

#### 出力

* 正規化済み Markdown
* 要確認箇所リスト
* 変更ログ
* EPUB 用 HTML 断片または最終 HTML

---

### 5.13 LLM 補助後処理

#### 目的

ページまたぎ結合や OCR 誤り候補のうち、規則だけでは判定しにくい箇所を補助的に判定する。

#### 基本方針

* LLM は **規則ベースで候補抽出された箇所に対してのみ補助判定** を行うことを基本とする
* 原文改変を避けるため、全面書き換えは行わない
* 自動修正ではなく、候補提示または高信頼箇所のみ反映する

#### 想定オプション

* `UseLlmForJoinDecision : bool`
* `UseLlmForOcrErrorDetection : bool`
* `LlmProvider`
* `LlmModelName`
* `LlmEndpoint`
* `LlmConfidenceThreshold : float`

#### 想定プロバイダ

* `None`
* `Ollama`
* 将来的な拡張余地として他プロバイダを追加可能とする

#### 想定モデル例

* Ollama 上で利用可能なローカルモデル
  例として `gpt-oss-20b` を挙げてもよいが、モデル名は固定しない

#### 既定フロー

1. 規則ベースでページまたぎ結合候補を抽出する
2. 規則ベースで OCR 誤り候補を抽出する
3. `UseLlmForJoinDecision = true` の場合、結合候補についてのみ LLM に判定させる
4. `UseLlmForOcrErrorDetection = true` の場合、誤り候補についてのみ LLM に判定させる
5. LLM は本文全域を自由に書き換えない

#### LLM の役割

* ページ末尾と次ページ先頭を結合すべきかの判定
* OCR 誤り候補の抽出
* 見出し / 本文 / ノイズの判定
* JSON 形式で判定結果を返すこと

#### LLM にさせないこと

* 本文全体の全面自動校正
* 原文参照なしの断定修正
* 任意の言い換え・意訳
* 表記の勝手な統一

#### Ollama Structured Outputs

Ollama を利用する場合、判定結果の安定した構造化出力のため、OpenAI 互換 API の JSON mode または structured outputs を使用する。
推奨は、`format` フィールドに JSON Schema を渡して出力形式を拘束する方式とする。

#### JSON 返却例

```json
{
  "join_pages": true,
  "confidence": 0.93,
  "reason": "前ページ末尾が文中で終わり、次ページ先頭が助詞から始まるため",
  "suggested_text": "……別のものにつながり、そしてまた次へ……"
}
```

---

### 5.14 GUI の追加

#### 5.14.1 基本方針

既存 CLI は維持し、別途 GUI 画面を追加する。

#### 5.14.2 GUI に必要な項目

##### 入出力

* 入力フォルダ
* 出力フォルダ
* 参照ボタン

##### 実行モード

* 一括実行
* 工程別実行

##### 出力モード

* 画像固定 PDF を出力
* OCR 埋め込み PDF を出力
* EPUB を出力

##### OCR 派生出力

* HTML を出力
* Markdown を出力
* JSON を出力

##### OCR 前処理

* 注釈・マーカーオブジェクトを除去して OCR
* 図を含める
* 図中文字を含める

##### 出力構造

* 階層構造で出力
* 同一ディレクトリに平置き出力

##### 画質・サイズ

* 画像固定版 DPI（200 / 240 / 300）
* OCR 後軽量化を行う
* OCR PDF 目標 DPI（200 / 240 / 300）
* View PDF 軽量化を行う
* View PDF 目標 DPI（200 / 240 / 300）
* Real-ESRGAN を使う / 使わない

##### EPUB 整形

* EPUB を生成する
* ベースソース（Combined / Paged / JSON / Hybrid）
* OCR テキスト正規化を行う
* ページまたぎ自動結合を行う
* OCR 誤り候補抽出を行う
* LLM 補助を使う
* LLM プロバイダ
* モデル名
* LLM API エンドポイント（例: `http://localhost:11434`）
* JSON Schema / structured outputs を使う
* 信頼度しきい値

##### 実行制御

* 実行ボタン
* キャンセルボタン
* ログ表示欄
* 進捗表示

  * 総件数
  * 現在何件目か
  * 現在のファイル名
  * 可能なら現在何ページ目か
  * 工程名（画像化、補正、OCR、軽量化、EPUB 整形など）

##### エラー時の挙動

* 1 件失敗しても、残りの PDF があれば継続処理する
* 失敗件数と失敗ファイル名を最後にまとめて表示する
* ただし、ユーザーが「エラーで停止」を選べる拡張余地を残してよい

##### 並列処理と排他制御

将来的に並列処理を導入する場合、同名ファイル衝突時の連番付与では競合を避けるため、以下のいずれかを行う。

* 排他制御下で連番を決定する
* 一時的にプロセス ID / スレッド ID / タイムスタンプ付きの一意名で生成し、最終名称へアトミックに移動する

##### モデル設定

* Real-ESRGAN モデル選択が将来的に必要なら拡張余地を残す
* 現時点では固定モデル `RealESRGAN_x4plus` を使う仕様でよい
* GUI にはモデル選択をまだ出さなくてよいが、「現時点では固定」であることを明記する

---

## 6. 実装方針

### 6.1 一括処理基本フロー

#### ViewOnly

1. 元 PDF を入力
2. 画像化
3. Real-ESRGAN
4. 補正
5. 画像固定 PDF 生成
6. 必要なら後処理軽量化
7. 選択された出力構造に従って保存
8. 中間画像などの一時ファイルを削除

#### OcrOnly

1. 元 PDF を入力
2. `StripAnnotationsBeforeOcr = true` の場合、pdfcpu で注釈除去版 PDF を生成
3. 注釈除去後 PDF または元 PDF を YomiToku に直接渡す
4. PDF_OCRED / HTML / MD / JSON のうち選択されたものを保存
5. 必要なら OCR PDF を後処理軽量化
6. 必要なら EPUB 用本文整形と EPUB 生成
7. 一時ファイルを削除

#### Both

1. 元 PDF を入力
2. 画像固定版は元 PDF から ViewOnly フローで生成
3. OCR 用には必要なら注釈除去版 PDF を生成
4. OCR は注釈除去後 PDF または元 PDF に対して 1 回のみ実行
5. 選択された OCR 派生出力を保存
6. 必要なら OCR PDF / View PDF を軽量化
7. 必要なら EPUB 用本文整形と EPUB 生成
8. 中間画像・一時 PDF などを削除

### 6.2 工程別実行フロー

#### `RenderPdfToImages`

* PDF をページ画像群に展開する

#### `EnhanceImages`

* 画像群に対して Real-ESRGAN を適用する

#### `ImagesToPdf`

* 画像群を画像固定 PDF に再構築する

#### `StripAnnotations`

* PDF から注釈除去版 PDF を作成する

#### `RunOcr`

* PDF に対して OCR を実行し、OCR PDF / HTML / MD / JSON を生成する

#### `CompressPdf`

* 既存 PDF を後処理圧縮・再サンプリングする

#### `NormalizeOcrText`

* OCR Markdown / JSON を整形し、EPUB 向け本文を生成する

#### `BuildEpub`

* 整形済み Markdown / HTML から EPUB を生成する

### 6.3 PDF 軽量化バックエンド

`CompressPdf` および OCR 後軽量化の主要バックエンドには **Ghostscript の pdfwrite** を用いることを基本とする。
Ghostscript は PDF 再生成、画像圧縮、ダウンサンプリングを伴う最終 PDF 最適化に適している。
`pdfcpu` は PDF 構造操作や注釈除去に用い、画像再圧縮の主担当とはしない。

### 6.4 EPUB 生成バックエンド

* 単純な Markdown からの EPUB 生成では `calibre` または `pandoc` を使用してよい
* `FromJson` または `Hybrid` のように、段落構造・見出し・ページまたぎ結合結果・要確認箇所を細かく制御したい場合は、Python 側で整形済み HTML を生成したうえで EPUB 化することを基本とする
* 必要に応じて `ebooklib` を用いて、EPUB2/EPUB3 を直接ビルドしてよい

### 6.5 一時ファイル削除の原則

* 成功時は中間画像・一時 PDF を削除する
* エラー時はデバッグしやすいよう、必要に応じて残してもよい
* 将来的に「一時ファイルを保持する」デバッグオプションを追加できる設計にしておくこと

---

## 7. 非要求事項

今回の改修では、以下は必須としない。

* OCR モデル自体の変更
* Real-ESRGAN の学習済みモデル差し替え
* YomiToku 側モデルのカスタム学習
* 画像に焼き付いたマーカー色の除去
* 新規ビューアー機能そのものの実装
* `ocrmypdf` 等の別系統 OCR ツールとの比較・統合
* LLM による本文全面自動校正
* 完全自動無確認での EPUB 本文確定

---

## 8. コマンドライン例

### 例1: RAG 重視

```text
ConvertPdf D:\OCR_IN /dst:D:\OCR_OUT /ocr:yes /mode:ocr /stripAnnot:yes /figure:no /figureLetter:no /layout:flat
```

### 例2: 保存＋RAG 両立

```text
ConvertPdf D:\OCR_IN /dst:D:\OCR_OUT /ocr:yes /mode:both /stripAnnot:yes /figure:no /figureLetter:no /layout:hierarchical /dpi:240
```

### 例3: 画像固定版のみ

```text
ConvertPdf D:\OCR_IN /dst:D:\OCR_OUT /ocr:no /mode:view /layout:flat /dpi:240
```

### 例4: OCR 後 PDF 軽量化付き

```text
ConvertPdf D:\OCR_IN /dst:D:\OCR_OUT /ocr:yes /mode:ocr /stripAnnot:yes /downscaleOcrPdf:yes /ocrPdfTargetDpi:200
```

### 例5: 既存 OCR PDF を軽量化だけする

```text
CompressPdf D:\OCR_OUT\book_ocr.pdf /dst:D:\OCR_OUT\book_ocr_200.pdf /dpi:200
```

### 例6: OCR 出力から EPUB 生成まで行う

```text
ConvertPdf D:\OCR_IN /dst:D:\OCR_OUT /ocr:yes /mode:ocr /exportEpub:yes /epubSource:hybrid /normalizeOcrText:yes
```

### 例7: 既存 MD / JSON から EPUB だけ作る

```text
BuildEpub D:\OCR_OUT\book_md.md /json:D:\OCR_OUT\book_json.json /dst:D:\OCR_OUT\book.epub /source:hybrid
```

### 例8: Ollama のローカル LLM を使ってページまたぎ判定を補助する

```text
NormalizeOcrText D:\OCR_OUT\book_md_paged.md /json:D:\OCR_OUT\book_json.json /dst:D:\OCR_OUT\book_clean.md /useLlmJoin:yes /llmProvider:ollama /llmModel:gpt-oss-20b /llmEndpoint:http://localhost:11434
```

---

## 9. 受け入れ条件

1. GUI から以下を選択できる

   * OCR 埋め込み PDF 出力
   * 画像固定 PDF 出力
   * HTML / Markdown / JSON 出力
   * EPUB 出力
   * 注釈除去有無
   * 図 / 図中文字出力有無
   * 階層出力 / 平置き出力
   * 画像固定版 DPI
   * OCR 後軽量化
   * LLM 補助利用有無

2. `StripAnnotationsBeforeOcr = true` の場合

   * OCR は画像化前に生成された注釈除去後 PDF に対してのみ行われる
   * 画像固定版は元 PDF から作られる

3. `OutputLayoutMode = Flat` の場合、出力ファイルが指定ディレクトリ直下へ出る

4. `OutputMode = OcrOnly` の場合、画像固定 PDF が生成されず、画像化 → Real-ESRGAN → 画像固定 PDF 再構築フローも実行されない

5. `IncludeFigures = false / IncludeFigureLetters = false` の場合、YomiToku CLI に `--figure / --figure_letter` が付かない

6. `/ocr:no` と `/mode:ocr|both` の矛盾時に、明確なエラーが出る

7. `/ocr:yes` と `/mode:view` の場合、OCR は実行されず、警告ログが出る

8. `CompressPdf` を単独で実行できる

9. `CompressPdf` 実行時、既存 PDF を再処理せずに軽量版 PDF が得られる

10. `NormalizeOcrText` を単独で実行できる

11. EPUB 生成時、少なくとも次が除去または整理される

    * ページ番号
    * 柱
    * ScanPageInfo
    * 区切り線

12. ページまたぎ結合候補が検出される

13. OCR 誤り候補が抽出される

14. LLM 利用時、判定結果が JSON 等の構造化形式で返される

15. LLM を使わない場合でも、規則ベースだけで EPUB 生成まで完走できる

16. `Hybrid` 実行時に中間成果物が不足している場合、内部的一時生成または明示停止のいずれかの挙動が一定である

17. 日本語ファイル名を含む入力・出力で完走できる

18. 既存の 1 ページ PDF テストで正常完走する

19. 複数ページ PDF でも正常完走する

20. Flat モードで同名ファイル衝突時、連番付きで保存される

21. 複数 PDF 一括処理時、1 件失敗しても残りの処理が継続される

22. 成功時に中間画像・一時 PDF が削除される

---

## 10. 実装環境メモ

### OS

* Windows 11
* ログ上の OS 表示: Microsoft Windows [Version 10.0.26200.8039]

### IDE / ビルド

* Visual Studio 2022
* `.NET によるデスクトップ開発` ワークロード導入済み
* `.NET 6` ランタイム系が必要

### 実行ファイル

* `SuperBookToolsApp.exe`

### 外部ツール

* ImageMagick
* Real-ESRGAN
* YomiToku
* ExifTool
* pdfcpu
* Ghostscript
* EPUB 生成用ライブラリまたはツール
  例: calibre / pandoc / ebooklib

### 既知の注意

* ImageMagick の `delegates.xml / colors.xml` 警告は出るが、現状は完走している
* ExifTool の `PDF edits are reversible` 警告は致命的ではない
* YomiToku は CUDA 版 torch 導入後、CPU フォールバック警告が消えている
* LLM 補助は品質向上のための補助であり、全面自動本文確定を前提としない

---

## 付録 A. GUI 表示名と内部 enum の対応

| GUI 表示         | 内部 enum      |
| -------------- | ------------ |
| 階層構造で出力        | Hierarchical |
| 同一ディレクトリに平置き出力 | Flat         |
| 画像固定 PDF のみ    | ViewOnly     |
| OCR 系出力のみ      | OcrOnly      |
| 両方出力           | Both         |

