# Protocol: Framing / Sync / CRC

## 1. 目的
光リンク上で “モデムっぽさ” を成立させるための最小プロトコル（同期・フレーム・CRC・再送の前提）を定義する。

## 2. フレーム形式（箱）

### 2.1 Preamble
- Pattern: `0x55` repeated
- Count: TBD（例：16〜64 bytes）
- Purpose: 同期検出のための繰り返しパターン

### 2.2 Sync
- Value: TBD（例：`0xD5`）
- Purpose: フレーム開始の確定（preambleの後に続く印）

### 2.3 Header（例）
> ここは「最低限の箱」。W3で確定する

- `version` (1 byte)
- `flags` (1 byte): mode/rate/power/ack関連など
- `seq` (1 byte): Stop&Wait用（1bitでもbyteで持ってOK）
- `type` (1 byte): DATA/ACK/NACK/TEST etc.（任意）

### 2.4 Length
- 1 byte or 2 bytes（暫定：1 byte）
- payload length in bytes（0〜MAX）

### 2.5 Payload
- user data or test pattern (PRBSなど)

### 2.6 CRC
- CRC-16-CCITT（spec.mdに従う）
- Coverage: `Header + Length + Payload`
- Details（poly/init/refin/refout/xorout）はW3で確定

## 3. 同期（受信状態遷移の箱）
- SEARCH_PREAMBLE
- SEARCH_SYNC
- READ_HEADER
- READ_LENGTH
- READ_PAYLOAD
- READ_CRC
- VALIDATE / DROP / RESYNC

## 4. 再送（Stop-and-Waitの箱）
- DATA送信 -> WAIT_ACK
- ACKなら次へ / TIMEOUTなら再送 / NACKなら再送
- Retry limit: TBD（例：3回）

## 5. モード（符号化切替の箱）
- Mode A: NRZ (+ optional scramble)
- Mode B: Manchester
- Modeは `flags` で通知・切替

## 6. 未確定項目（To decide）
- preamble長、sync値
- header field確定
- CRCパラメータ確定
- ACK/NACK表現（type or flags）
