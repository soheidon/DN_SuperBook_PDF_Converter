# setup（リポジトリ同梱）

| パス | 内容 |
|------|------|
| `image_tools/Setup-ExternalTools.ps1` | `external_tools/.../image_tools` 向けの自動取得・配置 |
| `image_tools/ExternalTools-Versions.ps1` | 上記が dot-source する URL・バージョン定義 |
| `Run-ConvertPdf.ps1` | ビルド済み `SuperBookToolsApp.exe` で `ConvertPdf` を実行するラッパー |
| `Run-RecompressPdf.ps1` | 同上で `RecompressPdf`（Ghostscript 再圧縮のみ）を実行するラッパー |

**実験用・一時スクリプト**はリポジトリルートの **`dev/`** に置いてください（`.gitignore` 済み）。旧来の `scripts/` に混在させないでください。

詳細な手順は **`external_tools/external_tools/image_tools/README.md`** を参照してください。
