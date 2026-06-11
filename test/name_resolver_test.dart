import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

MaterialPageRoute<void> _route({RouteSettings? settings}) =>
    MaterialPageRoute<void>(
      builder: (_) => const SizedBox(),
      settings: settings,
    );

void main() {
  group('defaultNameResolver', () {
    test('uses settings.name when present', () {
      final route = _route(settings: const RouteSettings(name: '/details'));
      expect(defaultNameResolver(route), '/details');
    });

    test('uses Page.name for page-based routes', () {
      const page = MaterialPage<void>(name: 'profile', child: SizedBox());
      final route = page.createRoute(_FakeContext());
      expect(defaultNameResolver(route), 'profile');
    });

    test('uses Page.key value for keyed pages without a name', () {
      const page = MaterialPage<void>(
        key: ValueKey<String>('settings-page'),
        child: SizedBox(),
      );
      final route = page.createRoute(_FakeContext());
      expect(defaultNameResolver(route), 'settings-page');
    });

    testWidgets('labels dialogs, sheets, and popups', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );

      final dialog = DialogRoute<void>(
        context: context,
        builder: (_) => const SizedBox(),
      );
      expect(defaultNameResolver(dialog), '[dialog]');

      final sheet = ModalBottomSheetRoute<void>(
        builder: (_) => const SizedBox(),
        isScrollControlled: false,
      );
      expect(defaultNameResolver(sheet), '[bottom-sheet]');
    });

    test('falls back to bracketed runtime type', () {
      final route = _route();
      expect(defaultNameResolver(route), '[MaterialPageRoute<void>]');
    });

    test('treats empty settings.name as missing', () {
      final route = _route(settings: const RouteSettings(name: ''));
      expect(defaultNameResolver(route), '[MaterialPageRoute<void>]');
    });
  });
}

class _FakeContext extends Fake implements BuildContext {}
