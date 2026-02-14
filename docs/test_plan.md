# Test Plan

## 目的
通信リンクの品質（BER/PER）と機能（同期/再送/モード切替）を、**条件・合否基準・ログ**まで含めて再現可能に試験する。

---

## 1. テスト条件（マトリクス：別ファイル推奨）
- Vcc: 3.0 / 3.3 / 3.6 V（予定）
- rate: 0.5 / 1 / 2 Mbps
- mode: A / B
- power: 0 / 1 / 2
- cable: short / long

> 実体：`docs/test_matrix.csv`（後で追加）

---

## 2. 試験ID一覧（ヘッダだけ：W1テンプレ）
| Test ID | Category | Purpose | Setup | Procedure | Expected Result | Pass/Fail Criteria | Log Output | Notes |
|---|---|---|---|---|---|---|---|---|
| TP-001 | Power |  |  |  |  |  |  |  |
| TP-002 | Bring-up |  |  |  |  |  |  |  |
| TL-001 | Link |  |  |  |  |  |  |  |
| TM-001 | Mode |  |  |  |  |  |  |  |
| TQ-001 | Quality(PER) |  |  |  |  |  |  |  |
| TQ-002 | Quality(BER) |  |  |  |  |  |  |  |

---

## 3. 合否基準（仮置き）
- PER: TBD（例：< 1e-3）
- BER: TBD（例：< 1e-6）
- 連続運転：TBD（例：10分無停止）

---

## 4. ログ
- Format: `docs/log_format.md` に従う
- 保存先: `logs/`（後で命名規則を確定）
