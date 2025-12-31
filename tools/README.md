# tools/README.md
目的：ログ取得・PER/BER集計を回すための最小Python環境を固定する。

---

## 1. Python方針
- Python：3.11 以上（推奨）
- venv を必ず使う（グローバルに入れない）

---

## 2. セットアップ
1) venv 作成
2) 有効化
3) 必要パッケージを入れる

---

## 3. 必須パッケージ
- pyserial（UARTログ取得）
- pandas（CSV集計：後で使う）
- rich（CLIの見栄え：任意）

