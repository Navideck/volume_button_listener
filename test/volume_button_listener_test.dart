import 'package:fake_async/fake_async.dart';
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
  Future<VolumeButtonBackend> startListener() async {
    isListeningValue = true;
    return VolumeButtonBackend.native;
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
      listener.multiPressWindow = const Duration(milliseconds: 300);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
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

    test('Delays buttonPressed when long-press listener is registered and released before timeout', () {
      fakeAsync((async) {
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

        // Advance 100ms (< 300ms) and release
        async.elapse(const Duration(milliseconds: 100));
        listener.notifyVolumeButtonReleased(true);

        // Now pressed and released should have fired, but NOT long press
        expect(pressedEvents, [VolumeButtonDirection.up]);
        expect(releasedEvents, [VolumeButtonDirection.up]);
        expect(longPressedEvents, isEmpty);
        expect(longPressReleasedEvents, isEmpty);
      });
    });

    test('Triggers long-press when held past duration, and longPressReleased on release', () {
      fakeAsync((async) {
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

        // Advance 350ms (> 300ms)
        async.elapse(const Duration(milliseconds: 350));

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
    });

    test('Handles independent directions correctly', () {
      fakeAsync((async) {
        final longPressedEvents = <VolumeButtonDirection>[];
        final pressedEvents = <VolumeButtonDirection>[];

        listener.buttonPressedNotifier.addListener((d) => pressedEvents.add(d));
        listener.buttonLongPressedNotifier.addListener((d) => longPressedEvents.add(d));

        // Press UP
        listener.notifyVolumeButtonPressed(true);
        // Wait 100ms, then press DOWN
        async.elapse(const Duration(milliseconds: 100));
        listener.notifyVolumeButtonPressed(false);

        // Release UP after another 100ms (total 200ms < 300ms) -> UP short press
        async.elapse(const Duration(milliseconds: 100));
        listener.notifyVolumeButtonReleased(true);
        expect(pressedEvents, [VolumeButtonDirection.up]);

        // Advance another 250ms -> DOWN reaches > 300ms total -> DOWN long press
        async.elapse(const Duration(milliseconds: 250));
        expect(longPressedEvents, [VolumeButtonDirection.down]);
      });
    });

    test(
      'Does not treat two iOS press notifications as a long press and detects single press on release',
      () {
        fakeAsync((async) {
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
          async.elapse(const Duration(milliseconds: 100));
          listener.notifyVolumeButtonPressed(true);
          async.elapse(const Duration(milliseconds: 150));
          listener.notifyVolumeButtonReleased(true);

          expect(longPressedEvents, isEmpty);
          expect(pressedEvents, [VolumeButtonDirection.up]);
          expect(releasedEvents, [VolumeButtonDirection.up]);
        });
      },
    );

    test('Detects single press on iOS when long-press listener is registered', () {
      fakeAsync((async) {
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
        async.elapse(const Duration(milliseconds: 250));
        expect(longPressedEvents, isEmpty);
        expect(pressedEvents, isEmpty);

        listener.notifyVolumeButtonReleased(true);

        expect(longPressedEvents, isEmpty);
        expect(pressedEvents, [VolumeButtonDirection.up]);
        expect(releasedEvents, [VolumeButtonDirection.up]);
      });
    });

    test('Treats sustained iOS press notifications as a long press', () {
      fakeAsync((async) {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listener.setSuppressRepeatedPressEvents(true);
        listener.longPressDuration = const Duration(milliseconds: 200);
        final longPressedEvents = <VolumeButtonDirection>[];
        listener.buttonLongPressedNotifier.addListener(longPressedEvents.add);

        listener.notifyVolumeButtonPressed(true);
        async.elapse(const Duration(milliseconds: 50));
        listener.notifyVolumeButtonPressed(true);
        async.elapse(const Duration(milliseconds: 50));
        listener.notifyVolumeButtonPressed(true);
        async.elapse(const Duration(milliseconds: 150));

        expect(longPressedEvents, [VolumeButtonDirection.up]);
      });
    });
  });

  group('VolumeButtonListenerInterface Multi Press Tests', () {
    late TestVolumeButtonListener listener;
    late List<VolumeButtonDirection> pressedEvents;
    late List<VolumeButtonDirection> releasedEvents;
    late List<VolumeButtonDirection> longPressedEvents;
    late List<(VolumeButtonDirection, int)> multiPressedEvents;

    setUp(() {
      listener = TestVolumeButtonListener();
      listener.setSuppressRepeatedPressEvents(false);
      listener.longPressDuration = const Duration(milliseconds: 300);
      listener.multiPressWindow = const Duration(milliseconds: 300);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      pressedEvents = [];
      releasedEvents = [];
      longPressedEvents = [];
      multiPressedEvents = [];

      listener.buttonPressedNotifier.addListener(pressedEvents.add);
      listener.buttonReleasedNotifier.addListener(releasedEvents.add);
      listener.buttonLongPressedNotifier.addListener(longPressedEvents.add);
      listener.buttonMultiPressedNotifier.addListener(
        (direction, count) => multiPressedEvents.add((direction, count)),
      );
    });

    tearDown(() {
      listener.cancelLongPressTimers();
      debugDefaultTargetPlatformOverride = null;
    });

    void tap(VolumeButtonDirection direction) {
      final isUp = direction == VolumeButtonDirection.up;
      listener.notifyVolumeButtonPressed(isUp);
      listener.notifyVolumeButtonReleased(isUp);
    }

    test('Fires a double press after the second press and suppresses singles', () {
      fakeAsync((async) {
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 150));
        tap(VolumeButtonDirection.up);

        expect(multiPressedEvents, isEmpty);
        expect(pressedEvents, isEmpty);
        expect(releasedEvents, isEmpty);

        async.elapse(const Duration(milliseconds: 350));

        expect(multiPressedEvents, [(VolumeButtonDirection.up, 2)]);
        expect(pressedEvents, isEmpty);
        expect(releasedEvents, isEmpty);
      });
    });

    test('Fires a triple press only once for three rapid presses', () {
      fakeAsync((async) {
        tap(VolumeButtonDirection.down);
        async.elapse(const Duration(milliseconds: 150));
        tap(VolumeButtonDirection.down);
        async.elapse(const Duration(milliseconds: 150));
        tap(VolumeButtonDirection.down);
        async.elapse(const Duration(milliseconds: 400));

        expect(multiPressedEvents, [(VolumeButtonDirection.down, 3)]);
        expect(pressedEvents, isEmpty);
        expect(releasedEvents, isEmpty);
      });
    });

    test('Ignores a fourth press until the window resets', () {
      fakeAsync((async) {
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 150));
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 150));
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 150));
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 400));

        expect(multiPressedEvents, [(VolumeButtonDirection.up, 3)]);
      });
    });

    test('Fires two separate single presses when the gap exceeds the window', () {
      fakeAsync((async) {
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 400));
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 400));

        expect(multiPressedEvents, isEmpty);
        expect(pressedEvents, [VolumeButtonDirection.up, VolumeButtonDirection.up]);
        expect(releasedEvents, [VolumeButtonDirection.up, VolumeButtonDirection.up]);
      });
    });

    test('Does not combine different directions', () {
      fakeAsync((async) {
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 150));
        tap(VolumeButtonDirection.down);
        async.elapse(const Duration(milliseconds: 400));

        expect(multiPressedEvents, isEmpty);
        expect(pressedEvents, [VolumeButtonDirection.up, VolumeButtonDirection.down]);
        expect(releasedEvents, [VolumeButtonDirection.up, VolumeButtonDirection.down]);
      });
    });

    test('Defers a single press until the window elapses', () {
      fakeAsync((async) {
        tap(VolumeButtonDirection.up);

        expect(pressedEvents, isEmpty);
        expect(releasedEvents, isEmpty);

        async.elapse(const Duration(milliseconds: 400));

        expect(pressedEvents, [VolumeButtonDirection.up]);
        expect(releasedEvents, [VolumeButtonDirection.up]);
      });
    });

    test('Fires double press with long-press listeners on a short second release', () {
      fakeAsync((async) {
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 150));
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 400));

        expect(multiPressedEvents, [(VolumeButtonDirection.up, 2)]);
        expect(longPressedEvents, isEmpty);
        expect(pressedEvents, isEmpty);
        expect(releasedEvents, isEmpty);
      });
    });

    test('Lets a held second press become a long press instead of a double', () {
      fakeAsync((async) {
        tap(VolumeButtonDirection.up);
        async.elapse(const Duration(milliseconds: 150));
        listener.notifyVolumeButtonPressed(true);
        async.elapse(const Duration(milliseconds: 400));

        expect(longPressedEvents, [VolumeButtonDirection.up]);
        expect(multiPressedEvents, isEmpty);

        listener.notifyVolumeButtonReleased(true);

        expect(multiPressedEvents, isEmpty);
        expect(longPressedEvents, [VolumeButtonDirection.up]);
      });
    });

    test('cancelLongPressTimers clears pending multi-press state', () {
      fakeAsync((async) {
        tap(VolumeButtonDirection.up);
        listener.cancelLongPressTimers();
        async.elapse(const Duration(milliseconds: 400));

        expect(multiPressedEvents, isEmpty);
        expect(pressedEvents, isEmpty);
        expect(releasedEvents, isEmpty);
      });
    });
  });
}
