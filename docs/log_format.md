# Log Format (measure log)

## 作業ステータス
>  **measureログ（PER/BER結果）** のみを作成。  
> eventログ（状態遷移・エラーなど）は **JSONLで追加**（このファイルではフォーマットのみ方針メモ）。

---

## 1. 目的
光リンク（TOSLINK系）モデム実装の評価で発生する **PER/BER測定結果** を、
後から再集計・比較・再現できる形で保存するための CSV 仕様を定義する。

- **measureログ**：PER/BER の結果（**1行 = 1測定**）
- **eventログ**：状態遷移・エラーなど

---

## 2. 対象ログ
### 2.1 measureログ（本仕様の対象）
- ファイル形式：CSV
- エンコード：UTF-8（BOMなし推奨）
- 改行：LF（CRLFでも可だが統一推奨）
- 区切り：カンマ `,`
- 1行 = 1測定（PER/BER）
- 先頭にヘッダ行あり（必須）

### 2.2 eventログ
- 形式候補：JSON Lines（JSONL）
- 例：状態遷移、リンクダウン、CRC異常、同期再獲得、再送理由など

---

## 3. 命名規則（確定）
### 3.1 ログファイル名
`logs/YYYYMMDD_runXX_<mode>_<rate>_<test>.csv`

- `YYYYMMDD`：日付（例：20251230）
- `runXX`：同日内の通し番号（例：run01, run02）
- `<mode>`：`A` / `B`
- `<rate>`：Mbps表記（小数は `p` を使う：例 `0p5Mbps`, `1Mbps`, `2Mbps`）
- `<test>`：`per` / `ber`

**例**
- `logs/20251230_run01_A_0p5Mbps_per.csv`
- `logs/20251230_run02_B_2Mbps_ber.csv`

> ※ `cable`（short/long）や電源条件などは「列」で持つ（ファイル名に埋め込まない）

---

## 4. CSV Columns（確定：measureログ）
### 4.1 列一覧（順序固定・snake_case）
| column | type | required | description |
|---|---:|:---:|---|
| timestamp_iso | string | ✅ | ISO8601（例：`2025-12-30T18:35:12.123+09:00`） |
| mode | enum | ✅ | `A` / `B` |
| rate_mbps | number | ✅ | 例：`0.5`, `1`, `2` |
| power_level | int | ✅(予約) | `0/1/2`（初期は常に `0` 想定） |
| cable | enum | ✅ | `short` / `long`（ケーブル条件のタグ） |
| test_type | enum | ✅ | `per` / `ber` |
| pkt_sent | int | PER:✅ / BER:推奨 | 送信パケット数 |
| pkt_recv | int | PER:✅ / BER:推奨 | 受信パケット数（有効フレーム） |
| pkt_lost | int | PER:✅ / BER:推奨 | 欠損数（欠番・未達などの定義は test_plan に合わせる） |
| crc_fail | int | PER:✅ / BER:推奨 | CRC NG 数（受信はしたが破損） |
| bits_total | int | BER:✅ / PER:空可 | BER測定に使った総ビット数（payload由来など、定義は test_plan に合わせる） |
| bits_err | int | BER:✅ / PER:空可 | 誤りビット数 |
| ber | number | BER:✅ / PER:空可 | `bits_err / bits_total`（計算結果を保存。再計算可能性のため分子分母も残す） |
| note | string | 任意 | 自由欄（例：`vcc=3.30, temp=22C, firmware=abc123`） |

#### 値のルール（重要）
- **必須列は必ず存在**し、ヘッダのスペルはこの表と一致させる（解析を壊さないため）。
- `test_type=per` のとき：
  - `bits_total,bits_err,ber` は空でもよい（空欄推奨。`0` 埋めは誤解を生むので避ける）
- `test_type=ber` のとき：
  - `bits_total,bits_err,ber` は必須
  - `pkt_*` / `crc_fail` は残してもよい（フレーム化して測るなら役立つ）
- `note` にカンマが入る場合は **ダブルクォートで囲む**（CSV標準のエスケープ）

---

## 5. 例（ヘッダ + ダミー1行）
### 5.1 ヘッダ行
timestamp_iso,mode,rate_mbps,power_level,cable,test_type,pkt_sent,pkt_recv,pkt_lost,crc_fail,bits_total,bits_err,ber,note

### 5.2 PERの例（1行）
2025-12-30T18:35:12.123+09:00,A,0.5,0,short,per,10000,9992,8,3,,,,"vcc=3.30, firmware=abc123"

### 5.3 BERの例（1行）
2025-12-30T18:41:05.004+09:00,B,2,0,long,ber,2000,2000,0,0,16000000,12,7.5e-7,"prbs=15, vcc=3.30"

---

## 6. sample_logs
- `sample_logs/example_per.csv` を作り、5.1 のヘッダ + 5.2 の1行を入れる（ダミーでOK）
- 解析スクリプト（後日）を作るとき、この sample を単体で読めることが「動作確認」になる
****