import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/controllers/collar_controller.dart';

void main() {
  test('CollarState.applyHealth updates latest health and hr buffer', () {
    final s = CollarState.empty();
    final bytes =
        Uint8List.fromList([0xD0, 0x02, 0x62, 0x81, 0x01, 0x55, 0x07, 0x00]);
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
