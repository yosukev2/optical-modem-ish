# Log Format (CSV)

## 1. 目的
測定（PER/BER）や状態（mode/rate/power/counters）を **再現可能な形で保存**するためのCSVログ形式を定義する。

## 2. ファイル命名規則（案）
- `logs/YYYYMMDD_runXX_<mode>_<rate>_<power>.csv`

## 3. CSV Columns（最低限）
> 1行 = 1測定結果（または1秒スナップショット）

| column | description |
|---|---|
| timestamp | ISO8601 or epoch ms |
| test_type | `per` / `ber` / `status` |
| mode | `A` / `B` |
| rate_bps | data rate (bps) |
| power | `0/1/2`（論理的設定） |
| duration_s | 測定時間（秒） |
| payload_len | payload length (bytes) |
| total_bits | BER用：総ビット数 |
| error_bits | BER用：誤りビット数 |
| ber | `error_bits/total_bits` |
| sent_pkts | PER用：送信パケット数 |
| recv_pkts | PER用：受信パケット数 |
| lost_pkts | PER用：欠損数（欠番） |
| crc_fail_pkts | CRC NG数 |
| per | `lost_pkts/sent_pkts`（定義はtest_planに合わせる） |
| retries | 再送回数（合計） |
| timeouts | タイムアウト回数 |
| notes | 任意（例：cable=short/long, vcc=3.3） |

## 4. 例（ダミー）
timestamp,test_type,mode,rate_bps,power,duration_s,payload_len,total_bits,error_bits,ber,sent_pkts,recv_pkts,lost_pkts,crc_fail_pkts,per,retries,timeouts,notes
