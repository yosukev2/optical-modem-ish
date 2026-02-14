了解。以下はそのまま `README.md` に貼れる形で作りました（**W1時点のREADME**として、W2以降で埋める前提の“空枠”も入れてあります）。

---

# Optical Link Modem (RP2040 + TOSLINK)

## 目的（1〜2行）

RP2040(Pico) と TOSLINK 光モジュールを使い、**「基板 + 組み込みFW + 検証（BER/PER・ログ）+ 実務ドキュメント」**まで揃えた、実務代替ポートフォリオとしての“光リンクモデム”を実装する。

---

## 構成（箇条書き）

* **PC**

  * USB/シリアルで CLI 操作・ログ取得
* **MCU（RP2040 / Raspberry Pi Pico）**

  * フレーミング / 同期 / CRC / 再送 / 符号化モード切替
  * BER/PER 測定とログ出力
* **光モジュール（TOSLINK推奨）**

  * Tx：TOTX/TOTX系
  * Rx：TORX/TORX系
* **光ファイバ（TOSLINKケーブル）**

  * Tx↔Rx を接続（短距離から開始）
* **ベースボード（Pico載せ替え可能）**

  * 3.3V電源（LDO/DC-DC）＋保護＋テストパッド
  * Tx/Rxモジュール搭載、計測点、拡張I/F

> 構成図（W22で差し替え予定）
> `docs/onepager_A4.pdf` に掲載予定

---

## 成果物一覧（実務扱いに変える成果物）

* **Bring-up手順**：`docs/bringup.md`

  * 電源 → クロック → I/O → Tx → Rx → リンク確立（写真・測定値つき）
* **テスト計画**：`docs/test_plan.md` / `docs/test_matrix.csv`

  * 条件・合否基準・ログ形式・自動化手順
* **不具合チケット（最低3件）**：`docs/bugs/`（またはGitHub Issues）

  * 再現 → 切り分け → 修正 → 再発防止 → テスト追加
* **A4一枚サマリ**：`docs/onepager_A4.pdf`

  * 構成図、担当範囲、検証結果（BER/PER）、学び、残課題

---

## 週次マイルストーン（W1〜W4）

### W1：要件固定＆“実務の型”を作る

* `docs/spec.md`：仕様凍結（物理/レート/フレーム/CRC/再送/ログ）
* リポジトリ構成確定（docs/fw/hw/tools）
* Issueテンプレ追加（bug運用の型）

### W2：最速プロトで光リンクを“観測”する

* ブレッドボード等で Tx/Rx を暫定配線
* GPIOトグル → 受光出力変化を観測（ロジアナ/オシロ推奨）
* `docs/bringup.md` に配線図・測定ポイントを追記
* `fw/blink_optical/`：トグル＋Rxカウント最小FW

### W3：フレーム + CRC を“最低限のモデム核”として実装

* フレーム：`Preamble | Sync | Header | Length | Payload | CRC`
* 送受信バッファ（リング）・エラー処理
* `tools/test_crc.py`：CRCの既知ベクタテスト
* `docs/protocol.md`：プロトコル仕様

### W4：同期（プリアンブル検出）＋PER計測で“モデム顔”にする

* 受信同期：プリアンブル検出→sync→header→payload→CRC
* PER測定（連番pkt、欠番/CRC NG分類）
* ログフォーマット確定：`docs/log_format.md`
* READMEにデモ手順追記（このREADMEの空枠を埋める）

---

## デモ手順（W2で追記する前提の“空枠”）

> ※ここは W2 以降に更新予定

### 1) 配線・準備

* [ ] Tx/Rxモジュールの接続（Vcc/GND/IN/OUT）
* [ ] TOSLINKケーブルで Tx → Rx 接続
* [ ] Pico をPCに接続（USB）

### 2) ビルド＆書き込み

* [ ] `fw/` のビルド手順（例：CMake / pico-sdk）
* [ ] Picoにフラッシュ

### 3) 動作確認（最小）

* [ ] Txトグルを出す
* [ ] Rxでエッジカウント
* [ ] ロジアナで Tx入力とRx出力を観測（任意）

### 4) 測定（予定）

* [ ] PER測定（`test per ...`）
* [ ] BER測定（`test ber ...`）
* [ ] ログ保存（CSV/JSONL）

---

## 必要機材

* **Raspberry Pi Pico（RP2040）** ×2（送受信を分けるなら2枚推奨）
* **TOSLINK Tx/Rx モジュール**
  * 推奨：Toshiba系（TOTX/TORX など 3.3V対応の系統優先）
  * 代替：PLT133系（3〜5V/TTL互換と記載の系統）
* **TOSLINK光ファイバケーブル**（短め推奨）
* **ロジックアナライザ**（Tx入力/Rx出力の波形確認）
* **オシロスコープ**（電源リップル・受光ノイズ確認）⇒使用したいが、一旦保留
* **可変電源＋電流制限**（基板Bring-upの安全性UP）⇒使用したいが、一旦保留

---

## リポジトリ構成（予定）

```
.
├─ docs/            # 仕様・設計・bring-up・テスト・レポート
├─ fw/              # RP2040 firmware（link/protocol/cli/test）
├─ hw/              # KiCad（schematic/pcb/gerber）
├─ tools/           # PC側スクリプト（sweep/log/plot 等）
└─ sample_logs/     # サンプルログ（後で追加）
```

---

## ライセンス

* TBD（例：MIT / Apache-2.0）

---

## 状態

* W1（仕様凍結＆実務の型づくり）進行中

---

必要なら次に、**READMEの冒頭に入れる「3行で刺す要約」**と、`docs/spec.md` の雛形（項目埋め済み）も同時に作って、W1の成果物を一気に揃える形にできます。
