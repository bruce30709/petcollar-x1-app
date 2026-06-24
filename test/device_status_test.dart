import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/device_status.dart';
import 'package:petcollar_app/models/enums.dart';

void main() {
  test('DeviceStatus parses fields incl signed rssi and 24-bit uptime', () {
    final b = ByteData(6);
    b.setUint8(0, 1); // advertising
    b.setUint8(1, 85); // battery
    b.setInt8(2, -60); // rssi (signed)
    b.setUint8(3, 0x10); // uptime LE byte0
    b.setUint8(4, 0x27); // byte1
    b.setUint8(5, 0x00); // byte2  -> 0x002710 = 10000
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
