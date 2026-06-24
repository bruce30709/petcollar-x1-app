# PetCollar-X1 Companion App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Flutter 做一個跨平台手機 App，掃描並連線 PetCollar-X1 項圈，讀寫全部 6 個 GATT 特徵並即時顯示。

**Architecture:** 四層 —— BLE 層（封裝 flutter_blue_plus）、模型層（6 個封包 codec，純 Dart、可單元測試）、狀態層（Riverpod）、UI 層（掃描頁 + 儀表板）。模型層不依賴 BLE，是測試與產品延續的核心。

**Tech Stack:** Flutter / Dart、flutter_blue_plus（BLE）、flutter_riverpod（狀態）、fl_chart（趨勢圖）。

**對接韌體 UUID base:** `A1B2C3D4-xxxx-1000-8000-00805F9B34FB`（Service `0000`、Location `0101`、Health `0102`、Behavior `0103`、Command `0104`、Status `0105`、Config `0106`）。所有封包 **little-endian**。

---

## File Structure

```
petcollar-app/
├── pubspec.yaml
├── lib/
│   ├── main.dart                         # App 入口 + Riverpod ProviderScope
│   ├── ble/
│   │   ├── pcs_uuids.dart                 # UUID 常數
│   │   └── ble_service.dart              # flutter_blue_plus 封裝
│   ├── models/
│   │   ├── enums.dart                    # behavior/command/state enum
│   │   ├── location.dart                 # Location codec (18B, 讀)
│   │   ├── health.dart                   # Health codec (8B, 讀)
│   │   ├── behavior.dart                 # Behavior codec (6B, 讀)
│   │   ├── device_status.dart            # DeviceStatus codec (6B, 讀)
│   │   ├── command.dart                  # Command codec (4B, 寫)
│   │   └── config.dart                   # Config codec (20B, 讀+寫)
│   ├── controllers/
│   │   └── collar_controller.dart        # 連線 + 解析值狀態 + 趨勢緩衝
│   ├── screens/
│   │   ├── scan_screen.dart
│   │   └── dashboard_screen.dart
│   └── widgets/
│       ├── characteristic_card.dart
│       ├── command_panel.dart
│       └── config_panel.dart
├── test/
│   ├── health_test.dart
│   ├── location_test.dart
│   ├── behavior_test.dart
│   ├── device_status_test.dart
│   ├── command_test.dart
│   ├── config_test.dart
│   └── collar_controller_test.dart
├── android/app/src/main/AndroidManifest.xml   # 權限
└── ios/Runner/Info.plist                      # 權限
```

---

## Task 0: 環境與專案骨架

**Files:**
- Create: 整個 Flutter 專案骨架

- [ ] **Step 1: 安裝 Flutter SDK**

```bash
cd $HOME
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$HOME/flutter/bin:$PATH"
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
flutter --version
```
Expected: 印出 Flutter 版本（首次會下載 Dart SDK，需數分鐘）。

- [ ] **Step 2: 在現有 repo 內建立 Flutter 專案**

`/mnt/e/board/petcollar-app` 已是 git repo（含 docs/）。在其中就地建立 Flutter 結構：

```bash
cd /tmp && flutter create --org com.petcollar --project-name petcollar_app petcollar_app_tmp
# 複製產生的骨架到既有 repo（保留 docs/ 與 .git）
cp -r /tmp/petcollar_app_tmp/{lib,test,android,ios,pubspec.yaml,analysis_options.yaml} /mnt/e/board/petcollar-app/
rm -rf /tmp/petcollar_app_tmp
```
Expected: `/mnt/e/board/petcollar-app/lib/main.dart` 等檔案出現。

- [ ] **Step 3: 加入依賴**

編輯 `pubspec.yaml`，在 `dependencies:` 下加入：
```yaml
  flutter_blue_plus: ^1.32.0
  flutter_riverpod: ^2.5.0
  fl_chart: ^0.68.0
```
然後：
```bash
cd /mnt/e/board/petcollar-app && flutter pub get
```
Expected: `Got dependencies!`。

- [ ] **Step 4: 確認測試框架可跑**

```bash
cd /mnt/e/board/petcollar-app && flutter test
```
Expected: 預設 widget_test 通過（或刪除預設 test/widget_test.dart 後 `No tests found`）。先刪預設測試：
```bash
rm -f test/widget_test.dart
```

- [ ] **Step 5: Commit**

```bash
cd /mnt/e/board/petcollar-app
git add -A
git commit -m "chore: scaffold Flutter project with BLE/riverpod/chart deps"
```

---

## Task 1: UUID 與 Enum 常數

**Files:**
- Create: `lib/ble/pcs_uuids.dart`
- Create: `lib/models/enums.dart`

- [ ] **Step 1: 寫 UUID 常數**

