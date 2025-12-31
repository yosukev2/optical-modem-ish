# wiring_w2.md（W2 暫定配線）

目的：送受信を最短で確認するための暫定配線。
対象：Pico + (Tx PLT133/T10W) + (Rx PLR237/T10BK) を想定。

---

## 0. 前提（W2）
- 速度：まず低速（例：0.5Mbps相当のトグルでもOK）
- 配線：最短（ジャンパは短く）
- まずは 1mのファイバーで確認

---

## 1. ピンアサイン

- TX_GPIO = GP2（Pico → Tx Vin）
- RX_GPIO = GP3（Rx Vout → Pico）
- GND = Pico GND
- 3V3 = Pico 3V3(OUT)

---

## 2. 配線（1ノードでのループバック試験）
構成：Pico1台に Tx + Rx を載せて、Tx→(fiber)→Rx を同一基板/同一机で確認する。

### Tx（PLT133/T10W）
- Vcc  → Pico 3V3(OUT)
- GND  → Pico GND
- Vin  → Pico TX_GPIO（GP2）
- 追加推奨：
  - Vin と GND の間に pull-down（例：100kΩ）
    理由：VinがFLOATINGでもONになる条件があるため（浮き＝事故）  

- デカップリング：
  - Vcc-GND間に 0.1uF

### Rx（PLR237/T10BK）
- Vcc  → Pico 3V3(OUT)
- GND  → Pico GND
- Vout → Pico RX_GPIO（GP3）
- デカップリング：
  - Vcc-GND間に 0.1uF
---

## 3. 配線（2ノード試験：Pico2台で相互）
構成：Node-A と Node-B に Tx/Rx をそれぞれ載せ、fiber2本で双方向。

- Node-A Tx → (fiber1) → Node-B Rx
- Node-B Tx → (fiber2) → Node-A Rx

注意：
- 光ファイバは絶縁。原則 Node-A GND と Node-B GND を直結する必要はない。
- ただしUSB給電や計測器接続で意図せずGNDが共有されることはある（問題ではないが把握する）

---

## 4. 電源供給の方針（W2はこれで固定）
優先順位：
1) Picoの 3V3(OUT) から Tx/Rx に供給（最短・構成が単純）
2) 外部3.3Vレギュレータで供給（長期的には安定、ただしW2では複雑化）

W2の決定：まず 1) で行く。

---

## 5. “詰まり”予防策チェックリスト（配線時に必ず見る）
- [ ] Tx Vin に pull-down を入れた（or GPIOが常に駆動されている）
- [ ] Tx/Rx の Vcc-GND に 0.1uF を部品の足元に置いた
- [ ] ジャンパ線は最短（特にVcc/GND）
- [ ] PicoのGNDとTx/RxのGNDが確実に同一点でつながっている
- [ ] fiberの向き（Tx→Rx）が正しい（刺し間違いを疑う）
