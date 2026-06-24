import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/health.dart';

void main() {
  test('Health.fromBytes parses firmware stub vector', () {
    // 韌體 stub: hr=720, spo2=98, temp=385, sig=85, flags=0x07
    final bytes =
        Uint8List.fromList([0xD0, 0x02, 0x62, 0x81, 0x01, 0x55, 0x07, 0x00]);
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
