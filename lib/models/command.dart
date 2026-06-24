import 'dart:typed_data';
import 'enums.dart';

class CollarCommand {
  final PcsCommand cmd;
  final int param1;
  final int param2;

  CollarCommand({required this.cmd, this.param1 = 0, this.param2 = 0});

  Uint8List toBytes() {
    final d = ByteData(4);
    d.setUint8(0, cmd.value);
    d.setUint8(1, param1);
    d.setUint16(2, param2, Endian.little);
    return d.buffer.asUint8List();
  }
}
