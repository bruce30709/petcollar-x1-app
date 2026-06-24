import 'dart:typed_data';

class CollarConfig {
  final int gnssIntervalS;
  final int healthIntervalS;
  final int alertHrMax;
  final int alertTempMax;
  final int geofenceRadiusM;
  final Uint8List flags; // 8 bytes

  CollarConfig({
    required this.gnssIntervalS,
    required this.healthIntervalS,
    required this.alertHrMax,
    required this.alertTempMax,
    required this.geofenceRadiusM,
    required this.flags,
  });

  Uint8List toBytes() {
    final d = ByteData(20);
    d.setUint16(0, gnssIntervalS, Endian.little);
    d.setUint16(2, healthIntervalS, Endian.little);
    d.setUint16(4, alertHrMax, Endian.little);
    d.setUint16(6, alertTempMax, Endian.little);
    d.setUint32(8, geofenceRadiusM, Endian.little);
    final out = d.buffer.asUint8List();
    out.setRange(12, 20, flags);
    return out;
  }

  static CollarConfig fromBytes(Uint8List bytes) {
    if (bytes.length != 20) {
      throw FormatException('Config expects 20 bytes, got ${bytes.length}');
    }
    final d = ByteData.sublistView(bytes);
    return CollarConfig(
      gnssIntervalS: d.getUint16(0, Endian.little),
      healthIntervalS: d.getUint16(2, Endian.little),
      alertHrMax: d.getUint16(4, Endian.little),
      alertTempMax: d.getUint16(6, Endian.little),
      geofenceRadiusM: d.getUint32(8, Endian.little),
      flags: Uint8List.fromList(bytes.sublist(12, 20)),
    );
  }
}
