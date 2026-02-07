# FWのビルド/書き込み手順（MicroPython / Pico）

ファイル名：docs/fw_bringup_toggle_gp2.md

## 対象FW
- `fw/bringup_toggle_gp2/main.py`（GP2送信 / GP3受信の確認用）

## 手順（Thonny）
1. Raspberry Pi Pico をUSB接続する
2. Thonnyを起動し、Interpreter を `MicroPython (Raspberry Pi Pico)` に設定する
3. `fw/bringup_toggle_gp2/main.py` を開く
4. `Save` → 保存先に `Raspberry Pi Pico` を選び、ファイル名を `main.py` として保存する
5. `Run`（▶）で実行する

## 実行確認（最小）
- シリアル出力（ThonnyのShell）に `edges_per_sec` が表示される
- 50/100/200/500Hzで期待値近傍（100/200/400/1000）が出ることを確認する
