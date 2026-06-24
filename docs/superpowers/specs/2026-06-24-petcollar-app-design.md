# PetCollar-X1 手機 App 設計（驗證工具版）

**日期：** 2026-06-24
**專案：** PetCollar-X1 companion app
**框架：** Flutter + flutter_blue_plus
**對接韌體：** petcollar-x1-ble-firmware（Pet Collar Service，6 個特徵）

---

## 1. 目標與定位

做一個 **BLE 直連 PetCollar-X1 項圈的跨平台手機 App**，一份 Dart 程式碼同時上 Android 與 iOS。

這一版的定位是 **驗證工具，但架構為產品鋪路**：
- 功能上先做到「掃描 → 連線 → 讀寫全部 6 個特徵 → 即時顯示」，用來驗證韌體真的能用、能對人 demo。
- 架構上把「封包契約」獨立成穩定的一層，之後長成正式消費者 App 時這層不必重寫。

**非目標（本版不做）：** 手機 GPS 定位 / 地圖、資料落地（SQLite 歷史）、雲端 / server 同步、帳號登入、推播、正式產品級視覺設計。

---

## 2. 架構分層

四層，由下而上：

| 層 | 目錄 | 責任 | 依賴 |
|----|------|------|------|
| BLE 層 | `lib/ble/` | 封裝 flutter_blue_plus：掃描（用 service UUID 過濾）、連線、服務探索、訂閱 Notify、讀寫特徵。對外吐出每個特徵的原始 byte 流 + 連線狀態。**不懂封包意義。** | flutter_blue_plus |
| 模型層 ★ | `lib/models/` | 6 個封包 codec，一對一對齊韌體 header。`fromBytes()` / `toBytes()`，純 Dart、不碰 BLE。**產品核心、可單元測試。** | 無 |
| 狀態層 | `lib/controllers/` | 持有最新解析值 + 趨勢圖滾動緩衝；把 byte 流 → model → UI 狀態。 | 模型層、BLE 層 |
| UI 層 | `lib/screens/`, `lib/widgets/` | 掃描頁、儀表板、指令控制、設定編輯器。 | 狀態層 |

**分層理由：** 模型層完全不依賴 BLE，可用純 Dart 單元測試驗證解析正確（不需真機）；BLE 層只搬位元組、不懂語意，可替換；UI 層只看狀態。三層各自能獨立理解與測試。狀態管理統一用 **Riverpod**。

---

## 3. 螢幕流程

兩個畫面。

### 3.1 掃描頁 ScanScreen
- 開 App 自動掃描，用 Pet Collar Service 的 128-bit UUID 過濾，只列出 PetCollar 裝置。
- 列出找到的裝置 + RSSI 訊號強度。
- 點一下 → 連線 → 進儀表板。
- 空狀態（掃不到）顯示提示 + 重新掃描鈕。

### 3.2 儀表板 DashboardScreen
- 頂部狀態列：連線狀態、電量、RSSI。
- 特徵卡片（每個一張，Notify 即時更新）：
  - 📍 **位置**：項圈回報座標，**明確標示「目前為 firmware stub 假座標，非真實 GPS」**。
  - ❤️ **健康**：心率 / 血氧 / 體溫 + 心率即時趨勢小圖（fl_chart）。
  - 🐕 **行為**：行為分類文字、信心、步數。
  - 🔋 **狀態**：state、uptime。
- 指令區：`[尋找模式 開] [關] [校時]` → 寫 Command 特徵。
- 設定（可展開）：GNSS 間隔、心率上限等欄位 + `[讀取] [儲存]` → 讀 / 寫 Configuration 特徵。
- 連線中途斷掉 → 自動退回掃描頁或顯示重連。

---

## 4. 資料模型（封包解析）

6 個 Dart 類別一對一對齊韌體 header，全部 **little-endian**（Dart `ByteData` 用 `Endian.little`）。換算係數集中在此層，UI 拿到的是人看得懂的單位。

