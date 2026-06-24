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