`lib/ble/pcs_uuids.dart`：
```dart
/// Pet Collar Service UUIDs. Base: A1B2C3D4-xxxx-1000-8000-00805F9B34FB
class PcsUuids {
  static String _u(String x) => 'a1b2c3d4-$x-1000-8000-00805f9b34fb';

  static final String service  = _u('0000');
  static final String location = _u('0101');
  static final String health   = _u('0102');
  static final String behavior = _u('0103');
  static final String command  = _u('0104');
  static final String status   = _u('0105');
  static final String config   = _u('0106');
}
```

- [ ] **Step 2: 寫 enum**

`lib/models/enums.dart`：
```dart
enum BehaviorType {
  sleeping, resting, walking, running, playing, scratching, unknown;

  static BehaviorType fromByte(int b) =>
      (b >= 0 && b < BehaviorType.values.length)
          ? BehaviorType.values[b]
          : BehaviorType.unknown;

  String get label => const {
        BehaviorType.sleeping: '睡覺',
        BehaviorType.resting: '休息',
        BehaviorType.walking: '走路',
        BehaviorType.running: '跑步',
        BehaviorType.playing: '玩耍',
        BehaviorType.scratching: '抓癢',
        BehaviorType.unknown: '未知',
      }[this]!;
}

enum PcsCommand {
  findModeOn(0x01),
  findModeOff(0x02),
  syncTime(0x03),
  setConfig(0x04),
  reboot(0x05),
  dfuMode(0x06);

  const PcsCommand(this.value);
  final int value;
}

enum DeviceState {
  idle, advertising, connected, locating, unknown;

  static DeviceState fromByte(int b) =>
      (b >= 0 && b < DeviceState.values.length - 1)
          ? DeviceState.values[b]
          : DeviceState.unknown;

  String get label => const {
        DeviceState.idle: '閒置',
        DeviceState.advertising: '廣播中',
        DeviceState.connected: '已連線',
        DeviceState.locating: '定位中',
        DeviceState.unknown: '未知',
      }[this]!;
}
```

- [ ] **Step 3: Commit**

```bash
cd /mnt/e/board/petcollar-app
git add lib/ble/pcs_uuids.dart lib/models/enums.dart
git commit -m "feat: add PCS UUIDs and packet enums"
```

---

## Task 2: 讀取模型 codec（Health / Location / Behavior / DeviceStatus）

**Files:**
- Create: `lib/models/health.dart`, `location.dart`, `behavior.dart`, `device_status.dart`
- Test: `test/health_test.dart`, `location_test.dart`, `behavior_test.dart`, `device_status_test.dart`

> 測試設計說明：用「黃金位元組向量」測 `fromBytes`。Health 用韌體 stub 的真實值手算向量；其餘用 `ByteData` 在測試中以明確 offset 寫入欄位，再驗證解析（測試的 offset 寫死，與實作獨立，能抓出 offset 錯誤）。

- [ ] **Step 1: 寫 Health 失敗測試**

`test/health_test.dart`：
```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/health.dart';

void main() {
  test('Health.fromBytes parses firmware stub vector', () {
    // 韌體 stub: hr=720, spo2=98, temp=385, sig=85, flags=0x07
    final bytes = Uint8List.fromList(
        [0xD0, 0x02, 0x62, 0x81, 0x01, 0x55, 0x07, 0x00]);
    final h = Health.fromBytes(bytes);
    expect(h.heartRate, 72.0);
    expect(h.spo2, 98);
    expect(h.temperature, 38.5);
    expect(h.signalQuality, 85);
    expect(h.hrValid, true);
    expect(h.spo2Valid, true);
    expect(h.tempValid, true);
  });

  test('Health.fromBytes rejects wrong length', () {
    expect(() => Health.fromBytes(Uint8List(7)), throwsFormatException);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd /mnt/e/board/petcollar-app && flutter test test/health_test.dart`
Expected: FAIL（`health.dart` 不存在）。

- [ ] **Step 3: 寫 Health 實作**

`lib/models/health.dart`：
```dart
import 'dart:typed_data';

class Health {
  final double heartRate;   // BPM
  final int spo2;           // %
  final double temperature; // °C
  final int signalQuality;
  final int flags;

  Health({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.signalQuality,
    required this.flags,
  });

  bool get hrValid => flags & 0x01 != 0;
  bool get spo2Valid => flags & 0x02 != 0;
  bool get tempValid => flags & 0x04 != 0;

  static Health fromBytes(Uint8List bytes) {
    if (bytes.length != 8) {
      throw FormatException('Health expects 8 bytes, got ${bytes.length}');
    }
    final d = ByteData.sublistView(bytes);
    return Health(
      heartRate: d.getUint16(0, Endian.little) / 10.0,
      spo2: d.getUint8(2),
      temperature: d.getInt16(3, Endian.little) / 10.0,
      signalQuality: d.getUint8(5),
      flags: d.getUint16(6, Endian.little),
    );
  }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd /mnt/e/board/petcollar-app && flutter test test/health_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: 寫 Location 測試 + 實作**

`test/location_test.dart`：
```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/location.dart';

