import 'package:flutter/material.dart';
import '../ble/ble_service.dart';
import '../ble/pcs_uuids.dart';
import '../models/config.dart';

class ConfigPanel extends StatefulWidget {
  final BleService ble;
  const ConfigPanel({super.key, required this.ble});
  @override
  State<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<ConfigPanel> {
  CollarConfig? _cfg;

  Future<void> _read() async {
    try {
      final bytes = await widget.ble.read(PcsUuids.config);
      setState(() => _cfg = CollarConfig.fromBytes(bytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
      }
    }
  }

  Future<void> _save() async {
    final cfg = _cfg;
    if (cfg == null) return;
    try {
      await widget.ble.write(PcsUuids.config, cfg.toBytes());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('設定已儲存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: const Text('設定 (Configuration)'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (cfg == null)
            const Text('尚未讀取')
          else ...[
            Text('GNSS 間隔: ${cfg.gnssIntervalS}s'),
            Text('健康間隔: ${cfg.healthIntervalS}s'),
            Text('心率上限: ${cfg.alertHrMax}'),
            Text('體溫上限: ${cfg.alertTempMax}'),
            Text('地理圍欄半徑: ${cfg.geofenceRadiusM}m'),
          ],
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton(onPressed: _read, child: const Text('讀取')),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: cfg == null ? null : _save,
                child: const Text('儲存')),
          ]),
        ],
      ),
    );
  }
}
