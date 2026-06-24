import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health.dart';
import '../models/location.dart';
import '../models/behavior.dart';
import '../models/device_status.dart';

class CollarState {
  final Health? health;
  final Location? location;
  final Behavior? behavior;
  final DeviceStatus? status;
  final List<double> hrHistory;
  final String? lastError;

  CollarState({
    this.health,
    this.location,
    this.behavior,
    this.status,
    this.hrHistory = const [],
    this.lastError,
  });

  factory CollarState.empty() => CollarState();

  CollarState _copy({
    Health? health,
    Location? location,
    Behavior? behavior,
    DeviceStatus? status,
    List<double>? hrHistory,
    String? lastError,
  }) =>
      CollarState(
        health: health ?? this.health,
        location: location ?? this.location,
        behavior: behavior ?? this.behavior,
        status: status ?? this.status,
        hrHistory: hrHistory ?? this.hrHistory,
        lastError: lastError,
      );

  CollarState applyHealth(Uint8List b) {
    try {
      final h = Health.fromBytes(b);
      final hist = [...hrHistory, h.heartRate];
      if (hist.length > 60) hist.removeAt(0);
      return _copy(health: h, hrHistory: hist);
    } on FormatException catch (e) {
      return _copy(lastError: e.message);
    }
  }

  CollarState applyLocation(Uint8List b) {
    try {
      return _copy(location: Location.fromBytes(b));
    } on FormatException catch (e) {
      return _copy(lastError: e.message);
    }
  }

  CollarState applyBehavior(Uint8List b) {
    try {
      return _copy(behavior: Behavior.fromBytes(b));
    } on FormatException catch (e) {
      return _copy(lastError: e.message);
    }
  }

  CollarState applyStatus(Uint8List b) {
    try {
      return _copy(status: DeviceStatus.fromBytes(b));
    } on FormatException catch (e) {
      return _copy(lastError: e.message);
    }
  }
}

class CollarController extends StateNotifier<CollarState> {
  CollarController() : super(CollarState.empty());

  void onHealth(Uint8List b) => state = state.applyHealth(b);
  void onLocation(Uint8List b) => state = state.applyLocation(b);
  void onBehavior(Uint8List b) => state = state.applyBehavior(b);
  void onStatus(Uint8List b) => state = state.applyStatus(b);
}

final collarControllerProvider =
    StateNotifierProvider<CollarController, CollarState>(
        (ref) => CollarController());
