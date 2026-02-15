# tools/README.md
目的：ログ取得・PER/BER集計に加えて `circuit_synth` を使うため、`uv` でPython環境を固定する。

---

## 1. Python方針
- 依存管理：`uv`（`pyproject.toml` + `uv.lock`）
- Python：3.12 以上（`circuit_synth` の要件）
- 仮想環境：`tools/.venv`（`uv` が自動作成）

---

## 2. セットアップ
1) `tools` に移動  
2) 依存を同期  
   `uv sync`  
3) 動作確認  
   `uv run python -c "import circuit_synth as cs; print(cs.__version__)"`

---

## 3. 主要パッケージ
- circuit_synth（回路生成）
- pyserial（UARTログ取得）
- pandas（CSV集計）
- rich（CLI表示）

---

## 4. 補足
- PDF出力を使う場合は `reportlab` が必要なため、必要時に `uv add reportlab` を実行する。

