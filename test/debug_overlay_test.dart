import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

void main() {
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
  });

  Widget app(RouterObserver observer, {bool? enabled}) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [observer],
      builder: (context, child) => NavDebugOverlay(
        observers: [observer],
        enabled: enabled,
        child: child!,
      ),
      routes: {
        '/': (_) => const Scaffold(body: Text('home')),
        '/details': (_) => const Scaffold(body: Text('details')),
      },
    );
  }

  group('NavDebugOverlay', () {
    testWidgets('renders only the child when disabled', (tester) async {
      final observer = RouterObserver();
      await tester.pumpWidget(app(observer, enabled: false));
      expect(find.text('home'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('nav_debug_overlay_bubble')),
        findsNothing,
      );
    });

    testWidgets('shows the bubble when enabled', (tester) async {
      final observer = RouterObserver();
      await tester.pumpWidget(app(observer, enabled: true));
      expect(
        find.byKey(const ValueKey<String>('nav_debug_overlay_bubble')),
        findsOneWidget,
      );
    });

    testWidgets('tapping the bubble opens the panel with events and stack',
        (tester) async {
      final observer = RouterObserver();
      await tester.pumpWidget(app(observer, enabled: true));

      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('nav_debug_overlay_bubble')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('nav_debug_overlay_panel')),
        findsOneWidget,
      );
      expect(find.text('Navigation'), findsOneWidget);
      // Timeline shows the push; stack section shows the current stack.
      expect(find.textContaining('/details'), findsWidgets);
      expect(find.textContaining('root:'), findsOneWidget);
    });

    testWidgets('close button hides the panel', (tester) async {
      final observer = RouterObserver();
      await tester.pumpWidget(app(observer, enabled: true));

      await tester.tap(
        find.byKey(const ValueKey<String>('nav_debug_overlay_bubble')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('nav_debug_overlay_close')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('nav_debug_overlay_panel')),
        findsNothing,
      );
    });
  });
}
