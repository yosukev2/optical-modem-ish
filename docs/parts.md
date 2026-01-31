# docs/parts.md — Parts (Evidence) / 部品（根拠の置き場）

> **方針**：spec.md は「結論（採用品/方針）」、parts.md は「証拠（根拠表/一次ソース/購入リンク/代替）」。
> 在庫やURLは変動するので **parts.md を正** とし、spec.md には「参照先」だけを書きます。

- 最終更新: 2026-01-10
- 管理: GitHub Issue を変更履歴に残す（例: `[W2-01]`）

## 1. 採用部品一覧（MPN / 役割 / 一次ソース / 購入リンク）

| 区分 | 採用品（MPN / 型番） | 役割 | 一次ソース（データシート等） | 購入リンク（参考） | 備考 |
|---|---|---|---|---|---|
| MCUボード | **Raspberry Pi Pico (RP2040)** | W2の実機Bring-up、W3以降はヘッダ互換で載せ替え想定 | RP2040 Datasheet（I/O絶対最大・VIH/VILの根拠） | [Amazon] (https://www.amazon.co.jp/dp/B09229YRR4) | **Pico W / Pico 2 ではなく Pico（RP2040）前提** |
| Optical Tx | **Everlight PLT133/T10W** | POF光送信（TOSLINK系） | データシート（VCC/入力レベル/絶対最大/推奨回路） |[マルツ](https://www.marutsu.co.jp/pc/i/41237282/) | W2は3.3V動作で使用 |
| Optical Rx | **Everlight PLR237/T10BK** | POF光受信（TOSLINK系） | データシート（VCC/出力レベル/推奨回路） | [マルツ](https://www.marutsu.co.jp/pc/i/13672939/) | W2は3.3V動作で使用 |
| POFファイバ | **TOSLINK 光デジタルケーブル 1.0m** | Tx–Rxの接続（W2疎通確認） | 規格はTOSLINK/POF想定 | [Amazon（購入品）](https://www.amazon.co.jp/dp/B00L3KO5WK)  | “オーディオ用”でOK（まず動かす） |
| 電源（W3以降） | Polyfuse / TVS / LDO | VBUS(5V)→保護→3.3V | TBD | TBD | **W2はPicoの3V3(OUT)給電**、W3から基板で正式化 |

### 1.1 採用理由（入手性メモ）
- **PLT133/PLR237 を採用した理由**：購入可能な候補が実質これに収束したため（入手性優先）。

## 2. 整合説明（電源電圧とI/Oレベル）

**前提**：信号レベルは **3.3V系**（RP2040 IOVDD=3.3V）で統一する。

### 2.1 RP2040（Pico側）の入力条件（根拠）
- 入力 High 判定（IOVDD=3.3V）: **VIH(min)=2.0V**
- 入力 Low 判定（IOVDD=3.3V）: **VIL(max)=0.8V**
- 絶対最大（Digital IO）: **VPIN <= IOVDD + 0.5V**（= 3.3 + 0.5 = 3.8V 目安）  
  → 3.3V系以外（5V等）を直結しない
- 出典: RP2040 datasheet（Absolute Max / IO Electrical Characteristics）
- データシート: https://pip-assets.raspberrypi.com/categories/814-rp2040/documents/RP-008371-DS-1-rp2040-datasheet.pdf?disposition=inline

### 2.2 PLT133（Tx入力）← RP2040 GPIO 出力の整合
- PLT133 入力条件: **Vih(min)=2.0V, Vil(max)=0.8V**
- PLT133 絶対最大: **Vin <= Vcc + 0.5V**
- したがって、RP2040の 0/3.3V GPIO は PLT133 の入力条件を満たし、かつ絶対最大も超えない（Vcc=3.3V運用）。

### 2.3 PLR237（Rx出力）→ RP2040 GPIO 入力の整合
- [cite_start]PLR237 出力条件（Rev.1）: **VOH(min)=Vcc-0.4V**（@3.3V時 2.9V）[cite: 1351][cite_start], **VOL(max)=0.5V** 
- したがって、VOH(2.9V) > RP2040 VIH(min)(2.0V)、VOL(0.5V) < RP2040 VIL(max)(0.8V) となり、3.3V系で論理整合が取れる。

## 3. 根拠表（データシート抜粋）

### 3.1 Everlight PLT133/T10W（Tx）

> **設計メモ**
> - データシートは「推奨動作（Recommended）」と「絶対最大（Absolute Max）」を2段階で設計し、**推奨内に余裕を持って入れ**て設計、絶対最大は**一度でも超えると破損リスク**があるため死守するように設計。
> - 同様に、Vcc / Vin は「平均」ではなく **最悪値（min/max）**で判断する。特に **電源OFF中にVinが入る（逆給電）**が事故りやすい。

| 分類 | パラメータ | MIN | TYP | MAX | 単位 | 設計での意味（チェック観点） |
|---|---:|---:|---:|---:|---|---|
| 推奨動作 | Vcc（Supply Voltage） | 2.7 | 3.0 | 5.50 | V | 3.3V系で動作可。電源リップル/瞬断を含めて **2.7–5.5V** に収める。 |
| 入力（TTL） | Vih（High判定） | 2.0 | - | - | V | 駆動元GPIOのHighが2.0V以上であること（3.3V GPIOならOK）。 |
| 入力（TTL） | Vil（Low判定） | - | - | 0.8 | V | 駆動元GPIOのLowが0.8V以下であること（0VならOK）。 |
| 消費（電源） | Icc（Dissipation current） | - | 2.0 | 4.0 | mA | Max **4.0mA**。Tx(Max 10mA)と合わせても合計は**mA級（~14mA）**。W2は3V3(OUT)給電の暫定構成であり、大負荷は禁止。目安としてPico datasheetでは3V3ピン外部負荷は**300mA未満推奨**（断定せず“推奨”として扱う）。 |
| 絶対最大 | Vcc | -0.5 | - | 7 | V | **Vcc > 7V は破損リスク**。電源過渡（挿抜/スパイク）も含めて踏まない。 |
| 絶対最大 | Vin（DC input） | -0.5 | - | Vcc+0.5 | V | **Vin > Vcc+0.5V は破損リスク**（Vcc OFF中のGPIO Highなどで起きる）。**Vin < -0.5V も破損リスク**。 |
| 推奨回路 | デカップリング | 0.1 | - | - | µF | **最低0.1µF** をVcc–GND間に実装。部品近傍（目安：**7mm以内**）に置いて電源ループを最小化。 |
| 注意事項 | 電源OFF時の条件 | - | - | - | - | 「電源OFF時は **Vin と Vcc を一緒に切る**」旨の注意あり。Vcc=0のままVinを駆動しない（逆給電防止）。 |
| 注意事項 | 入力未定義（FLOAT） | - | - | - | - | Vccが有効でも **Vin=FLOATINGでLEDがONになり得る**。起動直後/リセット中にVinを浮かせない（FWでLow、回路でプルダウン）。 |

**“壊れる条件”（要点）**  
- **Vin が Vcc+0.5V を超える**（例：Vcc OFF中にGPIO High、5V信号直結）  
- **Vin が -0.5V 未満になる**（負電圧・リンギング）  
- **Vcc が 7V を超える**（電源スパイク含む）

- 一次ソース: Everlight PLT133/T10W datasheet（Rev.5）
### 3.2 Everlight PLR237/T10BK（Rx）

| 分類 | パラメータ | MIN | TYP | MAX | 単位 | 設計での意味（チェック観点） |
|---|---:|---:|---:|---:|---|---|
| 推奨動作 | Vcc（Supply Voltage） | 3.0 | - | 5.50 | V | [cite_start]3.3V動作OK（Min 3.0V）[cite: 1349]。 |
| 出力（TTL） | VOH（High出力） | Vcc-0.4 | - | - | V | [cite_start]Vcc=3.3V時、Min **2.9V** 。RP2040 VIH(2.0V)に対しマージンあり。 |
| 出力（TTL） | VOL（Low出力） | - | 0.4 | 0.5 | V | [cite_start]Max **0.5V** 。RP2040 VIL(0.8V)に対しマージンあり。 |
| 消費（電源） | Icc（Dissipation current） | - | 2.0 | 4.0 | mA | [cite_start]Max **4.0mA** 。Tx(10mA)と合わせてもPicoの供給能力内。 |
| **絶対最大** | Vcc | -0.5 | - | **5.5** | V | [cite_start]**Vcc > 5.5V で破損リスク** 。Tx(7V)より耐圧が低い点に注意。 |
| **絶対最大** | Vout | - | - | Vcc+0.3 | V | [cite_start]**Vout > Vcc+0.3V で破損リスク** 。出力ピンへの過電圧印加禁止。 |
| 推奨回路 | バイパスコンデンサ | 0.1 | - | - | µF | [cite_start]**必須**。部品近傍（**7mm以内**）に配置 。 |
| 注意事項 | 半田付け温度 | - | - | 260 | °C | [cite_start]260°C以下、**10秒以内** 。 |

- データシート: https://mm.digikey.com/Volume0/opasdata/d220001/medias/docus/5335/PLR237-T10BK_Rev1_3-30-21.pdf

### 3.3 RP2040（参考：I/O絶対最大 & 入力閾値）
- データシート: https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf
- 参照箇所（目安）：Pin Specifications（Absolute Maximum Ratings / IO Electrical Characteristics）

## 4. 代替候補（バックアップ）: TOTX/TORX

> **目的**：採用品（PLT/PLR）を揺らさずに、調達停止リスクを下げる “保険” を置く。

| セット | 候補 | 想定VCC | 使うときの注意 | 一次ソース |
|---|---|---:|---|---|
| 3.3V系 | TOTX147AL (Tx) / TORX147L (Rx) | 3.3V系 | **I/O整合（VOH/VOL/VIH/VIL）を再確認**。フットプリント/ピン配置も再確認。 | メーカ/代理店データシート（後でURL追記） |
| 5V系 | TOTX173 (Tx) / TORX173 (Rx) | 5V系 | **RP2040は5V直結不可**。レベル変換や抵抗/トランジスタが必要になる可能性。 | （例）Mouser掲載のToshibaデータシート |

- 5V系 参考（Mouser）: https://www.mouser.com/datasheet/2/408/totx173_torx173-1181045.pdf

## 5. 電源保護・LDO候補（W3用 / TBD）

- Polyfuse: TBD  
- TVS: TBD  
- LDO: TBD  
- **選定時に見る観点**（メモ）
  - VBUS入力（5V）での定格、逆接/サージ保護（TVSのクランプ、許容パルス）
  - LDOの dropout、最大電流、発熱（θJA）、PSRR、推奨コンデンサ条件

## 6. 変更履歴（Issueトレーサビリティ）
- 2026-01-10: 初版作成（W2-01）
