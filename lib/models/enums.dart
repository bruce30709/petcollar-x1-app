enum BehaviorType {
  sleeping,
  resting,
  walking,
  running,
  playing,
  scratching,
  unknown;

  static BehaviorType fromByte(int b) =>
      (b >= 0 && b < BehaviorType.values.length)
          ? BehaviorType.values[b]
          : BehaviorType.unknown;

  String get label => const {
        BehaviorType.sleeping: '睡覺',
        BehaviorType.resting: '休息',
        BehaviorType.walking: '走路',
        BehaviorType.running: '跑步',
        BehaviorType.playing: '玩耍',
        BehaviorType.scratching: '抓癢',
        BehaviorType.unknown: '未知',
      }[this]!;
}

enum PcsCommand {
  findModeOn(0x01),
  findModeOff(0x02),
  syncTime(0x03),
  setConfig(0x04),
  reboot(0x05),
  dfuMode(0x06);

  const PcsCommand(this.value);
  final int value;
}

enum DeviceState {
  idle,
  advertising,
  connected,
  locating,
  unknown;

  static DeviceState fromByte(int b) =>
      (b >= 0 && b < DeviceState.values.length - 1)
          ? DeviceState.values[b]
          : DeviceState.unknown;

  String get label => const {
        DeviceState.idle: '閒置',
        DeviceState.advertising: '廣播中',
        DeviceState.connected: '已連線',
        DeviceState.locating: '定位中',
        DeviceState.unknown: '未知',
      }[this]!;
}
