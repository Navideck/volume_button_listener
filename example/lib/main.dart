import 'dart:async';

import 'package:flutter/material.dart';
import 'package:volume_button_listener/volume_button_listener.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _OtherLogEntry {
  final String message;
  final DateTime at;

  _OtherLogEntry(this.message, this.at);
}

class _MyAppState extends State<MyApp> {
  static const int _maxLogEntries = 80;
  final List<_LogEntry> _volumeLog = [];
  final List<_OtherLogEntry> _otherLog = [];
  bool isListening = false;
  _LogEntry? _lastVolumeEvent;
  double? _currentVolume;
  bool _isFetchingVolume = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshListeningState());
  }

  @override
  void dispose() {
    unawaited(_removeListeners());
    super.dispose();
  }

  Future<void> _addListeners() async {
    await VolumeButtonListener.instance.addButtonPressedListener(
      _buttonPressedCallback,
    );
    await VolumeButtonListener.instance.addButtonReleasedListener(
      _buttonReleasedCallback,
    );
    await _refreshListeningState();
  }

  Future<void> _removeListeners() async {
    await VolumeButtonListener.instance.removeButtonPressedListener(
      _buttonPressedCallback,
    );
    await VolumeButtonListener.instance.removeButtonReleasedListener(
      _buttonReleasedCallback,
    );
    await _refreshListeningState();
  }

  Future<void> _refreshListeningState() async {
    final active = await VolumeButtonListener.instance.isListening;
    if (!mounted) return;
    setState(() => isListening = active);
  }

  void _buttonPressedCallback(VolumeButtonDirection direction) {
    final entry = _LogEntry.buttonPressed(direction);
    setState(() {
      _lastVolumeEvent = entry;
      _volumeLog.insert(0, entry);
    });
  }

  void _buttonReleasedCallback(VolumeButtonDirection direction) {
    final entry = _LogEntry.buttonReleased(direction);
    setState(() {
      _lastVolumeEvent = entry;
      _volumeLog.insert(0, entry);
      if (_volumeLog.length > _maxLogEntries) _volumeLog.removeLast();
    });
  }

  void addOtherLog(String message) {
    setState(() {
      _otherLog.insert(0, _OtherLogEntry(message, DateTime.now()));
      if (_otherLog.length > _maxLogEntries) _otherLog.removeLast();
    });
  }

  List<Object> getMergedLogs() {
    final merged = <Object>[..._volumeLog, ..._otherLog];
    merged.sort((a, b) {
      final at = a is _LogEntry ? a.at : (a as _OtherLogEntry).at;
      final bt = b is _LogEntry ? b.at : (b as _OtherLogEntry).at;
      return bt.compareTo(at);
    });
    return merged;
  }

  void clearLogs() {
    setState(() {
      _volumeLog.clear();
      _otherLog.clear();
      _lastVolumeEvent = null;
      _currentVolume = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Volume Button Listener'),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 2,
          actions: [
            IconButton(
              onPressed: _volumeLog.isEmpty && _otherLog.isEmpty
                  ? null
                  : clearLogs,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear logs',
            ),
          ],
        ),
        body: Column(
          children: [
            // Minimal state label
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isListening
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.6),
                    ),
                  ),
                  if (_lastVolumeEvent != null) ...[
                    const SizedBox(width: 16),
                    Text(
                      'Last: ${_lastVolumeEvent!.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_currentVolume != null) ...[
                    const SizedBox(width: 16),
                    Text(
                      'Volume: ${_currentVolume!.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final active =
                            await VolumeButtonListener.instance.isListening;
                        if (active) {
                          await _removeListeners();
                        } else {
                          await _addListeners();
                        }
                      },
                      icon: Icon(
                        isListening
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(isListening ? 'Stop' : 'Start'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isFetchingVolume
                          ? null
                          : () async {
                              setState(() => _isFetchingVolume = true);
                              try {
                                final volume = await VolumeButtonListener
                                    .instance
                                    .getVolume();
                                if (mounted) {
                                  setState(() {
                                    _currentVolume = volume;
                                    _isFetchingVolume = false;
                                  });
                                  addOtherLog(
                                    'Volume: ${volume.toStringAsFixed(2)}',
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _isFetchingVolume = false);
                                  addOtherLog('Get volume error: $e');
                                }
                              }
                            },
                      icon: _isFetchingVolume
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.volume_up_outlined, size: 20),
                      label: Text(_isFetchingVolume ? '…' : 'vol'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await VolumeButtonListener.instance.setVolume(0.5);
                        if (mounted) addOtherLog('Set to 0.5');
                      },
                      icon: const Icon(Icons.tune_rounded, size: 20),
                      label: const Text('0.5'),
                    ),
                  ),
                ],
              ),
            ),
            // Show/Hide Volume UI
            const SizedBox(height: 8),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          VolumeButtonListener.instance.showVolumeUI = true,
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Show Volume UI'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          VolumeButtonListener.instance.showVolumeUI = false,
                      icon: const Icon(Icons.visibility_off_rounded),
                      label: const Text('Hide Volume UI'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          VolumeButtonListener
                                  .instance
                                  .suppressRepeatedPressEvents =
                              true,
                      icon: const Icon(Icons.repeat_one_rounded),
                      label: const Text('Suppress Repeated Press Events'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          VolumeButtonListener
                                  .instance
                                  .suppressRepeatedPressEvents =
                              false,
                      icon: const Icon(Icons.repeat_one_rounded),
                      label: const Text('Allow Repeated Press Events'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Events',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Log list (merged by time, newest first)
            Expanded(
              child: Builder(
                builder: (context) {
                  final merged = getMergedLogs();
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: merged.length,
                    itemBuilder: (context, index) {
                      final entry = merged[index];
                      if (entry is _LogEntry) {
                        return _VolumeLogTile(entry: entry);
                      }
                      return _OtherLogTile(
                        message: (entry as _OtherLogEntry).message,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeLogTile extends StatelessWidget {
  const _VolumeLogTile({required this.entry});

  final _LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUp = entry.direction == VolumeButtonDirection.up;
    final isPressed = entry.isPressed;
    final color = isPressed
        ? (isUp ? colorScheme.primary : colorScheme.tertiary)
        : colorScheme.outline;
    final icon = isUp ? Icons.add_circle : Icons.remove_circle;
    final time = _formatTime(entry.at);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: color.withValues(alpha: isPressed ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      time,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUp ? 'UP' : 'DOWN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtherLogTile extends StatelessWidget {
  const _OtherLogTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  final time =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.${(dt.millisecond ~/ 100).toString().padLeft(1, '0')}';
  if (d == today) return time;
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday $time';
  return '${dt.month}/${dt.day} $time';
}

class _LogEntry {
  final bool isPressed;
  final VolumeButtonDirection direction;
  final DateTime at;

  _LogEntry(this.isPressed, this.direction, this.at);

  factory _LogEntry.buttonPressed(VolumeButtonDirection direction) =>
      _LogEntry(true, direction, DateTime.now());

  factory _LogEntry.buttonReleased(VolumeButtonDirection direction) =>
      _LogEntry(false, direction, DateTime.now());

  String get label => '$_labelPrefix . ${isPressed ? 'pressed' : 'released'}';

  String get _labelPrefix => switch (direction) {
    VolumeButtonDirection.up => 'Volume up',
    VolumeButtonDirection.down => 'Volume down',
  };
}
