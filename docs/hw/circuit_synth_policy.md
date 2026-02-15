# Circuit-Synth運用ポリシー（正本）

## 目的
Circuit-Synth導入時に、生成物と手編集の責務を分離し、Step運用とレビュー再現性を維持する。

## 適用範囲
- 対象: 子シート（`hw/stepNN_*.kicad_sch`）
- 非対象: 統合点の `hw/hw.kicad_sch`（Step00）

## 基本ルール
- Step00（`hw/hw.kicad_sch`）は統合点として手書き維持する。
- 正本は生成スクリプト（`scripts/hw/` 配下）と入力定義ファイルとする。
- 生成された `.kicad_sch` は成果物としてコミットする。
- 生成物 `.kicad_sch` を直接手編集しない。変更は必ずスクリプト経由で再生成する。

## 再生成運用（雛形）
- 再生成コマンドは `scripts/hw/` 配下に配置する。
- 命名例: `scripts/hw/gen_step02.ps1` または `scripts/hw/gen_step02.sh`
- PRには、実行コマンドと再生成ログをEvidenceとして添付する。

## レビュー観点
- 変更差分が「入力定義/スクリプト変更」と「再生成結果」で対応していること
- 手編集起因の差分（配線/UUID/座標の不整合）が混入していないこと
- Step00への変更は統合PRルール（`integration-pr` ラベル）に従うこと
