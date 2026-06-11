import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

NavEvent _event(int sequence, {String name = '/x'}) => NavPush(
      route: RouteInfo(name: name, type: 'Route', id: sequence),
      timestamp: DateTime.utc(2026, 6, 11, 12, 1, 33, 456),
      sequence: sequence,
      navigatorLabel: 'root',
      stackSnapshot: [name],
    );

void main() {
  group('NavBreadcrumbs', () {
    test('buffers events oldest first', () {
      final crumbs = NavBreadcrumbs();
      crumbs
        ..onNavEvent(_event(1))
        ..onNavEvent(_event(2));
      expect(crumbs.entries.map((e) => e.sequence), [1, 2]);
    });

    test('evicts oldest events beyond capacity', () {
      final crumbs = NavBreadcrumbs(capacity: 3);
      for (var i = 1; i <= 5; i++) {
        crumbs.onNavEvent(_event(i));
      }
      expect(crumbs.entries.map((e) => e.sequence), [3, 4, 5]);
    });

    test('dump returns JSON maps', () {
      final crumbs = NavBreadcrumbs()..onNavEvent(_event(1));
      final dump = crumbs.dump();
      expect(dump.single['type'], 'push');
      expect(dump.single['sequence'], 1);
    });

    test('describe renders a readable trail', () {
      final crumbs = NavBreadcrumbs()..onNavEvent(_event(1, name: '/home'));
      expect(
        crumbs.describe(),
        '12:01:33.456 [root] push /home (depth 1)\n',
      );
    });

    test('forwards each event to onCrumb before buffering', () {
      final forwarded = <NavEvent>[];
      final crumbs = NavBreadcrumbs(onCrumb: forwarded.add)
        ..onNavEvent(_event(1));
      expect(forwarded.single.sequence, 1);
      expect(crumbs.entries, hasLength(1));
    });

    test('clear and close empty the buffer', () {
      final crumbs = NavBreadcrumbs()..onNavEvent(_event(1));
      crumbs.clear();
      expect(crumbs.entries, isEmpty);
      crumbs.onNavEvent(_event(2));
      crumbs.close();
      expect(crumbs.entries, isEmpty);
    });
  });
}
