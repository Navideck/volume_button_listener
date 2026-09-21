part of '../main.dart';

class _OtherLogEntry {
  final String message;
  final DateTime at;

  _OtherLogEntry(this.message, this.at);
}

enum _EventType {
  pressed,
  released,
  longPressed,
  longPressReleased,
  multiPressed,
}

class _LogEntry {
  final _EventType type;
  final VolumeButtonDirection direction;
  final DateTime at;
  final int count;

  _LogEntry(this.type, this.direction, this.at, {this.count = 0});

  factory _LogEntry.buttonPressed(VolumeButtonDirection direction) =>
      _LogEntry(_EventType.pressed, direction, DateTime.now());

  factory _LogEntry.buttonReleased(VolumeButtonDirection direction) =>
      _LogEntry(_EventType.released, direction, DateTime.now());

  factory _LogEntry.buttonLongPressed(VolumeButtonDirection direction) =>
      _LogEntry(_EventType.longPressed, direction, DateTime.now());

  factory _LogEntry.buttonLongPressReleased(VolumeButtonDirection direction) =>
      _LogEntry(_EventType.longPressReleased, direction, DateTime.now());

  factory _LogEntry.buttonMultiPressed(
    VolumeButtonDirection direction,
    int count,
  ) =>
      _LogEntry(_EventType.multiPressed, direction, DateTime.now(), count: count);

  String get label {
    final typeStr = switch (type) {
      _EventType.pressed => 'pressed',
      _EventType.released => 'released',
      _EventType.longPressed => 'LONG PRESSED',
      _EventType.longPressReleased => 'long press released',
      _EventType.multiPressed => count >= 3
          ? 'TRIPLE PRESSED'
          : 'DOUBLE PRESSED',
    };
    return '$_labelPrefix . $typeStr';
  }

  String get _labelPrefix => switch (direction) {
    VolumeButtonDirection.up => 'Volume up',
    VolumeButtonDirection.down => 'Volume down',
  };
}
