# CLI (Command List)

## 目的
PCから設定・測定・ログ保存を一連で実行できるようにする（実務っぽさの“顔”）。

---

## コマンド候補（W1テンプレ）
### help
- `help`
  - コマンド一覧表示

### get status
- `get status`
  - mode / rate / power / counters（crc_fail, retries, timeouts...）を表示

### set rate
- `set rate <bps>`
  - 例：`set rate 500000`

### set mode
- `set mode <A|B>`
  - Mode A: NRZ(+scramble)
  - Mode B: Manchester

### set power
- `set power <0|1|2>`
  - 物理出力ではなく論理冗長（例：同一フレーム複数回送信等）

### test per
- `test per <N> <payload_len>`
  - 例：`test per 1000 64`

### test ber
- `test ber <duration_s>`
  - 例：`test ber 10`

### log start/stop
- `log start`
- `log stop`
  - ログ出力開始/停止

---

## 出力形式
- ステータス：人間が読めるテキスト + 重要値はCSVログにも出せると良い
