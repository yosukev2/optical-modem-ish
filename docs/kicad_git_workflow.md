# KiCadをGitで管理する運用
このドキュメントは、KiCadプロジェクトをGit/GitHubで安全に管理・レビューするための運用ルールを1箇所に集約したものです。  
**目的は「差分が追える」「衝突を避ける」「別PCでも再現できる」状態を維持すること**です。

---

## 1. リポジトリ構成（配置の原則）
**原則：KiCadプロジェクトは `hw/` 配下に置く。規約は `docs/` に集約する。**

hw/
  hw.kicad_pro
  hw.kicad_sch # Step00（正本）
  step01_power.kicad_sch # Step01以降
  (必要になったら) hw.kicad_pcb
  (必要になったら) sym-lib-table
  (必要になったら) fp-lib-table
lib/ # 外部ライブラリは必要時のみ（追加は別Issue）
docs/
  kicad_git_workflow.md # このファイル（運用の単一の真実）
  hw/
    nets.yml # ネット名辞書の正本（canonical）
    interface_contract.yml # Step間I/F契約の正本
    circuit_synth_policy.md # Circuit-Synth運用規約の正本
out/ # 生成物（原則git管理しない）


注意：`out/` は生成物置き場。普段はGitに入れない（リリース時だけ例外ルールあり）。

---

## 2. Gitで追跡するもの / ignoreするもの
KiCadはGUI編集だが、主要成果物はテキストファイルでありGit管理が可能。  
ただし個人環境ファイルや自動生成・バックアップ類は差分ノイズになるため除外する。

### 2.1 追跡（commit）対象（基本）
- `hw/*.kicad_pro`（プロジェクト設定。共有に有用なため原則追跡）
- `hw/*.kicad_sch`（回路図。Step分割前提）
- `hw/*.kicad_pcb`（基板。導入後は追跡）
- `hw/sym-lib-table` / `hw/fp-lib-table`（ライブラリ参照固定に有用。必要になったら追跡）
- `docs/` 配下（規約、設計ノート、意思決定ログ）

### 2.2 除外（ignore）対象（必須）
- `*.kicad_prl`（ユーザーごとの状態。必ず除外）
- `*-backups/`（バックアップフォルダ）
- `_autosave-*`（自動保存）
- `*.lck`（ロックファイル）
- `out/`（生成物置き場）
- `hw/out/`（`hw/` 配下の生成物置き場）

---

## 3. 回路図の分割方針（Step運用）と同時編集ルール
### 3.1 分割方針（Step01〜）
原則：回路図はStep単位のファイルに分割し、変更範囲を小さくする。

- `hw/hw.kicad_sch`：Step00（最上位／俯瞰と階層シートの接続点）
- `hw/step01_power.kicad_sch`：電源（W3でこのファイルを作る方針）
- `hw/step02_*`：I/OやTOSLINK周辺
- `hw/step03_*`：MCU周り
- 以降、必要に応じて `stepNN_*` を追加

命名規則：
- `hw/stepNN_<short>.kicad_sch`（NN=01,02... / shortは小文字スネーク）
- CIでは `^hw/step[0-9][0-9]_[^/]+\.kicad_sch$` を強制する（`hw/hw.kicad_sch` はStep00として別扱い）
- 一度決めたファイル名は原則変更しない（差分追跡コストを上げるため）

### 3.2 同時編集しないルール（コンフリクト回避の最重要）
- 同じ `.kicad_sch` を複数ブランチで同時に編集しない
- 特に `.kicad_pcb` は衝突が解消しづらいため、次を原則とする：
  - 基板ファイルは担当者固定、または順番制（同時編集禁止）

### 3.3 Step00への統合ルール（参照の追加）
- Step01〜を作っただけではStep00に自動反映されないため、**統合は `hw/hw.kicad_sch` に階層シート参照を追加して行う**
- `hw/hw.kicad_sch` は統合点なので、**同時編集禁止**（衝突回避）

