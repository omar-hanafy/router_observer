import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

class _CapturingSink implements NavEventSink {
  final List<NavEvent> events = <NavEvent>[];

  @override
  void add(NavEvent event) => events.add(event);

  @override
  Future<void> close() async {}
}

Route<void> _route(String name, {Object? arguments}) => PageRouteBuilder<void>(
      settings: RouteSettings(name: name, arguments: arguments),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

void main() {
  final fixedClock = DateTime.utc(2026);

  group('NavTelemetryObserver', () {
    test('emits a structured push event', () {
      final sink = _CapturingSink();
      final observer = NavTelemetryObserver(
        config: NavObserverConfig(clock: () => fixedClock),
        sink: sink,
      );

      observer.didPush(_route('home'), null);

      expect(sink.events, hasLength(1));
      final event = sink.events.single;
      expect(event.type, NavEventType.push);
      expect(event.routeName, 'home');
      expect(event.timestamp, fixedClock);
      expect(event.stackDepth, 1);
      expect(event.stackSnapshot, <String>['home']);
    });

    test('tracks stack depth across push/pop', () {
      final sink = _CapturingSink();
      final observer = NavTelemetryObserver(sink: sink);

      final home = _route('home');
      final details = _route('details');
      observer.didPush(home, null);
      observer.didPush(details, home);
      observer.didPop(details, home);

      expect(sink.events.map((e) => e.type).toList(), <NavEventType>[
        NavEventType.push,
        NavEventType.push,
        NavEventType.pop,
      ]);
      expect(sink.events.last.stackDepth, 1);
    });

    test('drops events below the configured severity floor', () {
      final sink = _CapturingSink();
      // Default minSeverity is info; changeTop is debug -> dropped.
      final observer = NavTelemetryObserver(sink: sink);

      observer.didChangeTop(_route('top'), null);

      expect(sink.events, isEmpty);
    });

    test('emits verbose events when the floor is lowered', () {
      final sink = _CapturingSink();
      final observer = NavTelemetryObserver(
        config: const NavObserverConfig(minSeverity: NavSeverity.trace),
        sink: sink,
      );

      observer.didChangeTop(_route('top'), null);

      expect(sink.events.single.type, NavEventType.changeTop);
    });

    test('redacts masked argument keys when capture is enabled', () {
      final sink = _CapturingSink();
      final observer = NavTelemetryObserver(
        config: const NavObserverConfig(captureArguments: true),
        sink: sink,
      );

      observer.didPush(
        _route('login', arguments: {'token': 'secret', 'id': '42'}),
        null,
      );

      final args = sink.events.single.routeSettings['args']! as Map;
      expect(args['token'], '***');
      expect(args['id'], '42');
    });

    test('honors the per-minute rate limit', () {
      final sink = _CapturingSink();
      final observer = NavTelemetryObserver(
        config: NavObserverConfig(
          rateLimitPerMinute: 1,
          clock: () => fixedClock,
        ),
        sink: sink,
      );

      observer.didPush(_route('a'), null);
      observer.didPush(_route('b'), null);

      expect(sink.events, hasLength(1));
    });
  });

  group('NavEvent.toJson', () {
    test('produces an encodable map', () {
      final event = NavEvent(
        type: NavEventType.push,
        timestamp: fixedClock,
        navigatorKey: 'root#1',
        navigatorHash: 1,
        stackDepth: 1,
        routeId: 7,
        routeName: 'home',
        routeType: 'MaterialPageRoute',
        routeIsCurrent: true,
        routeSettings: const {'name': 'home'},
        stackSnapshot: const ['home'],
      );

      final json = event.toJson();
      expect(json['type'], 'push');
      expect(json['ts'], fixedClock.toIso8601String());
      expect((json['route']! as Map)['name'], 'home');
    });
  });

  group('defaultRedactor', () {
    test('masks matching keys and truncates long values', () {
      final result = defaultRedactor(
        {'password': 'p', 'note': 'abcdef'},
        maskKeys: {'password'},
        maxChars: 3,
      )! as Map;

      expect(result['password'], '***');
      expect(result['note'], startsWith('abc'));
    });
  });

  group('NavTelemetryObserver.observers', () {
    test('returns no observers when disabled', () {
      final observers = NavTelemetryObserver.observers(
        config: const NavObserverConfig(enabled: false),
      );
      expect(observers, isEmpty);
    });

    test('returns a single observer when enabled', () {
      final observers = NavTelemetryObserver.observers(
        config: const NavObserverConfig(),
        sink: _CapturingSink(),
      );
      expect(observers, hasLength(1));
    });
  });
}
