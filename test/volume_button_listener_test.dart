import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volume_button_listener/src/volume_button_listener_interface.dart';
import 'package:volume_button_listener/volume_button_listener.dart';

class TestVolumeButtonListener with VolumeButtonListenerInterface {
  bool isListeningValue = false;
  double currentVolume = 0.5;
  bool showUiValue = true;

  @override
  Future<double> getVolume() async => currentVolume;

  @override
  Future<void> setVolume(double volume) async {
    currentVolume = volume;
  }

  @override
  Future<void> startListener() async {
    isListeningValue = true;
  }

  @override
  Future<void> stopListener() async {
    isListeningValue = false;
  }

  @override
  Future<void> setShowVolumeUi(bool showVolumeUi) async {
    showUiValue = showVolumeUi;
  }

  @override
  Future<bool> isListening() async => isListeningValue;
}

void main() {
  group('VolumeButtonListenerInterface Long Press Tests', () {
    late TestVolumeButtonListener listener;

    setUp(() {
      listener = TestVolumeButtonListener();
      listener.setSuppressRepeatedPressEvents(false);
      listener.longPressDuration = const Duration(milliseconds: 300);
    });

    tearDown(() {
      listener.cancelLongPressTimers();
      debugDefaultTargetPlatformOverride = null;
    });

    test('Fires immediate buttonPressed when no long-press listener is registered', () {
      final pressedEvents = <VolumeButtonDirection>[];
      final releasedEvents = <VolumeButtonDirection>[];

      listener.buttonPressedNotifier.addListener((d) => pressedEvents.add(d));
      listener.buttonReleasedNotifier.addListener((d) => releasedEvents.add(d));

      listener.notifyVolumeButtonPressed(true);
      expect(pressedEvents, [VolumeButtonDirection.up]);
      expect(releasedEvents, isEmpty);

      listener.notifyVolumeButtonReleased(true);
      expect(pressedEvents, [VolumeButtonDirection.up]);
      expect(releasedEvents, [VolumeButtonDirection.up]);
    });

    test('Delays buttonPressed when long-press listener is registered and released before timeout', () async {
      final pressedEvents = <VolumeButtonDirection>[];
      final releasedEvents = <VolumeButtonDirection>[];
      final longPressedEvents = <VolumeButtonDirection>[];
      final longPressReleasedEvents = <VolumeButtonDirection>[];

      listener.buttonPressedNotifier.addListener((d) => pressedEvents.add(d));
      listener.buttonReleasedNotifier.addListener((d) => releasedEvents.add(d));
      listener.buttonLongPressedNotifier.addListener((d) => longPressedEvents.add(d));
      listener.buttonLongPressReleasedNotifier.addListener((d) => longPressReleasedEvents.add(d));

      // Press button down
      listener.notifyVolumeButtonPressed(true);
      // buttonPressed should NOT have fired yet because long-press listener is active
      expect(pressedEvents, isEmpty);
      expect(longPressedEvents, isEmpty);

      // Wait 100ms (< 300ms) and release
      await Future.delayed(const Duration(milliseconds: 100));
      listener.notifyVolumeButtonReleased(true);

      // Now pressed and released should have fired, but NOT long press
      expect(pressedEvents, [VolumeButtonDirection.up]);
      expect(releasedEvents, [VolumeButtonDirection.up]);
      expect(longPressedEvents, isEmpty);
      expect(longPressReleasedEvents, isEmpty);
    });

    test('Triggers long-press when held past duration, and longPressReleased on release', () async {
      final pressedEvents = <VolumeButtonDirection>[];
      final releasedEvents = <VolumeButtonDirection>[];
      final longPressedEvents = <VolumeButtonDirection>[];
      final longPressReleasedEvents = <VolumeButtonDirection>[];

      listener.buttonPressedNotifier.addListener((d) => pressedEvents.add(d));
      listener.buttonReleasedNotifier.addListener((d) => releasedEvents.add(d));
      listener.buttonLongPressedNotifier.addListener((d) => longPressedEvents.add(d));
      listener.buttonLongPressReleasedNotifier.addListener((d) => longPressReleasedEvents.add(d));

      // Press button down
      listener.notifyVolumeButtonPressed(false);
      expect(pressedEvents, isEmpty);
      expect(longPressedEvents, isEmpty);

      // Wait 350ms (> 300ms)
      await Future.delayed(const Duration(milliseconds: 350));

      expect(pressedEvents, isEmpty);
      expect(longPressedEvents, [VolumeButtonDirection.down]);
      expect(releasedEvents, isEmpty);
      expect(longPressReleasedEvents, isEmpty);

      // Release button
      listener.notifyVolumeButtonReleased(false);

      // Normal released should NOT fire; only longPressReleased
      expect(pressedEvents, isEmpty);
      expect(releasedEvents, isEmpty);
      expect(longPressedEvents, [VolumeButtonDirection.down]);
      expect(longPressReleasedEvents, [VolumeButtonDirection.down]);
    });

    test('Handles independent directions correctly', () async {
      final longPressedEvents = <VolumeButtonDirection>[];
      final pressedEvents = <VolumeButtonDirection>[];

      listener.buttonPressedNotifier.addListener((d) => pressedEvents.add(d));
      listener.buttonLongPressedNotifier.addListener((d) => longPressedEvents.add(d));

      // Press UP
      listener.notifyVolumeButtonPressed(true);
      // Wait 100ms, then press DOWN
      await Future.delayed(const Duration(milliseconds: 100));
      listener.notifyVolumeButtonPressed(false);

      // Release UP after another 100ms (total 200ms < 300ms) -> UP short press
      await Future.delayed(const Duration(milliseconds: 100));
      listener.notifyVolumeButtonReleased(true);
      expect(pressedEvents, [VolumeButtonDirection.up]);

      // Wait another 250ms -> DOWN reaches > 300ms total -> DOWN long press
      await Future.delayed(const Duration(milliseconds: 250));
      expect(longPressedEvents, [VolumeButtonDirection.down]);
    });

    test(
      'Does not treat two iOS press notifications as a long press and detects single press on release',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listener.setSuppressRepeatedPressEvents(true);
        listener.longPressDuration = const Duration(milliseconds: 200);
        final pressedEvents = <VolumeButtonDirection>[];
        final releasedEvents = <VolumeButtonDirection>[];
        final longPressedEvents = <VolumeButtonDirection>[];
        listener.buttonPressedNotifier.addListener(pressedEvents.add);
        listener.buttonReleasedNotifier.addListener(releasedEvents.add);
        listener.buttonLongPressedNotifier.addListener(longPressedEvents.add);

        listener.notifyVolumeButtonPressed(true);
        await Future.delayed(const Duration(milliseconds: 100));
        listener.notifyVolumeButtonPressed(true);
        await Future.delayed(const Duration(milliseconds: 150));
        listener.notifyVolumeButtonReleased(true);

        expect(longPressedEvents, isEmpty);
        expect(pressedEvents, [VolumeButtonDirection.up]);
        expect(releasedEvents, [VolumeButtonDirection.up]);
      },
    );

    test('Detects single press on iOS when long-press listener is registered', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listener.setSuppressRepeatedPressEvents(true);
      listener.longPressDuration = const Duration(milliseconds: 200);
      final pressedEvents = <VolumeButtonDirection>[];
      final releasedEvents = <VolumeButtonDirection>[];
      final longPressedEvents = <VolumeButtonDirection>[];

      listener.buttonPressedNotifier.addListener(pressedEvents.add);
      listener.buttonReleasedNotifier.addListener(releasedEvents.add);
      listener.buttonLongPressedNotifier.addListener(longPressedEvents.add);

      listener.notifyVolumeButtonPressed(true);
      await Future.delayed(const Duration(milliseconds: 250));
      expect(longPressedEvents, isEmpty);
      expect(pressedEvents, isEmpty);

      listener.notifyVolumeButtonReleased(true);

      expect(longPressedEvents, isEmpty);
      expect(pressedEvents, [VolumeButtonDirection.up]);
      expect(releasedEvents, [VolumeButtonDirection.up]);
    });

    test('Treats sustained iOS press notifications as a long press', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listener.setSuppressRepeatedPressEvents(true);
      listener.longPressDuration = const Duration(milliseconds: 200);
      final longPressedEvents = <VolumeButtonDirection>[];
      listener.buttonLongPressedNotifier.addListener(longPressedEvents.add);

      listener.notifyVolumeButtonPressed(true);
      await Future.delayed(const Duration(milliseconds: 50));
      listener.notifyVolumeButtonPressed(true);
      await Future.delayed(const Duration(milliseconds: 50));
      listener.notifyVolumeButtonPressed(true);
      await Future.delayed(const Duration(milliseconds: 150));

      expect(longPressedEvents, [VolumeButtonDirection.up]);
    });
  });
}
