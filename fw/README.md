# fw/README.md
目的：W2で "必ずビルドして.uf2を作る" ための最小手順を固定する。

---

## 1. 前提
- OS：Windows（PowerShell想定）
- ボード：Raspberry Pi Pico (RP2040)
- SDK：pico-sdk **2.2.0 固定**（タグ固定。master追従しない）

---

## 2. 依存（インストール済みチェック）
必要：
- Git
- CMake
- Ninja（推奨）
- ARM GCC toolchain（arm-none-eabi-gcc）
- Python（ビルド補助で使う場合あり）

---

## 3. pico-sdk を取得（サブモジュール or 直clone）
推奨：repo直下に external/pico-sdk として置く

例：
- external/pico-sdk を作って clone
- tag 2.2.0 に checkout

---

## 4. ビルド手順（最小）
例：fw/blink をビルドする想定（W2はLED点滅でOK）

1) ビルドディレクトリ作成
2) cmake configure
3) ninja で build
4) .uf2 を Pico に書き込み

[TODO] 実際の fw 構成に合わせてコマンドを確定する
