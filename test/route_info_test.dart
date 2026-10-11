import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

void main() {
  group('RouteInfo', () {
    test('capture snapshots a named route', () {
      final route = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
        settings: const RouteSettings(name: '/home'),
      );
      final info = RouteInfo.capture(route, arguments: {'a': 1});
      expect(info.name, '/home');
      expect(info.type, 'MaterialPageRoute<void>');
      expect(info.id, identityHashCode(route));
      expect(info.arguments, {'a': 1});
      expect(info.isPopup, isFalse);
      expect(info.isModal, isTrue);
      expect(info.pageKey, isNull);
      expect(info.isCurrent, isNull);
    });

    test('capture extracts page keys', () {
      const page = MaterialPage<void>(
        key: ValueKey<String>('home-page'),
        child: SizedBox(),
      );
      final route = page.createRoute(_FakeContext());
      final info = RouteInfo.capture(route);
      expect(info.pageKey, 'home-page');
      expect(info.name, 'home-page');
    });

    test('toJson omits null optionals', () {
      const info = RouteInfo(name: '/x', type: 'Route', id: 1);
      final json = info.toJson();
      expect(json.containsKey('arguments'), isFalse);
      expect(json.containsKey('pageKey'), isFalse);
      expect(json.containsKey('isCurrent'), isFalse);
      expect(json['name'], '/x');
      expect(json['isFirst'], isFalse);
      expect(json['isPopup'], isFalse);
    });

    test('toString names the route', () {
      const info = RouteInfo(name: '/x', type: 'Route', id: 1);
      expect(info.toString(), 'RouteInfo(/x, type: Route)');
    });
  });
}

class _FakeContext extends Fake implements BuildContext {}
