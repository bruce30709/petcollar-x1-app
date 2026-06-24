import 'package:flutter/material.dart';
import '../ble/ble_service.dart';
import '../ble/pcs_uuids.dart';
import '../models/command.dart';
import '../models/enums.dart';

class CommandPanel extends StatelessWidget {
  final BleService ble;
  const CommandPanel({super.key, required this.ble});

  Future<void> _send(BuildContext context, PcsCommand cmd) async {
    try {
      await ble.write(PcsUuids.command, CollarCommand(cmd: cmd).toBytes(),
          withoutResponse: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已送出 ${cmd.name}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('送出失敗：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('指令', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton(
                  onPressed: () => _send(context, PcsCommand.findModeOn),
                  child: const Text('尋找開')),
              OutlinedButton(
                  onPressed: () => _send(context, PcsCommand.findModeOff),
                  child: const Text('尋找關')),
              OutlinedButton(
                  onPressed: () => _send(context, PcsCommand.syncTime),
                  child: const Text('校時')),
            ]),
          ],
        ),
      ),
    );
  }
}
