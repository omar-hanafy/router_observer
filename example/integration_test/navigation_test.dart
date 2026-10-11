import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:router_observer/router_observer.dart';
import 'package:router_observer_example/main.dart' as example;

const _bubbleKey = ValueKey<String>('nav_debug_overlay_bubble');
const _panelKey = ValueKey<String>('nav_debug_overlay_panel');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example routes, popups, breadcrumbs, and nested remount', (
    tester,
  ) async {
    example.breadcrumbs.clear();
    await tester.pumpWidget(const example.DemoApp());
    await tester.pumpAndSettle();
    expect(example.rootObserver.currentRoute!.name, '/');

    await _tap(tester, 'Push named route (with redacted args)');
    expect(find.text('Details'), findsOneWidget);
    final details = example.breadcrumbs.entries.whereType<NavPush>().last;
    expect(details.route.name, '/details');
    expect(details.route.arguments, {'productId': 42, 'token': maskedValue});
    expect(example.rootObserver.stackDepth, 2);

    await _tap(tester, 'Replace with tabs page');
    expect(find.text('Nested navigator'), findsOneWidget);
    expect(example.rootObserver.currentStack.map((route) => route.name), [
      '/',
      '/tabs',
    ]);
    expect(
      example.breadcrumbs.entries.whereType<NavReplace>().last.route.name,
      '/tabs',
    );
    await _tap(tester, 'Push inside nested navigator');
    expect(find.text('Tab detail'), findsOneWidget);
    expect(example.tabObserver.stackDepth, 2);
    expect(example.tabObserver.currentRoute!.name, 'tab-detail');

    // Pop the outer route while its nested navigator still has a detail route.
    // Reopening must reuse the observer without carrying the destroyed stack.
    example.rootObserver.navigator!.pop();
    await tester.pumpAndSettle();
    await _tap(tester, 'Open nested tab navigator');
    expect(example.tabObserver.currentStack.map((route) => route.name), [
      'tab-root',
    ]);
    example.rootObserver.navigator!.pop();
    await tester.pumpAndSettle();

    await _tap(tester, 'Push anonymous route');
    expect(find.text('Anonymous route'), findsOneWidget);
    expect(example.rootObserver.currentRoute!.name, isNot('[unknown]'));
    example.rootObserver.navigator!.pop();
    await tester.pumpAndSettle();
    expect(example.rootObserver.currentRoute!.name, '/');

    await _tap(tester, 'Show dialog');
    expect(find.text('A dialog'), findsOneWidget);
    expect(example.rootObserver.currentRoute!.name, '[dialog]');
    expect(example.rootObserver.currentRoute!.isPopup, isTrue);
    example.rootObserver.navigator!.pop();
    await tester.pumpAndSettle();

    await _tap(tester, 'Show bottom sheet');
    expect(find.text('Logged as [bottom-sheet]'), findsOneWidget);
    expect(example.rootObserver.currentRoute!.name, '[bottom-sheet]');
    example.rootObserver.navigator!.pop();
    await tester.pumpAndSettle();

    await _tap(tester, 'Dump breadcrumbs (crash-report style)');
    expect(find.text('Breadcrumb trail'), findsOneWidget);
    expect(
      find.textContaining('[tab:explore] push tab-detail'),
      findsOneWidget,
    );
    expect(find.textContaining('[root] replace /tabs'), findsOneWidget);
    example.rootObserver.navigator!.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_bubbleKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_panelKey), findsOneWidget);
    expect(find.text('root: /'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('nav_debug_overlay_close')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_panelKey), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hidden stack surgery and reset only track visible screens', (
    tester,
  ) async {
    final views = <ScreenView>[];
    final recorder = RecordingNavListener();
    final observer = RouterObserver(
      listeners: [
        recorder,
        ScreenTracker(onScreenView: views.add),
      ],
    );
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(observer, key));
    await tester.pumpAndSettle();
    final first = _route('first');
    final top = _route('top');
    unawaited(key.currentState!.push(first));
    await tester.pumpAndSettle();
    unawaited(key.currentState!.push(top));
    await tester.pumpAndSettle();
    expect(views.map((view) => view.name), ['/', 'first', 'top']);

    key.currentState!.removeRoute(first);
    await tester.pumpAndSettle();
    expect(find.text('top'), findsOneWidget);
    expect(views.map((view) => view.name), ['/', 'first', 'top']);
    expect(recorder.removes.single.currentRoute!.name, 'top');

    final hiddenHome = ModalRoute.of(
      tester.element(find.text('home', skipOffstage: false)),
    )!;
    key.currentState!.replace(
      oldRoute: hiddenHome,
      newRoute: _route('new-home'),
    );
    await tester.pumpAndSettle();
    expect(find.text('top'), findsOneWidget);
    expect(views.map((view) => view.name), ['/', 'first', 'top']);
    expect(recorder.replaces.single.currentRoute!.name, 'top');

    unawaited(
      key.currentState!.pushAndRemoveUntil(_route('final'), (_) => false),
    );
    await tester.pumpAndSettle();
    expect(find.text('final'), findsOneWidget);
    expect(observer.currentStack.map((route) => route.name), ['final']);
    expect(views.map((view) => view.name), ['/', 'first', 'top', 'final']);
    expect(views.last.previousName, 'top');
    expect(views.last.timeOnPreviousScreen, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await observer.dispose();
  });

  testWidgets('popup traffic does not emit analytics screen detours', (
    tester,
  ) async {
    final views = <ScreenView>[];
    final recorder = RecordingNavListener();
    final observer = RouterObserver(
      listeners: [
        recorder,
        ScreenTracker(onScreenView: views.add),
      ],
    );
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(observer, key));
    await tester.pumpAndSettle();
    unawaited(key.currentState!.push(_route('screen')));
    await tester.pumpAndSettle();

    unawaited(
      showDialog<void>(
        context: tester.element(find.text('screen')),
        builder: (_) => const AlertDialog(title: Text('popup')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('popup'), findsOneWidget);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(find.text('screen')),
        builder: (_) => const SizedBox(height: 100, child: Text('sheet')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsOneWidget);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(views.map((view) => view.name), ['/', 'screen']);
    expect(recorder.pushes.map((event) => event.route.name), [
      '/',
      'screen',
      '[dialog]',
      '[bottom-sheet]',
    ]);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(views.map((view) => view.name), ['/', 'screen', '/']);
    await tester.pumpWidget(const SizedBox.shrink());
    await observer.dispose();
  });

  testWidgets('captured arguments never expose deep secrets in event JSON', (
    tester,
  ) async {
    final recorder = RecordingNavListener();
    final observer = RouterObserver(
      listeners: [recorder],
      settings: const RouterObserverSettings(captureArguments: true),
    );
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(observer, key));
    await tester.pumpAndSettle();
    Object nested = {'accessToken': 'deep-token-must-not-escape'};
    for (var depth = 0; depth < 9; depth++) {
      nested = {'next': nested};
    }
    unawaited(
      key.currentState!.push(
        _route(
          'private',
          arguments: {
            'token': 'top-token-must-not-escape',
            'contacts': [
              {'email': 'private-email-must-not-escape', 'product': 42},
            ],
            'nested': nested,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('private'), findsOneWidget);
    final payload = jsonEncode(
      recorder.events.map((event) => event.toJson()).toList(),
    );
    expect(payload, isNot(contains('must-not-escape')));
    expect(payload, contains(maskedValue));
    expect(payload, contains('max-depth'));
    expect(payload, contains('42'));
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(
      jsonEncode(recorder.events.map((event) => event.toJson()).toList()),
      isNot(contains('must-not-escape')),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await observer.dispose();
  });

  testWidgets('overlay remains interactive after drag and layout resize', (
    tester,
  ) async {
    final observer = RouterObserver();
    final size = ValueNotifier<Size>(const Size(600, 400));
    const areaKey = ValueKey<String>('overlay-test-area');
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<Size>(
            valueListenable: size,
            builder: (_, value, _) => SizedBox(
              key: areaKey,
              width: value.width,
              height: value.height,
              child: NavDebugOverlay(
                observers: [observer],
                enabled: true,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bubble = find.byKey(_bubbleKey);
    await tester.drag(bubble, const Offset(2000, 2000));
    await tester.pumpAndSettle();
    _expectContained(
      tester.getRect(bubble),
      tester.getRect(find.byKey(areaKey)),
    );
    size.value = const Size(240, 280);
    await tester.pumpAndSettle();
    _expectContained(
      tester.getRect(bubble),
      tester.getRect(find.byKey(areaKey)),
    );
    await tester.drag(bubble, const Offset(-2000, -2000));
    await tester.pumpAndSettle();
    _expectContained(
      tester.getRect(bubble),
      tester.getRect(find.byKey(areaKey)),
    );
    await tester.tap(bubble);
    await tester.pumpAndSettle();
    expect(find.byKey(_panelKey), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('nav_debug_overlay_close')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_panelKey), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    size.dispose();
    await observer.dispose();
  });
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Widget _app(RouterObserver observer, GlobalKey<NavigatorState> key) =>
    MaterialApp(
      navigatorKey: key,
      navigatorObservers: [observer],
      home: const Scaffold(body: Center(child: Text('home'))),
    );

MaterialPageRoute<void> _route(String name, {Object? arguments}) =>
    MaterialPageRoute<void>(
      settings: RouteSettings(name: name, arguments: arguments),
      builder: (_) => Scaffold(body: Center(child: Text(name))),
    );

void _expectContained(Rect bubble, Rect area) {
  expect(bubble.left, greaterThanOrEqualTo(area.left));
  expect(bubble.top, greaterThanOrEqualTo(area.top));
  expect(bubble.right, lessThanOrEqualTo(area.right));
  expect(bubble.bottom, lessThanOrEqualTo(area.bottom));
}
