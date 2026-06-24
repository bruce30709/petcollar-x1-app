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