void main() {
  test('Location.fromBytes parses fields', () {
    final b = ByteData(18);
    b.setInt32(0, 250330000, Endian.little);   // lat_e7 -> 25.033
    b.setInt32(4, 1215654000, Endian.little);  // lon_e7 -> 121.5654
    b.setInt16(8, 10, Endian.little);          // alt_m
    b.setUint16(10, 150, Endian.little);       // accuracy_cm
    b.setUint32(12, 1719187200, Endian.little);// timestamp
    b.setUint8(16, 2);                         // fix_type
    b.setUint8(17, 1);                         // mode
    final loc = Location.fromBytes(b.buffer.asUint8List());
    expect(loc.latitude, closeTo(25.033, 1e-6));
    expect(loc.longitude, closeTo(121.5654, 1e-6));
    expect(loc.altitudeM, 10);
    expect(loc.accuracyCm, 150);
    expect(loc.fixType, 2);
    expect(loc.mode, 1);
  });

  test('Location.fromBytes rejects wrong length', () {
    expect(() => Location.fromBytes(Uint8List(17)), throwsFormatException);
  });
}
```
`lib/models/location.dart`：
```dart
import 'dart:typed_data';

class Location {
  final double latitude;
  final double longitude;
  final int altitudeM;
  final int accuracyCm;
  final int timestamp;
  final int fixType;
  final int mode;

  Location({
    required this.latitude,
    required this.longitude,
    required this.altitudeM,
    required this.accuracyCm,
    required this.timestamp,
    required this.fixType,
    required this.mode,
  });

  static Location fromBytes(Uint8List bytes) {
    if (bytes.length != 18) {
      throw FormatException('Location expects 18 bytes, got ${bytes.length}');
    }
    final d = ByteData.sublistView(bytes);
    return Location(
      latitude: d.getInt32(0, Endian.little) / 1e7,
      longitude: d.getInt32(4, Endian.little) / 1e7,
      altitudeM: d.getInt16(8, Endian.little),
      accuracyCm: d.getUint16(10, Endian.little),
      timestamp: d.getUint32(12, Endian.little),
      fixType: d.getUint8(16),
      mode: d.getUint8(17),
    );
  }
}
```

- [ ] **Step 6: 寫 Behavior 測試 + 實作**

`test/behavior_test.dart`：
```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/behavior.dart';
import 'package:petcollar_app/models/enums.dart';

void main() {
  test('Behavior.fromBytes parses fields', () {
    final b = ByteData(6);
    b.setUint8(0, 2);                       // walking
    b.setUint8(1, 80);                      // confidence
    b.setUint32(2, 1234, Endian.little);    // steps
    final beh = Behavior.fromBytes(b.buffer.asUint8List());
    expect(beh.type, BehaviorType.walking);
    expect(beh.confidence, 80);
    expect(beh.steps, 1234);
  });

  test('Behavior.fromBytes rejects wrong length', () {
    expect(() => Behavior.fromBytes(Uint8List(5)), throwsFormatException);
  });
}
```
`lib/models/behavior.dart`：
```dart
import 'dart:typed_data';
import 'enums.dart';

class Behavior {
  final BehaviorType type;
  final int confidence;
  final int steps;

  Behavior({required this.type, required this.confidence, required this.steps});

  static Behavior fromBytes(Uint8List bytes) {
    if (bytes.length != 6) {
      throw FormatException('Behavior expects 6 bytes, got ${bytes.length}');
    }
    final d = ByteData.sublistView(bytes);
    return Behavior(
      type: BehaviorType.fromByte(d.getUint8(0)),
      confidence: d.getUint8(1),
      steps: d.getUint32(2, Endian.little),
    );
  }
}
```

- [ ] **Step 7: 寫 DeviceStatus 測試 + 實作**

`test/device_status_test.dart`：
```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/device_status.dart';
import 'package:petcollar_app/models/enums.dart';

void main() {
  test('DeviceStatus parses fields incl signed rssi and 24-bit uptime', () {
    final b = ByteData(6);
    b.setUint8(0, 1);            // advertising
    b.setUint8(1, 85);           // battery
    b.setInt8(2, -60);           // rssi (signed)
    b.setUint8(3, 0x10);         // uptime LE byte0
    b.setUint8(4, 0x27);         // byte1
    b.setUint8(5, 0x00);         // byte2  -> 0x002710 = 10000
    final s = DeviceStatus.fromBytes(b.buffer.asUint8List());
    expect(s.state, DeviceState.advertising);
    expect(s.batteryPct, 85);
    expect(s.rssi, -60);
    expect(s.uptimeSec, 10000);
  });

  test('DeviceStatus rejects wrong length', () {
    expect(() => DeviceStatus.fromBytes(Uint8List(5)), throwsFormatException);
  });
}
```
`lib/models/device_status.dart`：
```dart
import 'dart:typed_data';
import 'enums.dart';

