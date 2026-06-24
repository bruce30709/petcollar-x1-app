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
      gnssIntervalS: 0,
      healthIntervalS: 0,
      alertHrMax: 0,
      alertTempMax: 0,
      geofenceRadiusM: 0,
      flags: Uint8List(8),
    );
    expect(c.toBytes().length, 20);
  });

  test('Config.fromBytes rejects wrong length', () {
    expect(() => CollarConfig.fromBytes(Uint8List(19)), throwsFormatException);
  });
}
