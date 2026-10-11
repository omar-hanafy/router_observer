import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

const _route = RouteInfo(name: '/details', type: 'MaterialPageRoute', id: 1);
const _previous = RouteInfo(name: '/home', type: 'MaterialPageRoute', id: 2);

NavPush _push() => NavPush(
  route: _route,
  previousRoute: _previous,
  currentRoute: _route,
  timestamp: DateTime.utc(2026, 6, 11, 12),
  sequence: 7,
  navigatorLabel: 'root',
  stackSnapshot: const ['/home', '/details'],
);

void main() {
  group('NavEvent', () {
    test('toJson includes shared fields and route payloads', () {
      final json = _push().toJson();
      expect(json['type'], 'push');
      expect(json['sequence'], 7);
      expect(json['navigator'], 'root');
      expect(json['timestamp'], '2026-06-11T12:00:00.000Z');
      expect(json['stack'], ['/home', '/details']);
      expect(json['stackDepth'], 2);
      expect((json['route']! as Map)['name'], '/details');
      expect((json['previousRoute']! as Map)['name'], '/home');
      expect((json['currentRoute']! as Map)['name'], '/details');
    });

    test('stackDepth derives from snapshot', () {
      expect(_push().stackDepth, 2);
    });

    test('typeName per subtype', () {
      NavEvent build(
        NavEvent Function({
          required RouteInfo route,
          required DateTime timestamp,
          required int sequence,
          required String navigatorLabel,
          required List<String> stackSnapshot,
        })
        ctor,
      ) => ctor(
        route: _route,
        timestamp: DateTime.utc(2026),
        sequence: 1,
        navigatorLabel: 'root',
        stackSnapshot: const [],
      );

      expect(build(NavPush.new).typeName, 'push');
      expect(build(NavPop.new).typeName, 'pop');
      expect(build(NavRemove.new).typeName, 'remove');
      expect(build(NavReplace.new).typeName, 'replace');
      expect(build(NavTopChange.new).typeName, 'topChange');
      expect(build(NavGestureStart.new).typeName, 'gestureStart');
      expect(build(NavGestureEnd.new).typeName, 'gestureEnd');
    });

    test('NavReplace exposes oldRoute/newRoute aliases', () {
      final replace = NavReplace(
        route: _route,
        previousRoute: _previous,
        timestamp: DateTime.utc(2026),
        sequence: 1,
        navigatorLabel: 'root',
        stackSnapshot: const ['/details'],
      );
      expect(replace.newRoute, same(replace.route));
      expect(replace.oldRoute, same(replace.previousRoute));
    });

    test('sealed hierarchy switches exhaustively', () {
      final NavEvent event = _push();
      final String label = switch (event) {
        NavPush() => 'push',
        NavPop() => 'pop',
        NavRemove() => 'remove',
        NavReplace() => 'replace',
        NavTopChange() => 'top',
        NavGestureStart() => 'gs',
        NavGestureEnd() => 'ge',
      };
      expect(label, 'push');
    });

    test('toString is informative', () {
      expect(_push().toString(), 'NavEvent.push(#7 [root] /details <- /home)');
    });
  });
}
