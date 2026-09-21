import 'dart:async';

import 'package:flutter/material.dart';
import 'package:volume_button_listener/volume_button_listener.dart';

part 'src/event_widgets.dart';
part 'src/log_entries.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const int _maxLogEntries = 80;
  static const double _wideBreakpoint = 700;

  final List<_LogEntry> _volumeLog = [];
  final List<_OtherLogEntry> _otherLog = [];
  bool isListening = false;
  _LogEntry? _lastVolumeEvent;
  double? _currentVolume;
  bool _isFetchingVolume = false;
  bool _controlsExpanded = true;

  bool _listenPressed = true;
  bool _listenReleased = true;
  bool _listenLongPressed = true;
  bool _listenLongPressReleased = true;
  bool _listenMultiPressed = true;

  int _longPressMs = 500;
  int _multiPressWindowMs = 300;

  LinuxVolumeButtonSetupStatus _captureSetupStatus =
      LinuxVolumeButtonSetupStatus.notApplicable;
  bool _settingUpCapture = false;

  @override
  void initState() {
    super.initState();
    VolumeButtonListener.instance.longPressDuration = Duration(
      milliseconds: _longPressMs,
    );
    VolumeButtonListener.instance.multiPressWindow = Duration(
      milliseconds: _multiPressWindowMs,
    );
    _captureSetupStatus = LinuxVolumeButtonSetup.status();
    unawaited(_addListeners());
  }

  @override
  void dispose() {
    unawaited(_removeListeners());
    super.dispose();
  }

  Future<void> _addListeners() async {
    if (_listenPressed) {
      await VolumeButtonListener.instance.addButtonPressedListener(
        _buttonPressedCallback,
      );
    }
    if (_listenReleased) {
      await VolumeButtonListener.instance.addButtonReleasedListener(
        _buttonReleasedCallback,
      );
    }
    if (_listenLongPressed) {
      await VolumeButtonListener.instance.addButtonLongPressedListener(
        _buttonLongPressedCallback,
      );
    }
    if (_listenLongPressReleased) {
      await VolumeButtonListener.instance.addButtonLongPressReleasedListener(
        _buttonLongPressReleasedCallback,
      );
    }
    if (_listenMultiPressed) {
      await VolumeButtonListener.instance.addButtonMultiPressedListener(
        _buttonMultiPressedCallback,
      );
    }
    await _refreshListeningState();
  }

  Future<void> _removeListeners() async {
    await VolumeButtonListener.instance.removeButtonPressedListener(
      _buttonPressedCallback,
    );
    await VolumeButtonListener.instance.removeButtonReleasedListener(
      _buttonReleasedCallback,
    );
    await VolumeButtonListener.instance.removeButtonLongPressedListener(
      _buttonLongPressedCallback,
    );
    await VolumeButtonListener.instance.removeButtonLongPressReleasedListener(
      _buttonLongPressReleasedCallback,
    );
    await VolumeButtonListener.instance.removeButtonMultiPressedListener(
      _buttonMultiPressedCallback,
    );
    await _refreshListeningState();
  }

  Future<void> _refreshListeningState() async {
    final active = await VolumeButtonListener.instance.isListening;
    if (!mounted) return;
    setState(() => isListening = active);
  }

  Future<void> _setUpVolumeButtonCapture() async {
    setState(() => _settingUpCapture = true);
    final enabled = await LinuxVolumeButtonSetup.setUp();
    if (!mounted) return;

    if (enabled) {
      // Restart listening so the native capture backend is picked up.
      await VolumeButtonListener.instance.pause();
      await VolumeButtonListener.instance.resume();
      if (!mounted) return;
    }

    setState(() {
      _settingUpCapture = false;
      _captureSetupStatus = LinuxVolumeButtonSetup.status();
    });
    addOtherLog(
      enabled
          ? 'Hardware volume buttons enabled'
          : 'Hardware volume buttons were not enabled (authentication cancelled or unsupported)',
    );
  }

  void _buttonPressedCallback(VolumeButtonDirection direction) {
    final entry = _LogEntry.buttonPressed(direction);
    setState(() {
      _lastVolumeEvent = entry;
      _volumeLog.insert(0, entry);
      if (_volumeLog.length > _maxLogEntries) _volumeLog.removeLast();
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

  void _buttonLongPressedCallback(VolumeButtonDirection direction) {
    final entry = _LogEntry.buttonLongPressed(direction);
    setState(() {
      _lastVolumeEvent = entry;
      _volumeLog.insert(0, entry);
      if (_volumeLog.length > _maxLogEntries) _volumeLog.removeLast();
    });
  }

  void _buttonLongPressReleasedCallback(VolumeButtonDirection direction) {
    final entry = _LogEntry.buttonLongPressReleased(direction);
    setState(() {
      _lastVolumeEvent = entry;
      _volumeLog.insert(0, entry);
      if (_volumeLog.length > _maxLogEntries) _volumeLog.removeLast();
    });
  }

  void _buttonMultiPressedCallback(
    VolumeButtonDirection direction,
    int count,
  ) {
    final entry = _LogEntry.buttonMultiPressed(direction, count);
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideBreakpoint;
            final statusBar = _buildStatusBar(theme, colorScheme);

            if (isWide) {
              return Column(
                children: [
                  statusBar,
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 380,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildControls(theme, colorScheme),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: _buildEvents(theme, colorScheme)),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                statusBar,
                _buildControlsHeader(theme, colorScheme),
                if (_controlsExpanded)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.5,
                    ),
                    child: SingleChildScrollView(
                      child: _buildControls(theme, colorScheme),
                    ),
                  ),
                Expanded(child: _buildEvents(theme, colorScheme)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 8),
              Text(
                isListening ? 'Listening' : 'Stopped',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_lastVolumeEvent != null)
            Text(
              'Last: ${_lastVolumeEvent!.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          if (_currentVolume != null)
            Text(
              'Volume: ${_currentVolume!.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsHeader(ThemeData theme, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => setState(() => _controlsExpanded = !_controlsExpanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Text(
              'Controls',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Icon(
              _controlsExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                    isListening ? Icons.stop_rounded : Icons.play_arrow_rounded,
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
                            final volume =
                                await VolumeButtonListener.instance.getVolume();
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
        const SizedBox(height: 4),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listeners (restart to apply):',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text('Pressed'),
                    selected: _listenPressed,
                    onSelected: (v) => setState(() => _listenPressed = v),
                  ),
                  FilterChip(
                    label: const Text('Released'),
                    selected: _listenReleased,
                    onSelected: (v) => setState(() => _listenReleased = v),
                  ),
                  FilterChip(
                    label: const Text('Long Pressed'),
                    selected: _listenLongPressed,
                    onSelected: (v) => setState(() => _listenLongPressed = v),
                  ),
                  FilterChip(
                    label: const Text('Long Press Released'),
                    selected: _listenLongPressReleased,
                    onSelected: (v) =>
                        setState(() => _listenLongPressReleased = v),
                  ),
                  FilterChip(
                    label: const Text('Multi Pressed'),
                    selected: _listenMultiPressed,
                    onSelected: (v) => setState(() => _listenMultiPressed = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildDurationPicker(
            theme: theme,
            label: 'Long Press Duration: ${_longPressMs}ms',
            options: const [300, 500, 800, 1200],
            selected: _longPressMs,
            onSelected: (ms) {
              setState(() => _longPressMs = ms);
              VolumeButtonListener.instance.longPressDuration = Duration(
                milliseconds: ms,
              );
              addOtherLog('Long press duration: ${ms}ms');
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildDurationPicker(
            theme: theme,
            label: 'Multi Press Window: ${_multiPressWindowMs}ms',
            options: const [200, 300, 400, 500],
            selected: _multiPressWindowMs,
            onSelected: (ms) {
              setState(() => _multiPressWindowMs = ms);
              VolumeButtonListener.instance.multiPressWindow = Duration(
                milliseconds: ms,
              );
              addOtherLog('Multi press window: ${ms}ms');
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    VolumeButtonListener.instance.showVolumeUI = true,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Show Volume UI'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    VolumeButtonListener.instance.showVolumeUI = false,
                icon: const Icon(Icons.visibility_off_rounded),
                label: const Text('Hide Volume UI'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => VolumeButtonListener
                    .instance.suppressRepeatedPressEvents = true,
                icon: const Icon(Icons.repeat_one_rounded),
                label: const Text('Suppress Repeated Press Events'),
              ),
              OutlinedButton.icon(
                onPressed: () => VolumeButtonListener
                    .instance.suppressRepeatedPressEvents = false,
                icon: const Icon(Icons.repeat_one_rounded),
                label: const Text('Allow Repeated Press Events'),
              ),
            ],
          ),
        ),
        if (_captureSetupStatus ==
            LinuxVolumeButtonSetupStatus.needsSetup) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hardware volume buttons',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This device routes its hardware volume buttons through the '
                  'intel-hid 5-button array. Setup enables the array and grants '
                  'the app access to capture the buttons, so the system volume '
                  'change is suppressed. It requires administrator authentication.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _settingUpCapture
                        ? null
                        : _setUpVolumeButtonCapture,
                    icon: _settingUpCapture
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.volume_up_rounded, size: 20),
                    label: Text(
                      _settingUpCapture
                          ? 'Enabling…'
                          : 'Enable hardware volume buttons',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDurationPicker({
    required ThemeData theme,
    required String label,
    required List<int> options,
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final ms in options)
              ChoiceChip(
                label: Text('${ms}ms'),
                selected: selected == ms,
                onSelected: (isSelected) {
                  if (isSelected) onSelected(ms);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEvents(ThemeData theme, ColorScheme colorScheme) {
    final merged = getMergedLogs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              const Spacer(),
              Text(
                '${merged.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: merged.isEmpty
              ? Center(
                  child: Text(
                    'No events yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
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
                ),
        ),
      ],
    );
  }
}

