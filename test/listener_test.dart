import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

NavEvent _event(int sequence) => NavPush(
      route: const RouteInfo(name: '/x', type: 'Route', id: 1),
      timestamp: DateTime.utc(2026),
      sequence: sequence,
      navigatorLabel: 'root',
      stackSnapshot: const ['/x'],
    );

void main() {
  group('NavCallbackListener', () {
    test('forwards events and close', () {
      final received = <NavEvent>[];
      var closed = false;
      final listener = NavCallbackListener(
        onEvent: received.add,
        onClose: () => closed = true,
      );
      final event = _event(1);
      listener.onNavEvent(event);
      listener.close();
      expect(received, [event]);
      expect(closed, isTrue);
    });
  });

  group('RecordingNavListener', () {
    test('records and filters by type', () {
      final recorder = RecordingNavListener();
      final push = _event(1);
      final pop = NavPop(
        route: const RouteInfo(name: '/x', type: 'Route', id: 1),
        timestamp: DateTime.utc(2026),
        sequence: 2,
        navigatorLabel: 'root',
        stackSnapshot: const [],
      );
      recorder
        ..onNavEvent(push)
        ..onNavEvent(pop);
      expect(recorder.events, [push, pop]);
      expect(recorder.pushes, [push]);
      expect(recorder.pops, [pop]);
      expect(recorder.removes, isEmpty);
      recorder.clear();
      expect(recorder.events, isEmpty);
    });

    test('events list is unmodifiable', () {
      final recorder = RecordingNavListener();
      expect(() => recorder.events.add(_event(1)), throwsUnsupportedError);
    });
  });

  group('RouterObserverSettings', () {
    test('copyWith overrides only the given fields', () {
      const settings = RouterObserverSettings();
      final copy = settings.copyWith(
        captureArguments: true,
        includeGestureEvents: true,
      );
      expect(copy.captureArguments, isTrue);
      expect(copy.includeGestureEvents, isTrue);
      expect(copy.enabled, settings.enabled);
      expect(copy.includePopupRoutes, settings.includePopupRoutes);
      expect(copy.maskKeys, settings.maskKeys);
    });
  });
}
