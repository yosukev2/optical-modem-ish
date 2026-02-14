# Spec: Optical Link Modem (RP2040 + PLT133/PLR237)

> SPEC FREEZE (v0.1 / W1)  
> 本仕様は原則確定版。変更が必要な場合は Issue 経由で、理由・影響範囲・代替案・必要なテスト更新（test_plan / log_format 等）を明記した後に反映。

## 0. 関連ドキュメント（正）
- Protocol詳細（フレーム/同期/状態遷移）: `docs/protocol.md`
- ログ列定義（CSVの一次ソース）: `docs/log_format.md`
- テスト計画（試験ID/合否基準/条件マトリクス）: `docs/test_plan.md`
- CLI仕様: `docs/cli.md`
- 部品根拠（データシート抜粋/購入リンク/代替候補）: `docs/parts.md`

---

## 1. 目的
PLT133（Tx）/PLR237（Rx）のTOSLINK系モジュールを用いた低速の光リンクで、“モデムっぽい”通信FW（フレーミング/同期/CRC/再送/符号化モード切替）と、検証（BER/PER・ログ）および 実務ドキュメント（Bring-up/Test plan/Bug tickets/Onepager）までを揃える。

## 2. スコープ
- 光リンク（短距離）での 双方向 送受信（最低2ノード、Tx/Rxを両方搭載）
- “モデムっぽさ”は ファーム側で実装（物理の難所は極力回避）
- 初期は「動く」より 測れる・再現できる・壊れ方が定義される を優先する

---

## 3. 固定仕様（W1で凍結する値）

### 3.1 ハード前提（部品・電圧）
- MCU: RP2040（Raspberry Pi Pico）
- Optical modules（Photolink系）
  - Tx: PLT133/T10W
  - Rx: PLR237/T10BK
- 部品の採用理由・一次ソース（データシート抜粋）・購入リンク・代替候補は `docs/parts.md` を正 とする（specは凍結運用のまま）
- GPIO Logic level: 3.3V
- Optical module Vcc:
  - Tx(Vcc)=3.3V
  - Rx(Vcc)=3.3V
  - 理由：Rx出力をRP2040の3.3V入力範囲に収めるため（Rxを5V駆動する場合はレベルシフタ必須。v0.1では禁止）

### 3.2 リンク形態
- Nodes: 2ノード想定（双方向 / Tx+Rx）
- Medium: TOSLINK光ファイバ

### 3.3 データレート
- 対応レート（設定可能）: 0.5 / 1 / 2 Mbps
- 初期運用（W2〜W4）: 0.5 Mbps 固定（安定化優先）

### 3.4 フレーム（概要）
- Frame format: `Preamble | Sync | Header | Length | Payload | CRC`
- Payload length: 0〜256 bytes（最大256B）
- CRC coverage: Header + Length + Payload（Preamble/Syncは除外）

### 3.5 同期（Preamble / Sync）
- Preamble
  - Pattern: 0x55 repeated
  - Count: 32 bytes（固定）
- Sync byte
  - Value: 0xD5（固定）
- 受信失敗時（CRC NG / 長さ不正 / sync不一致 等）は SYNC探索へ戻る（RESYNC）

### 3.6 Header（固定レイアウト）
Headerは 4 bytes固定。

| byte | name    | size | meaning |
|---:|---------|---:|---------|
| 0 | version | 1 | 固定値 0x01（v0.1） |
| 1 | flags   | 1 | mode/rate/power/ack等のビットフィールド |
| 2 | seq     | 1 | 下位4bitのみ使用（0〜15）、上位4bitは0固定 |
| 3 | type    | 1 | 0x01=DATA, 0x02=ACK, 0x03=NACK, 0x10=TEST |

#### flags（ビット割り当て）
- bit0-1: rate_id
  - 00=0.5Mbps, 01=1Mbps, 10=2Mbps, 11=reserved
- bit2: mode
  - 0=Mode A(NRZ), 1=Mode B(Manchester)
- bit3-4: power
  - 00=0, 01=1, 10=2, 11=reserved
- bit5: ack_req
  - 0=ACK不要, 1=ACK要求
- bit6-7: reserved（0固定）

### 3.7 CRC
- CRC Algorithm: CRC-16/CCITT-FALSE
  - width = 16
  - poly = 0x1021
  - init = 0xFFFF
  - refin = false
  - refout = false
  - xorout = 0x0000
- CRCの付与順（送信バイト順）: MSB first（big-endian）
  - 例：CRC=0x1234 → `0x12 0x34`
- CRCの入力順: Header → Length → Payload の順にバイト列を投入

### 3.8 再送（ARQ）
- ARQ: Stop-and-Wait
- seq: 4bit（0〜15）（Header.seq下位4bit）
- timeout: 20ms
- retry上限: 5回
- retry超過: link_down を宣言（statusに反映し、再同期を試みる）

### 3.9 符号化モード（PHY coding）
- Mode A: NRZ（W3〜で利用）
- Mode B: Manchester（W8で実装。仕様としてはv0.1で固定）
- モードの通知/切替: `flags.mode`

### 3.10 測定（品質評価）
- PER: packet error/loss rate（連番パケット、欠番/CRC NG を分類）
- BER: PRBS7（余力でPRBS15）

### 3.11 ログ（CSV）
- 保存先: `logs/`
- 命名規則: `logs/YYYYMMDD_runXX_<mode>_<rate>_<power>_<note>.csv`
  - 例：`logs/20260105_run01_A_0p5M_p1_short.csv`
- 列定義: `docs/log_format.md` を正（specは参照のみ）

---

## 4. 非目標（Non-goals）
- FEC（前方誤り訂正）
- 暗号化（Encryption）
- 高速化（>2Mbps）
- 長距離・高信頼向けのアナログ最適化（TIA設計、受光アンプ設計 等）
- 厳密な規格準拠（S/PDIF等）

---

## 5. インターフェース

### 5.1 PC ↔ MCU
- Control/CLI: USB CDC（優先）
  - 代替: UART
- Log output: USBまたはUART（制御と分離してもOK）

### 5.2 MCU ↔ Optical
- Tx: GPIO -> PLT133 IN
- Rx: PLR237 OUT -> GPIO input
- 実装方針: Rxは PIO or IRQ（W3で確定）

---

## 6. 合格条件（W26の最終成果物：1段落）
W26時点で、基板のBring-up手順（電源→I/O→リンク）が写真・測定値つきで再現可能であり、テスト計画（条件・合否基準・ログ形式）に基づいて BER/PERを自動測定しCSVログとして保存できること。さらに、不具合チケットを最低3件（再現→切り分け→修正→再発防止→テスト追加まで）完了しており、代表条件での測定結果（数値）をまとめた A4一枚サマリを提出できる状態であること。

---

## 7. 変更履歴
- 2025-12-30: 初版完成
