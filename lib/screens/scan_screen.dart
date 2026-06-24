import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../ble/ble_service.dart';
import 'dashboard_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _ble = BleService();
  Stream<List<ScanResult>>? _results;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() => setState(() => _results = _ble.scan());

  Future<void> _connect(BluetoothDevice d) async {
    await _ble.stopScan();
    try {
      await _ble.connect(d);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DashboardScreen(ble: _ble, device: d),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('連線失敗：$e')));
      _startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('尋找 PetCollar')),
      floatingActionButton: FloatingActionButton(
        onPressed: _startScan,
        child: const Icon(Icons.refresh),
      ),
      body: StreamBuilder<List<ScanResult>>(
        stream: _results,
        builder: (context, snap) {
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('掃描中… 找不到裝置時點右下角重試'));
          }
          return ListView(
            children: [
              for (final r in list)
                ListTile(
                  leading: const Icon(Icons.pets),
                  title: Text(r.device.platformName.isEmpty
                      ? '(未命名)'
                      : r.device.platformName),
                  subtitle: Text('RSSI ${r.rssi} dBm'),
                  onTap: () => _connect(r.device),
                ),
            ],
          );
        },
      ),
    );
  }
}
