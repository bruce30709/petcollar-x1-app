import 'package:flutter_test/flutter_test.dart';
import 'package:petcollar_app/models/command.dart';
import 'package:petcollar_app/models/enums.dart';

void main() {
  test('Command.toBytes encodes cmd + params little-endian', () {
    final bytes = CollarCommand(
      cmd: PcsCommand.findModeOn,
      param1: 0xAB,
      param2: 0x1234,
    ).toBytes();
    expect(bytes, [0x01, 0xAB, 0x34, 0x12]); // param2 LE
  });
}