class DeviceStatus {
  final DeviceState state;
  final int batteryPct;
  final int rssi;       // signed dBm
  final int uptimeSec;

  DeviceStatus({
    required this.state,
    required this.batteryPct,
    required this.rssi,
    required this.uptimeSec,
  });

  static DeviceStatus fromBytes(Uint8List bytes) {
    if (bytes.length != 6) {
      throw FormatException('DeviceStatus expects 6 bytes, got ${bytes.length}');
    }
    final d = ByteData.sublistView(bytes);
    final uptime = d.getUint8(3) | (d.getUint8(4) << 8) | (d.getUint8(5) << 16);
    return DeviceStatus(
      state: DeviceState.fromByte(d.getUint8(0)),
      batteryPct: d.getUint8(1),
      rssi: d.getInt8(2),
      uptimeSec: uptime,
    );
  }
}
```

- [ ] **Step 8: 跑全部讀取模型測試**

Run: `cd /mnt/e/board/petcollar-app && flutter test test/health_test.dart test/location_test.dart test/behavior_test.dart test/device_status_test.dart`
Expected: 全部 PASS。

- [ ] **Step 9: Commit**

```bash
cd /mnt/e/board/petcollar-app
git add lib/models test/health_test.dart test/location_test.dart test/behavior_test.dart test/device_status_test.dart
git commit -m "feat: read-model codecs (health/location/behavior/status) with tests"
```

---

## Task 3: 寫入模型 codec（Command / Config）

**Files:**
- Create: `lib/models/command.dart`, `lib/models/config.dart`
- Test: `test/command_test.dart`, `test/config_test.dart`

- [ ] **Step 1: 寫 Command 測試**

`test/command_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/command.dart';
import 'package:petcollar_app/models/enums.dart';

