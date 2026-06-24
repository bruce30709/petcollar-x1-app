import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../ble/ble_service.dart';
import '../ble/pcs_uuids.dart';
import '../controllers/collar_controller.dart';
import '../widgets/characteristic_card.dart';
import '../widgets/command_panel.dart';
import '../widgets/config_panel.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final BleService ble;
  final BluetoothDevice device;
  const DashboardScreen({super.key, required this.ble, required this.device});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    final c = ref.read(collarControllerProvider.notifier);
    widget.ble.subscribe(PcsUuids.health).listen(c.onHealth);
    widget.ble.subscribe(PcsUuids.location).listen(c.onLocation);
    widget.ble.subscribe(PcsUuids.behavior).listen(c.onBehavior);
    widget.ble.subscribe(PcsUuids.status).listen(c.onStatus);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(collarControllerProvider);
    final h = s.health;
    final loc = s.location;
    final beh = s.behavior;
    final st = s.status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PetCollar-X1'),
        actions: [
          if (st != null) Center(child: Text('🔋${st.batteryPct}%  ')),
        ],
      ),
      body: ListView(
        children: [
          CharacteristicCard(
            icon: Icons.location_on,
            title: '位置',
            rows: [
              Text(loc == null
                  ? '—'
                  : '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}'),
              const Text('⚠️ 目前為 firmware stub 假座標，非真實 GPS',
                  style: TextStyle(fontSize: 12, color: Colors.orange)),
            ],
          ),
          CharacteristicCard(
            icon: Icons.favorite,
            title: '健康',
            rows: [
              Text(h == null
                  ? '—'
                  : '心率 ${h.heartRate.toStringAsFixed(1)} BPM  血氧 ${h.spo2}%  體溫 ${h.temperature.toStringAsFixed(1)}°C'),
            ],
            footer: SizedBox(
              height: 80,
              child: s.hrHistory.length < 2
                  ? const Center(child: Text('收集心率資料中…'))
                  : LineChart(LineChartData(
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < s.hrHistory.length; i++)
                              FlSpot(i.toDouble(), s.hrHistory[i]),
                          ],
                          isCurved: true,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    )),
            ),
          ),
          CharacteristicCard(
            icon: Icons.pets,
            title: '行為',
            rows: [
              Text(beh == null
                  ? '—'
                  : '${beh.type.label}  信心 ${beh.confidence}  步數 ${beh.steps}'),
            ],
          ),
          CharacteristicCard(
            icon: Icons.info,
            title: '裝置狀態',
            rows: [
              Text(st == null
                  ? '—'
                  : '${st.state.label}  RSSI ${st.rssi} dBm  運行 ${st.uptimeSec}s'),
            ],
          ),
          CommandPanel(ble: widget.ble),
          ConfigPanel(ble: widget.ble),
        ],
      ),
    );
  }
}