**推奨運用（統合PR方式）**
- 各Step作成PR（例：`hw/step01_power.kicad_sch` 追加/更新）では **`hw/hw.kicad_sch` を触らない**
- Stepが揃ったタイミングで、最後に **「統合PR」** を作り、`hw/hw.kicad_sch` に **参照（階層シート）をまとめて追加**する
- 統合PRの判定は **PRラベル `integration-pr` が付いているかどうかのみ** で行う

注意：
- ここでの「統合」は **KiCadでの参照追加**であり、**KiCad上でファイル同士を“マージ”する操作はしない**

---

## 4. ライブラリ方針（標準優先 / 外部追加は最小）
### 4.1 基本方針
- KiCad標準ライブラリを優先
- 外部ライブラリ追加は最小限にする（差分が追いにくくなるため）

### 4.2 外部ライブラリを追加する場合（必須ルール）
- 必ずIssueを分けて実施する（このIssueではやらない）
- 追加する場合はプロジェクト内に同梱し、環境依存を避ける（例：`hw/lib/`）
- 追加時に必ず記録する（PR本文またはdocsの追記）
  - 追加理由
  - 出典（URL）
  - バージョン/コミットSHAなど識別子

---

## 5. PR運用（1PR=1Step）とレビュー証跡
### 5.1 1PR=1Step の意味
- 1つのPRでは基本1つのStepファイル（例：step01_power）だけを変更する
- PRが承認されたらGitHub上でマージして積み上げる
  - KiCad上で“マージ”操作はしない
- Stepファイル（step01/step02…）は順次マージで前進し、Step00（`hw/hw.kicad_sch`）への参照追加は「統合PR」でまとめて行う

### 5.2 PRガードレールCI（差分ベース）
PRでは `git diff --name-status <base> <head>` の差分だけを対象に、次を強制する。

- 禁止ファイル/パスを含む差分はFAIL
  - `*.kicad_prl`
  - `*/<something>-backups/*`
  - `_autosave-*` を含むファイル名
  - `*.lck`
  - `out/` 配下
  - `hw/out/` 配下
- 追加（`A`）・改名（`R*`）された `hw/` 配下の `.kicad_sch`（`hw/hw.kicad_sch` を除く）は
  `^hw/step[0-9][0-9]_[^/]+\.kicad_sch$` に一致しない場合FAIL
- `hw/hw.kicad_sch` が差分に含まれるPRは、ラベル `integration-pr` が無ければFAIL
  - `integration-pr` がある統合PRのみ、Step00変更を許可
- 変更された `hw/*.kicad_sch`（追加/変更/改名）だけに対して ERC を実行し、`error=0` かつ `warning=0` を必須化
  - 実装スクリプト: `scripts/ci/erc_changed_gate.sh`
  - 判定対象は差分ベース（`BASE_SHA` と `HEAD_SHA` の比較）

### 5.3 PRに必ず添付する“証跡”（Evidence）
GUI編集のため、差分だけだとレビューが難しい。  
そのため、PRには最低限の証跡を添付してレビュー可能性を上げる。

必須（推奨）：
- 変更したStepの回路図PDF（またはスクショ）
- ERC結果（PASS/FAILが分かるスクショ/ログ）
- What（何を変更したか）/ Why（なぜ必要か）を短文で

基板がある場合（推奨）：
- DRC結果（PASS/FAILが分かるスクショ/ログ）
- 基板レンダ画像（表/裏）

---

## 6. コンフリクト（衝突）時の原則対応
原則：無理にテキストマージで解決しない。KiCadで開いて直して解決する。

- Gitでコンフリクトが出たら、まず「同時編集が起きた」ことを確認し、再発防止（担当/順番）を調整
- 解決手順（原則）
  1. 片方の変更をベースにする（どちらを採用するか決める）
  2. KiCadでファイルを開き、必要な変更を反映
  3. ERC/DRC（該当する場合）を再確認
  4. コミットして解決

---

## 7. 製造リリースの例外ルール（Gerber等の扱い）
普段は `out/` をGit管理しないが、製造に出した瞬間の成果物は再現可能な形で固定したい。

