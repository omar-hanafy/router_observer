import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

const _home = RouteInfo(name: '/home', type: 'Route', id: 1);
const _details = RouteInfo(
  name: '/details',
  type: 'Route',
  id: 2,
  arguments: '{id: 42}',
);

NavEvent _push() => NavPush(
  route: _details,
  previousRoute: _home,
  timestamp: DateTime.utc(2026),
  sequence: 1,
  navigatorLabel: 'root',
  stackSnapshot: const ['/home', '/details'],
);

NavEvent _pop() => NavPop(
  route: _details,
  previousRoute: _home,
  timestamp: DateTime.utc(2026),
  sequence: 2,
  navigatorLabel: 'root',
  stackSnapshot: const ['/home'],
);

void main() {
  group('ConsoleNavLogger', () {
    test('formats push with origin and depth', () {
      final lines = <String>[];
      ConsoleNavLogger(printer: lines.add).onNavEvent(_push());
      expect(
        lines.single,
        '[root] -> push         /details (from /home) depth=2',
      );
    });

    test('formats pop with destination', () {
      final lines = <String>[];
      ConsoleNavLogger(printer: lines.add).onNavEvent(_pop());
      expect(lines.single, contains('<- pop'));
      expect(lines.single, contains('(to /home)'));
    });

    test('appends arguments and stack when enabled', () {
      final lines = <String>[];
      ConsoleNavLogger(
        printer: lines.add,
        showArguments: true,
        showStack: true,
      ).onNavEvent(_push());
      expect(lines.single, contains('args={id: 42}'));
      expect(lines.single, contains('stack=[/home / /details]'));
    });

    test('json mode prints valid JSON', () {
      final lines = <String>[];
      ConsoleNavLogger(printer: lines.add, json: true).onNavEvent(_push());
      final decoded = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(decoded['type'], 'push');
    });

    test('colors wrap the line in ANSI escapes', () {
      final lines = <String>[];
      ConsoleNavLogger(printer: lines.add, useColors: true).onNavEvent(_push());
      expect(lines.single, startsWith('\x1B[32m'));
      expect(lines.single, endsWith('\x1B[0m'));
    });

    test('formatter overrides output and can skip events', () {
      final lines = <String>[];
      final logger = ConsoleNavLogger(
        printer: lines.add,
        formatter: (event) =>
            event is NavPop ? null : 'custom:${event.typeName}',
      );
      logger
        ..onNavEvent(_push())
        ..onNavEvent(_pop());
      expect(lines, ['custom:push']);
    });
  });
}
