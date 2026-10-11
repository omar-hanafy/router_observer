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

    testWidgets('tapping the bubble opens the panel with events and stack', (
      tester,
    ) async {
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

    testWidgets('keeps the bubble reachable after dragging beyond each edge', (
      tester,
    ) async {
      await tester.pumpWidget(app(RouterObserver(), enabled: true));
      final bubble = find.byKey(
        const ValueKey<String>('nav_debug_overlay_bubble'),
      );
      await tester.drag(bubble, const Offset(2000, 2000));
      await tester.pumpAndSettle();
      expect(tester.getRect(bubble).right, lessThanOrEqualTo(800));
      expect(tester.getRect(bubble).bottom, lessThanOrEqualTo(600));

      await tester.drag(bubble, const Offset(-2000, -2000));
      await tester.pumpAndSettle();
      expect(tester.getRect(bubble).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(bubble).top, greaterThanOrEqualTo(0));
      await tester.tap(bubble);
      await tester.pumpAndSettle();
      expect(find.text('Navigation'), findsOneWidget);
    });

    testWidgets('clamps the bubble after the viewport shrinks', (tester) async {
      await tester.pumpWidget(app(RouterObserver(), enabled: true));
      final bubble = find.byKey(
        const ValueKey<String>('nav_debug_overlay_bubble'),
      );
      await tester.drag(bubble, const Offset(100, 100));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(tester.getRect(bubble).right, lessThanOrEqualTo(320));
      expect(tester.getRect(bubble).bottom, lessThanOrEqualTo(480));
      await tester.drag(bubble, const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(bubble).left, lessThan(272));
      await tester.tap(bubble);
      await tester.pumpAndSettle();
      expect(find.text('Navigation'), findsOneWidget);
    });

    testWidgets('positions the bubble within its own constrained layout', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 240,
              child: NavDebugOverlay(
                observers: [RouterObserver()],
                enabled: true,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      );
      final bubble = find.byKey(
        const ValueKey<String>('nav_debug_overlay_bubble'),
      );
      final Rect bounds = tester.getRect(bubble);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(200));
      expect(bounds.bottom, lessThanOrEqualTo(240));
    });

    testWidgets('accumulates drag updates received before a frame', (
      tester,
    ) async {
      await tester.pumpWidget(app(RouterObserver(), enabled: true));
      final bubble = find.byKey(
        const ValueKey<String>('nav_debug_overlay_bubble'),
      );
      final gesture = await tester.startGesture(tester.getCenter(bubble));
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      final double initialLeft = tester.getRect(bubble).left;
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-25, 0));
      await tester.pump();
      expect(tester.getRect(bubble).left, closeTo(initialLeft - 45, 0.01));
      await gesture.up();
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
