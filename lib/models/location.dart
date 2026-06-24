import 'dart:typed_data';

class Location {
  final double latitude;
  final double longitude;
  final int altitudeM;
  final int accuracyCm;
  final int timestamp;
  final int fixType;
  final int mode;

  Location({
    required this.latitude,
    required this.longitude,
    required this.altitudeM,
    required this.accuracyCm,
    required this.timestamp,
    required this.fixType,
    required this.mode,
  });

  static Location fromBytes(Uint8List bytes) {
    if (bytes.length != 18) {
      throw FormatException('Location expects 18 bytes, got ${bytes.length}');
    }
    final d = ByteData.sublistView(bytes);
    return Location(
      latitude: d.getInt32(0, Endian.little) / 1e7,
      longitude: d.getInt32(4, Endian.little) / 1e7,
      altitudeM: d.getInt16(8, Endian.little),
      accuracyCm: d.getUint16(10, Endian.little),
      timestamp: d.getUint32(12, Endian.little),
      fixType: d.getUint8(16),
      mode: d.getUint8(17),
    );
  }
}