以下のいずれかを採用（プロジェクトで統一すること）：
- GitHub Releaseに、Gerber/Drill/BOM等を添付（推奨）
- タグを打ち、リリース成果物をArtifactsとして保存（推奨）
- 例外的に `release/<date>_revX/` のようなフォルダにコミット（必要時のみ）

どれを採用するかは別Issueで決めても良い（本MDでは方針のみ提示）。

---

## 8. PR前の最小手順（ローカル証跡生成）

PRを出す前に、ローカルで証跡（PDF/ERC/DRC）を生成して内容を確認する。
生成した証跡はActionsのArtifactsと照合可能。

### 8.1 前提条件
- KiCad 8.0以降がインストールされていること
- `kicad-cli` にPATHが通っていること（コマンドプロンプトで `kicad-cli version` が実行できる）

### 8.2 1コマンド実行（PowerShell）

```powershell
# リポジトリルートで実行
.\scripts\kicad\gen_evidence.ps1 -ProjectPath "hw/hw.kicad_pro"
```

### 8.2.1 変更シートだけERCゲートを再現（bash）

```bash
# BASE/HEAD はCIと同じく差分比較で指定
bash scripts/ci/erc_changed_gate.sh "$BASE_SHA" "$HEAD_SHA"
```

### 8.3 生成されるファイル

出力先: `hw/out/`

| ファイル | 内容 |
|---------|------|
| `{名前}.pdf` | 回路図PDF |
| `{名前}_erc_all.json` | ERC結果（全severity） |
| `{名前}_erc_error.json` | ERC結果（エラーのみ、artifact確認用） |
| `erc/{名前}_erc_changed.json` | 変更シートERCゲート結果（error/warning判定用） |
| `{名前}_drc.json` | DRC結果（pcbがある場合のみ） |

例: `hw/hw.kicad_sch` の場合 → `hw/out/hw.pdf`, `hw/out/hw_erc_all.json`, `hw/out/hw_erc_error.json`, `hw/out/erc/hw_erc_changed.json`

### 8.4 hw/out/ はコミットしない

`hw/out/` は `.gitignore` で除外済み。生成後に `git status` で表示されないことを確認する。

```powershell
git status
# hw/out/ が表示されなければOK
```

### 8.5 Actions Artifactsとの照合チェック

PRをpushすると、GitHub ActionsがArtifacts (`kicad-pr-{PR番号}`) を生成する。
ローカル生成物とActionsの出力が整合していることを以下で確認できる：

- [ ] **ファイル名が一致**: ローカルの `hw/out/{名前}.pdf` と Artifacts の `{名前}.pdf` が同じ命名規則
- [ ] **ERC結果の整合**: ローカルでPASSならActionsでもPASS（エラーがあればActionsも失敗する）
- [ ] **DRC結果の整合**: pcbがある場合、ローカルとActionsで同じ `{名前}_drc.json` が生成される

注意: ActionsではPNG（`pdftoppm`）も生成されるが、ローカルでは省略している（PDF確認で十分）。

---

## 9. 最小チェックリスト（運用の守り）
- [ ] KiCadプロジェクトは `hw/` 配下にある
- [ ] `*.kicad_prl` / `*-backups/` / `_autosave-*` / `*.lck` / `out/` / `hw/out/` はGitに入れない
- [ ] Step00正本は `hw/hw.kicad_sch` とし、通常PRでは触らない（統合PR + `integration-pr` ラベル時のみ許可）
- [ ] 回路図（Step01以降）は `^hw/step[0-9][0-9]_[^/]+\.kicad_sch$` の命名規約を守る
- [ ] ハード契約（ネット名/I/F契約/Circuit-Synth運用）は `docs/hw/` の正本に従う
- [ ] PRは基本 1PR=1Step で小さく積み上げる
- [ ] PRに回路図PDF（またはスクショ）とERC/DRC結果を添付する
- [ ] 外部ライブラリ追加は必ずIssueを分け、理由/出典/版を残す
- [ ] コンフリクトはKiCadで開いて直し、ERC/DRCで再確認して解決する
