import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/location.dart';

void main() {
  test('Location.fromBytes parses fields', () {
    final b = ByteData(18);
    b.setInt32(0, 250330000, Endian.little); // lat_e7 -> 25.033
    b.setInt32(4, 1215654000, Endian.little); // lon_e7 -> 121.5654
    b.setInt16(8, 10, Endian.little); // alt_m
    b.setUint16(10, 150, Endian.little); // accuracy_cm
    b.setUint32(12, 1719187200, Endian.little); // timestamp
    b.setUint8(16, 2); // fix_type
    b.setUint8(17, 1); // mode
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
