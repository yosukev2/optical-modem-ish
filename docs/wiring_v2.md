# wiring_v2.md — 配線（本番用）: USB VBUS(5V) → 保護 → LDO → +3V3 → MCU/Tx/Rx

## ネット（固定）
電源系
- VBUS_IN: USBコネクタのVBUS(5V)
- VBUS_PROT: Polyfuse後、LDO手前の5V
- +3V3: LDO出力の3.3V配布
- GND: 全体GND（USBのGNDと同一）
- LDO_EN: LDO enable（任意。作るなら名前固定）

信号系（例）
- GP_TX: MCU→Tx入力
- GP_RX: Rx出力→MCU入力

期待電圧（テスター）
- VBUS_IN: 約5V
- VBUS_PROT: 約5V
- +3V3: 約3.3V

## 全体配線（ブロック）
    USBコネクタ
      |
      |  VBUS_IN
      +-----> TVS: VBUS_IN → GND
      |
      +-----> Polyfuse(直列): VBUS_IN → VBUS_PROT → LDO(IN)
                                         LDO(OUT) → +3V3配布
                                         LDO(GND) → GND
                                         LDO(EN)  → LDO_EN（任意）

    +3V3配布 → MCU 3V3
    GND      → MCU GND

    +3V3配布 → Tx Vcc
    GND      → Tx GND
    GP_TX    → Tx Vin

    +3V3配布 → Rx Vcc
    GND      → Rx GND
    Rx Vout  → GP_RX

    Tx（光） → POF → Rx（光）

## 配置ルール（実装のコツ）
- TVSはUSBコネクタ直近（VBUS_INとGNDへの経路を短く太く）
- Polyfuseはコネクタ直後〜LDO手前（VBUS_IN直列）
- LDOは負荷（3.3Vを使う回路）に近め
- LDOの入力/出力コンデンサはLDOの足元に置く
- GNDは1系統に統一（別GND名を増やさない）

## 部品の接続（回路図でやること）
USBコネクタ
- VBUSピン → VBUS_IN
- GNDピン → GND

TVS（プレースホルダ）
- 片側 → VBUS_IN
- 片側 → GND

Polyfuse（プレースホルダ）
- 直列で挿入: VBUS_IN → VBUS_PROT

LDO（プレースホルダ）
- IN  → VBUS_PROT
- OUT → +3V3
- GND → GND
- EN  → LDO_EN（任意。使わないなら既知レベル固定、またはEN無し品を採用）

コンデンサ（推奨。プレースホルダで席確保）
- C_IN: VBUS_PROT ↔ GND（LDO近接）
- C_OUT: +3V3 ↔ GND（LDO近接）
- Tx/Rxそれぞれ: Vcc ↔ GND に0.1uFを近接

MCU（例: Pico互換ヘッダ）
- MCU 3.3Vピン → +3V3
- MCU GNDピン → GND
- MCU GPIO → GP_TX / GP_RX

Tx（PLT133）
- Vcc → +3V3
- GND → GND
- Vin → GP_TX

Rx（PLR237）
- Vcc → +3V3
- GND → GND
- Vout → GP_RX

## テストポイント（推奨）
- TP_GND: GND
- TP_VBUS_IN: VBUS_IN
- TP_VBUS_PROT: VBUS_PROT
- TP_3V3: +3V3
- TP_TX: GP_TX（任意）
- TP_RX: GP_RX（任意）

