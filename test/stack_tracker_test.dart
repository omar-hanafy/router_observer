import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/src/stack_tracker.dart';

MaterialPageRoute<void> _route(String name) => MaterialPageRoute<void>(
  builder: (_) => const SizedBox(),
  settings: RouteSettings(name: name),
);

void main() {
  group('StackTracker', () {
    test('tracks ordered pushes', () {
      final tracker = StackTracker();
      final a = _route('a');
      final b = _route('b');
      tracker.push(a);
      tracker.push(b, previous: a);
      expect(tracker.routes, [a, b]);
      expect(tracker.top, same(b));
      expect(tracker.depth, 2);
    });

    test('inserts above the given previous route', () {
      final tracker = StackTracker();
      final a = _route('a');
      final b = _route('b');
      final c = _route('c');
      tracker.push(a);
      tracker.push(b, previous: a);
      tracker.push(c, previous: a); // inserted between a and b
      expect(tracker.routes, [a, c, b]);
    });

    test('ignores duplicate pushes', () {
      final tracker = StackTracker();
      final a = _route('a');
      tracker.push(a);
      tracker.push(a);
      expect(tracker.depth, 1);
    });

    test('removes routes anywhere in the stack', () {
      final tracker = StackTracker();
      final a = _route('a');
      final b = _route('b');
      final c = _route('c');
      tracker.push(a);
      tracker.push(b, previous: a);
      tracker.push(c, previous: b);
      tracker.remove(b);
      expect(tracker.routes, [a, c]);
    });

    test('replaces in place', () {
      final tracker = StackTracker();
      final a = _route('a');
      final b = _route('b');
      final z = _route('z');
      tracker.push(a);
      tracker.push(b, previous: a);
      tracker.replace(oldRoute: a, newRoute: z);
      expect(tracker.routes, [z, b]);
    });

    test('replace falls back to push when old route is unknown', () {
      final tracker = StackTracker();
      final a = _route('a');
      final z = _route('z');
      tracker.push(a);
      tracker.replace(oldRoute: _route('ghost'), newRoute: z);
      expect(tracker.routes, [a, z]);
    });

    test('ensure self-heals missing routes without duplicating', () {
      final tracker = StackTracker();
      final a = _route('a');
      final b = _route('b');
      tracker.ensure(b, previous: a);
      expect(tracker.routes, [b]);
      tracker.ensure(b);
      expect(tracker.depth, 1);
    });

    test('appends when previous route is unknown', () {
      final tracker = StackTracker();
      final a = _route('a');
      final b = _route('b');
      tracker.push(a);
      tracker.push(b, previous: _route('ghost'));
      expect(tracker.routes, [a, b]);
    });

    test('top changes move an existing page without duplicating it', () {
      final tracker = StackTracker();
      final a = _route('a');
      final b = _route('b');
      tracker.push(a);
      tracker.push(b, previous: a);
      tracker.ensure(a, previous: b);
      expect(tracker.routes, [b, a]);
      expect(tracker.top, same(a));
    });
  });
}