| 模型 | 大小 | 方向 | 欄位 / 換算 |
|------|------|------|------------|
| `Location` | 18 B | 讀 | `lat = lat_e7 / 1e7`、`lon = lon_e7 / 1e7`、`alt_m`(int16)、`accuracy_cm`(uint16)、`timestamp`(uint32)、`fix_type`(uint8)、`mode`(uint8) |
| `Health` | 8 B | 讀 | `heartRate = heart_rate / 10` BPM(uint16)、`spo2` %(uint8)、`temperature = temp / 10` °C(**int16, 可負**)、`signalQuality`(uint8)、`flags`(uint16, bit0=HR bit1=SpO2 bit2=Temp 有效) |
| `Behavior` | 6 B | 讀 | `behavior`(uint8 enum → 文字)、`confidence`(uint8 0-100)、`steps`(uint32) |
| `DeviceStatus` | 6 B | 讀 | `state`(uint8 enum)、`battery`(uint8 %)、`rssi`(**int8, signed dBm**)、`uptime`(3-byte LE → 秒) |
| `Command` | 4 B | **寫** | `cmd`(uint8 enum)、`param1`(uint8)、`param2`(uint16) → `toBytes()`，Write Without Response |
| `Config` | 20 B | 讀 + 寫 | `gnssInterval`、`healthInterval`、`alertHrMax`、`alertTempMax`(各 uint16)、`geofenceRadius`(uint32)、`flags`(uint8[8])，雙向 |

### Enum 對照（對齊韌體）
- `behavior_type`：0=睡覺 1=休息 2=走路 3=跑步 4=玩耍 5=抓癢 6=未知
- `pcs_command`：0x01=尋找開 0x02=尋找關 0x03=校時 0x04=設定 0x05=重啟(stub) 0x06=DFU(stub)
- `pcs_device_state`：0=idle 1=廣播中 2=已連線 3=定位中

### UUID（對齊韌體）
- Base：`A1B2C3D4-xxxx-1000-8000-00805F9B34FB`
- Service `0000`、Location `0101`、Health `0102`、Behavior `0103`、Command `0104`、Status `0105`、Config `0106`

### 解析規則
- signed 欄位（`rssi` int8、`temperature` int16）正確處理負值。
- enum 值對不到 → fallback「未知」，不 crash。
- 收到的 byte 長度與預期不符 → 拋明確錯誤，由狀態層接住顯示「資料異常」，不亂解析、不 crash。

---

## 5. 錯誤處理

原則：**永不 crash，給清楚提示。**

| 情境 | 處理 |
|------|------|
| 藍牙權限被拒 | 說明 + 引導去系統設定開啟 |
| 藍牙關閉 | 提示開啟藍牙 |
| 掃不到裝置 | 空狀態 + 重新掃描鈕 |
| 連線失敗 / 逾時 | 錯誤提示 + 重試 |
| 連線中途斷掉 | 自動退回掃描頁或顯示重連 |
| 找不到預期特徵（韌體版本不符） | 明確錯誤訊息，不 crash |
| 封包長度不對 | 模型層拋錯 → 狀態層接住 → 顯示「資料異常」 |
| 寫指令 / 設定失敗 | snackbar 提示失敗 |

**平台權限宣告：** Android `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT`（及舊版定位權限）；iOS `NSBluetoothAlwaysUsageDescription`。

---

## 6. 測試策略

| 層 | 怎麼測 | 需硬體 |
|----|--------|--------|
| 模型層（6 codec） | 純 Dart 單元測試：餵已知 bytes → 驗證解析 / 編碼，round-trip | ❌ |
| 狀態層 | 餵假 byte 流 → 驗證狀態轉換 | ❌ |
| BLE 層 | 保持薄，靠手動驗證 | — |
| 整體 | Flutter 跑起來 → 掃描連線真項圈 → 看 6 特徵互動 | ✅ Flutter + 手機 + 韌體 |

自動測試的安全網主要在 **模型層** —— 這是「看不懂 Dart 也能信任解析正確」的依據。

---

## 7. 環境限制（已知）

- Flutter / Dart 尚未安裝（實作階段需安裝 Flutter SDK）。
- 使用者目前遠端、無螢幕、無項圈硬體 → 本輪能做到「設計 + 寫程式 + 跑通模型 / 狀態層單元測試 + 推 GitHub」；「親眼看 UI、實機連項圈」需回到有螢幕 + 硬體的環境。
- 程式碼審查：使用者不讀 Dart，人工 code review 這關落在 AI + 自動測試；spec 與計畫以中文白話呈現供使用者審。

---

## 8. 專案位置

- App 程式碼：`/mnt/e/board/petcollar-app/`（獨立 git repo，對應韌體 repo `petcollar-x1-ble-firmware`）。

---

## 9. 成功標準

- 一份 Dart 程式碼可建置出 Android 與 iOS app。
- App 能用 service UUID 掃到 PetCollar-X1、連線、訂閱 4 個 Notify 特徵並即時顯示解析後數值。
- 能對 Command 特徵寫指令、讀寫 Configuration。
- 心率顯示即時趨勢圖。
- 模型層單元測試全數通過。
- 任何 BLE 失敗情境都不 crash，顯示清楚提示。
