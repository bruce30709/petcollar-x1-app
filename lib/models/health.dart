import 'dart:typed_data';

class Health {
  final double heartRate; // BPM
  final int spo2; // %
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
