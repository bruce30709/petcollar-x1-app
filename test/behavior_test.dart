import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/behavior.dart';
import 'package:petcollar_app/models/enums.dart';

void main() {
  test('Behavior.fromBytes parses fields', () {
    final b = ByteData(6);
    b.setUint8(0, 2); // walking
    b.setUint8(1, 80); // confidence
    b.setUint32(2, 1234, Endian.little); // steps
    final beh = Behavior.fromBytes(b.buffer.asUint8List());
    expect(beh.type, BehaviorType.walking);
    expect(beh.confidence, 80);
    expect(beh.steps, 1234);
  });

  test('Behavior.fromBytes rejects wrong length', () {
    expect(() => Behavior.fromBytes(Uint8List(5)), throwsFormatException);
  });
}
