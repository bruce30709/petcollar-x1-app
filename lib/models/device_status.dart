import 'dart:typed_data';
import 'enums.dart';

class DeviceStatus {
  final DeviceState state;
  final int batteryPct;
  final int rssi; // signed dBm
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
