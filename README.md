# PetCollar-X1 Companion App

PetCollar-X1 智慧寵物項圈的 **跨平台手機 App**（Flutter，一份 Dart 程式碼同時上 Android 與 iOS）。透過 BLE 直連項圈，掃描、連線、讀寫全部 6 個 GATT 特徵並即時顯示。

對接韌體：[petcollar-x1-ble-firmware](https://github.com/bruce30709/petcollar-x1-ble-firmware)（Pet Collar Service）。

---

## 定位

本版是 **驗證工具，架構為產品鋪路**：
- 功能上：掃描 → 連線 → 讀寫 6 特徵 → 即時顯示，用來驗證韌體並做 demo。
- 架構上：把「封包契約」獨立成穩定、可單元測試的一層，之後可長成正式消費者 App。

**本版不做**：手機 GPS / 地圖、資料落地（SQLite）、雲端 / server、帳號、推播。

---

## 架構（四層）

| 層 | 目錄 | 責任 |
|----|------|------|
| BLE 層 | `lib/ble/` | 封裝 flutter_blue_plus：掃描（service UUID 過濾）、連線、訂閱、讀寫。不懂封包意義。 |
| 模型層 ★ | `lib/models/` | 6 個封包 codec，對齊韌體 header，`fromBytes()` / `toBytes()`。純 Dart、可單元測試。 |
| 狀態層 | `lib/controllers/` | Riverpod：byte 流 → model → UI 狀態 + 心率趨勢緩衝。 |
| UI 層 | `lib/screens/`, `lib/widgets/` | 掃描頁、儀表板、指令、設定。 |

模型層不依賴 BLE，是測試與產品延續的核心。

---

## GATT 特徵對應

| 特徵 | UUID `xxxx` | 方向 | 顯示 |
|------|------------|------|------|
| 位置 | `0101` | 讀 | 座標（**標示 firmware stub 假座標，非真實 GPS**） |
| 健康 | `0102` | 讀 | 心率 / 血氧 / 體溫 + 心率趨勢圖 |
| 行為 | `0103` | 讀 | 行為分類 / 信心 / 步數 |
| 指令 | `0104` | 寫 | 尋找開 / 關 / 校時 |
| 裝置狀態 | `0105` | 讀 | state / 電量 / RSSI / uptime |
| 設定 | `0106` | 讀+寫 | GNSS / 健康間隔、告警上限等 |

Base UUID：`A1B2C3D4-xxxx-1000-8000-00805F9B34FB`，全部封包 little-endian。

---

## 開發

```bash
# 安裝依賴
flutter pub get

# 跑單元測試（模型層 + 狀態層，不需硬體）
flutter test

# 跑 App（需手機 / 模擬器）
flutter run
```

**技術棧**：Flutter 3.44+ / Dart 3.12+、flutter_blue_plus、flutter_riverpod、fl_chart。

---

## 測試

- **模型層 6 codec + 狀態層**：純 Dart 單元測試，`flutter test` 即可，不需硬體。共 14 項測試。
- **整體 / UI**：需 Flutter + 手機 + 項圈韌體實機驗證。

---

## 已知限制

- 實機跑 UI、連項圈需 **Flutter SDK + 手機 / 模擬器 + 韌體硬體**。
- Android build 需 Android SDK；iOS build 需 macOS + Xcode。
- 平台權限已宣告：Android `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` / `ACCESS_FINE_LOCATION`；iOS `NSBluetoothAlwaysUsageDescription`。