void main() {
  test('Command.toBytes encodes cmd + params little-endian', () {
    final bytes = CollarCommand(
      cmd: PcsCommand.findModeOn,
      param1: 0xAB,
      param2: 0x1234,
    ).toBytes();
    expect(bytes, [0x01, 0xAB, 0x34, 0x12]); // param2 LE
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd /mnt/e/board/petcollar-app && flutter test test/command_test.dart`
Expected: FAIL（`command.dart` 不存在）。

- [ ] **Step 3: 寫 Command 實作**

`lib/models/command.dart`：
```dart
import 'dart:typed_data';
import 'enums.dart';

class CollarCommand {
  final PcsCommand cmd;
  final int param1;
  final int param2;

  CollarCommand({required this.cmd, this.param1 = 0, this.param2 = 0});

  Uint8List toBytes() {
    final d = ByteData(4);
    d.setUint8(0, cmd.value);
    d.setUint8(1, param1);
    d.setUint16(2, param2, Endian.little);
    return d.buffer.asUint8List();
  }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd /mnt/e/board/petcollar-app && flutter test test/command_test.dart`
Expected: PASS。

- [ ] **Step 5: 寫 Config 測試（round-trip）+ 實作**

`test/config_test.dart`：
```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/config.dart';

void main() {
  test('Config round-trips through bytes', () {
    final c = CollarConfig(
      gnssIntervalS: 30,
      healthIntervalS: 60,
      alertHrMax: 1500,
      alertTempMax: 400,
      geofenceRadiusM: 100,
      flags: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
    );
    final back = CollarConfig.fromBytes(c.toBytes());
    expect(back.gnssIntervalS, 30);
    expect(back.healthIntervalS, 60);
    expect(back.alertHrMax, 1500);
    expect(back.alertTempMax, 400);
    expect(back.geofenceRadiusM, 100);
    expect(back.flags, [1, 2, 3, 4, 5, 6, 7, 8]);
  });

  test('Config.toBytes is 20 bytes', () {
    final c = CollarConfig(
      gnssIntervalS: 0, healthIntervalS: 0, alertHrMax: 0,
      alertTempMax: 0, geofenceRadiusM: 0, flags: Uint8List(8),
    );
    expect(c.toBytes().length, 20);
  });

  test('Config.fromBytes rejects wrong length', () {
    expect(() => CollarConfig.fromBytes(Uint8List(19)), throwsFormatException);
  });
}
```
`lib/models/config.dart`：
```dart
import 'dart:typed_data';

class CollarConfig {
  final int gnssIntervalS;
  final int healthIntervalS;
  final int alertHrMax;
  final int alertTempMax;
  final int geofenceRadiusM;
  final Uint8List flags; // 8 bytes

  CollarConfig({
    required this.gnssIntervalS,
    required this.healthIntervalS,
    required this.alertHrMax,
    required this.alertTempMax,
    required this.geofenceRadiusM,
    required this.flags,
  });

  Uint8List toBytes() {
    final d = ByteData(20);
    d.setUint16(0, gnssIntervalS, Endian.little);
    d.setUint16(2, healthIntervalS, Endian.little);
    d.setUint16(4, alertHrMax, Endian.little);
    d.setUint16(6, alertTempMax, Endian.little);
    d.setUint32(8, geofenceRadiusM, Endian.little);
    final out = d.buffer.asUint8List();
    out.setRange(12, 20, flags);
    return out;
  }

  static CollarConfig fromBytes(Uint8List bytes) {
    if (bytes.length != 20) {
      throw FormatException('Config expects 20 bytes, got ${bytes.length}');
    }
    final d = ByteData.sublistView(bytes);
    return CollarConfig(
      gnssIntervalS: d.getUint16(0, Endian.little),
      healthIntervalS: d.getUint16(2, Endian.little),
      alertHrMax: d.getUint16(4, Endian.little),
      alertTempMax: d.getUint16(6, Endian.little),
      geofenceRadiusM: d.getUint32(8, Endian.little),
      flags: Uint8List.fromList(bytes.sublist(12, 20)),
    );
  }
}
```

- [ ] **Step 6: 跑測試確認通過**

Run: `cd /mnt/e/board/petcollar-app && flutter test test/command_test.dart test/config_test.dart`
Expected: 全部 PASS。

- [ ] **Step 7: Commit**

```bash
cd /mnt/e/board/petcollar-app
git add lib/models/command.dart lib/models/config.dart test/command_test.dart test/config_test.dart
git commit -m "feat: write-model codecs (command/config) with tests"
```

---

## Task 4: BLE 服務層

**Files:**
- Create: `lib/ble/ble_service.dart`

> BLE 層難自動測（需真實藍牙），保持薄。封裝 flutter_blue_plus，對外提供 scan / connect / 各特徵的 byte stream / write。

- [ ] **Step 1: 寫 BleService**

`lib/ble/ble_service.dart`：
```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'pcs_uuids.dart';

class BleService {
  BluetoothDevice? _device;
  final Map<String, BluetoothCharacteristic> _chars = {};

  /// 掃描，只回傳含 Pet Collar Service 的裝置。
  Stream<List<ScanResult>> scan() {
    FlutterBluePlus.startScan(
      withServices: [Guid(PcsUuids.service)],
      timeout: const Duration(seconds: 10),
    );
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  /// 連線並探索特徵，把 6 個特徵存進 _chars。
  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    await device.connect(timeout: const Duration(seconds: 15));
    final services = await device.discoverServices();
    final svc = services.firstWhere(
      (s) => s.uuid.str128.toLowerCase() == PcsUuids.service,
      orElse: () => throw StateError('Pet Collar Service 不存在（韌體不符）'),
    );
    for (final c in svc.characteristics) {
      _chars[c.uuid.str128.toLowerCase()] = c;
    }
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _chars.clear();
    _device = null;
  }

  Stream<BluetoothConnectionState> get connectionState =>
      _device?.connectionState ?? const Stream.empty();

  /// 訂閱某特徵的 Notify，回傳 byte stream。
  Stream<Uint8List> subscribe(String uuid) {
    final c = _chars[uuid];
    if (c == null) throw StateError('特徵 $uuid 不存在');
    c.setNotifyValue(true);
    return c.lastValueStream.map((v) => Uint8List.fromList(v));
  }

  Future<Uint8List> read(String uuid) async {
    final c = _chars[uuid];
    if (c == null) throw StateError('特徵 $uuid 不存在');
    return Uint8List.fromList(await c.read());
  }

  Future<void> write(String uuid, Uint8List data,
      {bool withoutResponse = false}) async {
    final c = _chars[uuid];
    if (c == null) throw StateError('特徵 $uuid 不存在');
    await c.write(data, withoutResponse: withoutResponse);
  }
}
```

- [ ] **Step 2: 確認靜態分析通過**

Run: `cd /mnt/e/board/petcollar-app && flutter analyze lib/ble/ble_service.dart`
Expected: `No issues found!`（若 flutter_blue_plus API 名稱因版本不同，依分析錯誤調整為對應方法，例如 `str128`/`str`）。

- [ ] **Step 3: Commit**

```bash
cd /mnt/e/board/petcollar-app
git add lib/ble/ble_service.dart
git commit -m "feat: BLE service layer wrapping flutter_blue_plus"
```

---

## Task 5: 狀態層（Riverpod Controller）

**Files:**
- Create: `lib/controllers/collar_controller.dart`
- Test: `test/collar_controller_test.dart`

> Controller 把「原始 byte → 解析 model」的邏輯抽出來成純函式，可不靠 BLE 測試。

- [ ] **Step 1: 寫 controller 解析測試**

`test/collar_controller_test.dart`：
```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/controllers/collar_controller.dart';

void main() {
  test('CollarState.applyHealth updates latest health and hr buffer', () {
    final s = CollarState.empty();
    final bytes = Uint8List.fromList(
        [0xD0, 0x02, 0x62, 0x81, 0x01, 0x55, 0x07, 0x00]);
    final s2 = s.applyHealth(bytes);
    expect(s2.health?.heartRate, 72.0);
    expect(s2.hrHistory.last, 72.0);
  });

  test('applyHealth ignores malformed bytes without throwing', () {
    final s = CollarState.empty();
    final s2 = s.applyHealth(Uint8List(3)); // 長度錯
    expect(s2.health, isNull);
    expect(s2.lastError, isNotNull);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd /mnt/e/board/petcollar-app && flutter test test/collar_controller_test.dart`
Expected: FAIL。

- [ ] **Step 3: 寫 CollarState + Controller**

`lib/controllers/collar_controller.dart`：
```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health.dart';
import '../models/location.dart';
import '../models/behavior.dart';
import '../models/device_status.dart';

class CollarState {
  final Health? health;
  final Location? location;
  final Behavior? behavior;
  final DeviceStatus? status;
  final List<double> hrHistory;
  final String? lastError;

  CollarState({
    this.health,
    this.location,
    this.behavior,
    this.status,
    this.hrHistory = const [],
    this.lastError,
  });

  factory CollarState.empty() => CollarState();

  CollarState _copy({
    Health? health,
    Location? location,
    Behavior? behavior,
    DeviceStatus? status,
    List<double>? hrHistory,
    String? lastError,
  }) =>
      CollarState(
        health: health ?? this.health,
        location: location ?? this.location,
        behavior: behavior ?? this.behavior,
        status: status ?? this.status,
        hrHistory: hrHistory ?? this.hrHistory,
        lastError: lastError,
      );

  CollarState applyHealth(Uint8List b) {
    try {
      final h = Health.fromBytes(b);
      final hist = [...hrHistory, h.heartRate];
      if (hist.length > 60) hist.removeAt(0);
      return _copy(health: h, hrHistory: hist);
    } on FormatException catch (e) {
      return _copy(lastError: e.message);
    }
  }

  CollarState applyLocation(Uint8List b) {
    try {
      return _copy(location: Location.fromBytes(b));
    } on FormatException catch (e) {
      return _copy(lastError: e.message);
    }
  }

  CollarState applyBehavior(Uint8List b) {
    try {
      return _copy(behavior: Behavior.fromBytes(b));
    } on FormatException catch (e) {
      return _copy(lastError: e.message);
    }
  }

  CollarState applyStatus(Uint8List b) {
    try {
      return _copy(status: DeviceStatus.fromBytes(b));
    } on FormatException catch (e) {
      return _copy(lastError: e.message);
    }
  }
}

class CollarController extends StateNotifier<CollarState> {
  CollarController() : super(CollarState.empty());

  void onHealth(Uint8List b) => state = state.applyHealth(b);
  void onLocation(Uint8List b) => state = state.applyLocation(b);
  void onBehavior(Uint8List b) => state = state.applyBehavior(b);
  void onStatus(Uint8List b) => state = state.applyStatus(b);
}

final collarControllerProvider =
    StateNotifierProvider<CollarController, CollarState>(
        (ref) => CollarController());
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd /mnt/e/board/petcollar-app && flutter test test/collar_controller_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
cd /mnt/e/board/petcollar-app
git add lib/controllers/collar_controller.dart test/collar_controller_test.dart
git commit -m "feat: Riverpod collar controller with tested byte->model logic"
```

---

## Task 6: 掃描頁 UI

**Files:**
- Create: `lib/screens/scan_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 寫 main.dart**

`lib/main.dart`（整檔覆寫）：
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/scan_screen.dart';

void main() => runApp(const ProviderScope(child: PetCollarApp()));

class PetCollarApp extends StatelessWidget {
  const PetCollarApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetCollar-X1',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6D9F71),
        brightness: Brightness.light,
      ),
      home: const ScanScreen(),
    );
  }
}
```

- [ ] **Step 2: 寫 ScanScreen**

`lib/screens/scan_screen.dart`：
```dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../ble/ble_service.dart';
import 'dashboard_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _ble = BleService();
  Stream<List<ScanResult>>? _results;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() => setState(() => _results = _ble.scan());

  Future<void> _connect(BluetoothDevice d) async {
    await _ble.stopScan();
    try {
      await _ble.connect(d);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DashboardScreen(ble: _ble, device: d),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('連線失敗：$e')));
      _startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('尋找 PetCollar')),
      floatingActionButton: FloatingActionButton(
        onPressed: _startScan,
        child: const Icon(Icons.refresh),
      ),
      body: StreamBuilder<List<ScanResult>>(
        stream: _results,
        builder: (context, snap) {
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('掃描中… 找不到裝置時點右下角重試'));
          }
          return ListView(
            children: [
              for (final r in list)
                ListTile(
                  leading: const Icon(Icons.pets),
                  title: Text(r.device.platformName.isEmpty
                      ? '(未命名)'
                      : r.device.platformName),
                  subtitle: Text('RSSI ${r.rssi} dBm'),
                  onTap: () => _connect(r.device),
                ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: 確認靜態分析**

Run: `cd /mnt/e/board/petcollar-app && flutter analyze lib/main.dart lib/screens/scan_screen.dart`
Expected: `No issues found!`（dashboard_screen 尚未建立會報缺檔，下一個 task 補；可暫時容忍此 import 錯誤直到 Task 7）。

- [ ] **Step 4: Commit**

```bash
cd /mnt/e/board/petcollar-app
git add lib/main.dart lib/screens/scan_screen.dart
git commit -m "feat: scan screen with service-UUID filtered scanning"
```

---

## Task 7: 儀表板 UI（卡片 + 趨勢圖 + 指令 + 設定）

**Files:**
- Create: `lib/screens/dashboard_screen.dart`
- Create: `lib/widgets/characteristic_card.dart`, `lib/widgets/command_panel.dart`, `lib/widgets/config_panel.dart`

- [ ] **Step 1: 寫 characteristic_card.dart**

`lib/widgets/characteristic_card.dart`：
```dart
import 'package:flutter/material.dart';

class CharacteristicCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> rows;
  final Widget? footer;

  const CharacteristicCard({
    super.key,
    required this.icon,
    required this.title,
    required this.rows,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 22),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            ...rows,
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 寫 command_panel.dart**

`lib/widgets/command_panel.dart`：
```dart
import 'package:flutter/material.dart';
import '../ble/ble_service.dart';
import '../ble/pcs_uuids.dart';
import '../models/command.dart';
import '../models/enums.dart';

class CommandPanel extends StatelessWidget {
  final BleService ble;
  const CommandPanel({super.key, required this.ble});

  Future<void> _send(BuildContext context, PcsCommand cmd) async {
    try {
      await ble.write(PcsUuids.command, CollarCommand(cmd: cmd).toBytes(),
          withoutResponse: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已送出 ${cmd.name}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('送出失敗：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('指令', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton(
                  onPressed: () => _send(context, PcsCommand.findModeOn),
                  child: const Text('尋找開')),
              OutlinedButton(
                  onPressed: () => _send(context, PcsCommand.findModeOff),
                  child: const Text('尋找關')),
              OutlinedButton(
                  onPressed: () => _send(context, PcsCommand.syncTime),
                  child: const Text('校時')),
            ]),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 寫 config_panel.dart**

`lib/widgets/config_panel.dart`：
```dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../ble/ble_service.dart';
import '../ble/pcs_uuids.dart';
import '../models/config.dart';

class ConfigPanel extends StatefulWidget {
  final BleService ble;
  const ConfigPanel({super.key, required this.ble});
  @override
  State<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<ConfigPanel> {
  CollarConfig? _cfg;

  Future<void> _read() async {
    try {
      final bytes = await widget.ble.read(PcsUuids.config);
      setState(() => _cfg = CollarConfig.fromBytes(bytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
      }
    }
  }

  Future<void> _save() async {
    final cfg = _cfg;
    if (cfg == null) return;
    try {
      await widget.ble.write(PcsUuids.config, cfg.toBytes());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('設定已儲存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: const Text('設定 (Configuration)'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (cfg == null)
            const Text('尚未讀取')
          else ...[
            Text('GNSS 間隔: ${cfg.gnssIntervalS}s'),
            Text('健康間隔: ${cfg.healthIntervalS}s'),
            Text('心率上限: ${cfg.alertHrMax}'),
            Text('體溫上限: ${cfg.alertTempMax}'),
            Text('地理圍欄半徑: ${cfg.geofenceRadiusM}m'),
          ],
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton(onPressed: _read, child: const Text('讀取')),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: cfg == null ? null : _save,
                child: const Text('儲存')),
          ]),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 寫 dashboard_screen.dart**

`lib/screens/dashboard_screen.dart`：
```dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../ble/ble_service.dart';
import '../ble/pcs_uuids.dart';
import '../controllers/collar_controller.dart';
import '../widgets/characteristic_card.dart';
import '../widgets/command_panel.dart';
import '../widgets/config_panel.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final BleService ble;
  final BluetoothDevice device;
  const DashboardScreen({super.key, required this.ble, required this.device});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    final c = ref.read(collarControllerProvider.notifier);
    widget.ble.subscribe(PcsUuids.health).listen(c.onHealth);
    widget.ble.subscribe(PcsUuids.location).listen(c.onLocation);
    widget.ble.subscribe(PcsUuids.behavior).listen(c.onBehavior);
    widget.ble.subscribe(PcsUuids.status).listen(c.onStatus);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(collarControllerProvider);
    final h = s.health;
    final loc = s.location;
    final beh = s.behavior;
    final st = s.status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PetCollar-X1'),
        actions: [
          if (st != null) Center(child: Text('🔋${st.batteryPct}%  ')),
        ],
      ),
      body: ListView(
        children: [
          CharacteristicCard(
            icon: Icons.location_on,
            title: '位置',
            rows: [
              Text(loc == null
                  ? '—'
                  : '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}'),
              const Text('⚠️ 目前為 firmware stub 假座標，非真實 GPS',
                  style: TextStyle(fontSize: 12, color: Colors.orange)),
            ],
          ),
          CharacteristicCard(
            icon: Icons.favorite,
            title: '健康',
            rows: [
              Text(h == null
                  ? '—'
                  : '心率 ${h.heartRate.toStringAsFixed(1)} BPM  血氧 ${h.spo2}%  體溫 ${h.temperature.toStringAsFixed(1)}°C'),
            ],
            footer: SizedBox(
              height: 80,
              child: s.hrHistory.length < 2
                  ? const Center(child: Text('收集心率資料中…'))
                  : LineChart(LineChartData(
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < s.hrHistory.length; i++)
                              FlSpot(i.toDouble(), s.hrHistory[i]),
                          ],
                          isCurved: true,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    )),
            ),
          ),
          CharacteristicCard(
            icon: Icons.pets,
            title: '行為',
            rows: [
              Text(beh == null
                  ? '—'
                  : '${beh.type.label}  信心 ${beh.confidence}  步數 ${beh.steps}'),
            ],
          ),
          CharacteristicCard(
            icon: Icons.info,
            title: '裝置狀態',
            rows: [
              Text(st == null
                  ? '—'
                  : '${st.state.label}  RSSI ${st.rssi} dBm  運行 ${st.uptimeSec}s'),
            ],
          ),
          CommandPanel(ble: widget.ble),
          ConfigPanel(ble: widget.ble),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 確認整專案靜態分析 + 測試**

Run: `cd /mnt/e/board/petcollar-app && flutter analyze && flutter test`
Expected: `No issues found!` 且所有單元測試 PASS。

- [ ] **Step 6: Commit**

```bash
cd /mnt/e/board/petcollar-app
git add lib/screens/dashboard_screen.dart lib/widgets
git commit -m "feat: dashboard with characteristic cards, hr chart, command and config panels"
```

---

## Task 8: 平台權限

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: 加 Android 權限**

在 `android/app/src/main/AndroidManifest.xml` 的 `<manifest>` 內、`<application>` 前加入：
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

- [ ] **Step 2: 加 iOS 權限**

在 `ios/Runner/Info.plist` 的 `<dict>` 內加入：
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要藍牙以連線 PetCollar 項圈</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>需要藍牙以連線 PetCollar 項圈</string>
```

- [ ] **Step 3: 確認 Android 可建置（若環境有 Android SDK）**

Run: `cd /mnt/e/board/petcollar-app && flutter build apk --debug`
Expected: 建置成功產生 APK；若環境無 Android SDK 則略過此步，留待有 SDK 的環境驗證。

- [ ] **Step 4: Commit**

```bash
cd /mnt/e/board/petcollar-app
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat: add Android and iOS Bluetooth permissions"
```

---

## Task 9: README + 推 GitHub

**Files:**
- Create: `README.md`

- [ ] **Step 1: 寫 README**

`README.md` 涵蓋：專案目的（驗證工具）、架構四層、如何 `flutter pub get` / `flutter test` / `flutter run`、對接韌體 repo 連結、已知限制（需 Flutter + 手機 + 韌體硬體才能實機驗證）。

- [ ] **Step 2: Commit + 建 repo + push**

```bash
cd /mnt/e/board/petcollar-app
git add README.md && git commit -m "docs: add README"
# 用 GitHub API 建 repo petcollar-x1-app，再 push（token 不留在 remote URL）
```

---

## Self-Review 註記

- **Spec 覆蓋**：四層架構（Task 1-7）、6 codec（Task 2-3）、掃描+儀表板（Task 6-7）、指令+設定（Task 7）、錯誤處理（各 codec 長度檢查 + controller try/catch + UI snackbar）、測試策略（模型/狀態層單元測試）、權限（Task 8）。Location stub 標示（Task 7 Step 4）。
- **flutter_blue_plus 版本風險**：API（如 `str128`、`lastValueStream`、`platformName`）可能因版本略有差異；Task 4/6 的 analyze 步驟用來抓出並修正。
- **環境限制**：實機跑 UI / 連項圈需 Flutter + 手機 + 硬體；本計畫到 Task 9 可完成「程式 + 單元測試通過 + 推 GitHub」。
