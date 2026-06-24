import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/scan_screen.dart';

void main() => runApp(const ProviderScope(child: PetCollarApp()));

class PetCollarApp extends StatelessWidget {
  const PetCollarApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetCollar-X1',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6D9F71),
        brightness: Brightness.light,
      ),
      home: const ScanScreen(),
    );
  }
}
