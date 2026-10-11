import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

class _ThrowingListener implements NavListener {
  @override
  void onNavEvent(NavEvent event) => throw StateError('listener boom');

  @override
  void close() {}
}

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late RecordingNavListener recorder;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
    recorder = RecordingNavListener();
  });

  Widget app(RouterObserver observer, {Map<String, WidgetBuilder>? routes}) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [observer],
      routes: {
        '/': (_) => const Scaffold(body: Text('home')),
        '/details': (_) => const Scaffold(body: Text('details')),
        '/settings': (_) => const Scaffold(body: Text('settings')),
        ...?routes,
      },
    );
  }

  Future<RouterObserver> pumpApp(
    WidgetTester tester, {
    RouterObserverSettings settings = const RouterObserverSettings(),
    List<NavListener>? listeners,
  }) async {
    final observer = RouterObserver(
      listeners: listeners ?? [recorder],
      settings: settings,
    );
    await tester.pumpWidget(app(observer));
    recorder.clear();
    return observer;
  }

  group('RouterObserver', () {
    testWidgets('emits push and pop with route names', (tester) async {
      await pumpApp(tester);

      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      expect(recorder.pushes.single.route.name, '/details');
      expect(recorder.pushes.single.previousRoute!.name, '/');

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(recorder.pops.single.route.name, '/details');
      expect(recorder.pops.single.previousRoute!.name, '/');
    });

    testWidgets('emits the initial route push', (tester) async {
      final observer = RouterObserver(listeners: [recorder]);
      await tester.pumpWidget(app(observer));
      expect(recorder.pushes.single.route.name, '/');
      expect(recorder.pushes.single.route.isFirst, isTrue);
    });

    testWidgets('emits replace with old and new routes', (tester) async {
      await pumpApp(tester);

      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pushReplacementNamed('/settings');
      await tester.pumpAndSettle();

      final replace = recorder.replaces.single;
      expect(replace.newRoute.name, '/settings');
      expect(replace.oldRoute!.name, '/details');
    });

    testWidgets('emits remove for pushAndRemoveUntil', (tester) async {
      await pumpApp(tester);

      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/settings',
        (route) => route.isFirst,
      );
      await tester.pumpAndSettle();

      expect(recorder.removes.single.route.name, '/details');
      expect(recorder.pushes.last.route.name, '/settings');
    });

    testWidgets('tracks the current stack accurately', (tester) async {
      final observer = await pumpApp(tester);

      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pushNamed('/settings');
      await tester.pumpAndSettle();

      expect(observer.currentStack.map((r) => r.name), [
        '/',
        '/details',
        '/settings',
      ]);
      expect(observer.currentRoute!.name, '/settings');
      expect(observer.stackDepth, 3);

      navigatorKey.currentState!.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      expect(observer.currentStack.map((r) => r.name), ['/']);
    });

    testWidgets('attaches a stack snapshot to events', (tester) async {
      await pumpApp(tester);
      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      expect(recorder.pushes.single.stackSnapshot, ['/', '/details']);
      expect(recorder.pushes.single.stackDepth, 2);
    });

    testWidgets('emits topChange events and can disable them', (tester) async {
      await pumpApp(tester);
      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      expect(recorder.topChanges, isNotEmpty);

      recorder.clear();
      await tester.pumpWidget(const SizedBox());
      navigatorKey = GlobalKey<NavigatorState>();
      await pumpApp(
        tester,
        settings: const RouterObserverSettings(includeTopChanges: false),
      );
      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      expect(recorder.topChanges, isEmpty);
      expect(recorder.pushes, isNotEmpty);
    });

    testWidgets('excludes popup routes when configured', (tester) async {
      await pumpApp(
        tester,
        settings: const RouterObserverSettings(includePopupRoutes: false),
      );

      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const AlertDialog(title: Text('hi')),
      );
      await tester.pumpAndSettle();
      expect(recorder.pushes, isEmpty);
    });

    testWidgets('labels dialogs via the default resolver', (tester) async {
      await pumpApp(tester);

      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const AlertDialog(title: Text('hi')),
      );
      await tester.pumpAndSettle();
      expect(recorder.pushes.single.route.name, '[dialog]');
      expect(recorder.pushes.single.route.isPopup, isTrue);
    });

    testWidgets('routeFilter drops matching routes', (tester) async {
      await pumpApp(
        tester,
        settings: RouterObserverSettings(
          routeFilter: (route) => route.name != '/details',
        ),
      );

      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pushNamed('/settings');
      await tester.pumpAndSettle();

      expect(recorder.pushes.map((e) => e.route.name), ['/settings']);
    });

    testWidgets('eventFilter drops events generically', (tester) async {
      await pumpApp(
        tester,
        settings: RouterObserverSettings(
          eventFilter: (event) => event is! NavTopChange,
        ),
      );
      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      expect(recorder.topChanges, isEmpty);
      expect(recorder.pushes, isNotEmpty);
    });

    testWidgets('captures redacted arguments when enabled', (tester) async {
      await pumpApp(
        tester,
        settings: const RouterObserverSettings(captureArguments: true),
      );

      navigatorKey.currentState!.pushNamed(
        '/details',
        arguments: {'id': 42, 'token': 'secret'},
      );
      await tester.pumpAndSettle();

      final args =
          recorder.pushes.single.route.arguments! as Map<String, Object?>;
      expect(args['id'], 42);
      expect(args['token'], maskedValue);
    });

    testWidgets('does not capture arguments by default', (tester) async {
      await pumpApp(tester);
      navigatorKey.currentState!.pushNamed('/details', arguments: {'id': 42});
      await tester.pumpAndSettle();
      expect(recorder.pushes.single.route.arguments, isNull);
    });

    testWidgets('emits nothing when disabled', (tester) async {
      await pumpApp(
        tester,
        settings: const RouterObserverSettings(enabled: false),
      );
      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      expect(recorder.events, isEmpty);
    });

    testWidgets('a throwing listener does not break navigation or others', (
      tester,
    ) async {
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = oldHandler);

      await pumpApp(tester, listeners: [_ThrowingListener(), recorder]);
      recorder.clear();

      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();

      expect(find.text('details'), findsOneWidget);
      expect(recorder.pushes, isNotEmpty);
      expect(errors, isNotEmpty);
      expect(errors.first.library, 'router_observer');
    });

    testWidgets('events stream broadcasts delivered events', (tester) async {
      final observer = await pumpApp(tester);
      final streamed = <NavEvent>[];
      final subscription = observer.events.listen(streamed.add);
      addTearDown(subscription.cancel);

      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      expect(streamed.whereType<NavPush>().single.route.name, '/details');
    });

    testWidgets('sequence numbers increase monotonically', (tester) async {
      await pumpApp(tester);
      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      final sequences = recorder.events.map((e) => e.sequence).toList();
      expect(sequences, isNotEmpty);
      for (var i = 1; i < sequences.length; i++) {
        expect(sequences[i], greaterThan(sequences[i - 1]));
      }
    });

    testWidgets('injectable clock stamps events deterministically', (
      tester,
    ) async {
      final fixed = DateTime.utc(2026, 6, 11, 10);
      await pumpApp(
        tester,
        settings: RouterObserverSettings(clock: () => fixed),
      );
      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      expect(recorder.pushes.single.timestamp, fixed);
    });

    testWidgets('shared listeners receive labeled events from nested '
        'navigators', (tester) async {
      final rootObserver = RouterObserver(listeners: [recorder]);
      final nestedObserver = RouterObserver(
        navigatorLabel: 'nested',
        listeners: [recorder],
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [rootObserver],
          home: Scaffold(
            body: Navigator(
              observers: [nestedObserver],
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'nested-root'),
                builder: (_) => const Text('nested'),
              ),
            ),
          ),
        ),
      );

      final labels = recorder.pushes.map((e) => e.navigatorLabel).toSet();
      expect(labels, containsAll(<String>{'root', 'nested'}));
      final nestedPush = recorder.pushes.firstWhere(
        (e) => e.navigatorLabel == 'nested',
      );
      expect(nestedPush.route.name, 'nested-root');
    });

    test('emits gesture events only when enabled', () {
      // Drive the observer callbacks directly; a real iOS back swipe is
      // platform-dependent and adds nothing to this contract.
      final route = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
        settings: const RouteSettings(name: '/details'),
      );

      final silent = RouterObserver(listeners: [recorder]);
      silent.didPush(route, null);
      recorder.clear();
      silent.didStartUserGesture(route, null);
      silent.didStopUserGesture();
      expect(recorder.events, isEmpty);

      final chatty = RouterObserver(
        listeners: [recorder],
        settings: const RouterObserverSettings(includeGestureEvents: true),
      );
      chatty.didPush(route, null);
      recorder.clear();
      chatty.didStartUserGesture(route, null);
      chatty.didStopUserGesture();
      expect(recorder.events.whereType<NavGestureStart>(), hasLength(1));
      expect(recorder.events.whereType<NavGestureEnd>(), hasLength(1));
    });

    test('empty-stack gesture completion respects every event filter', () {
      final configurations = [
        const RouterObserverSettings(
          enabled: false,
          includeGestureEvents: true,
        ),
        RouterObserverSettings(
          includeGestureEvents: true,
          routeFilter: (_) => false,
        ),
        RouterObserverSettings(
          includeGestureEvents: true,
          eventFilter: (_) => false,
        ),
      ];
      for (final settings in configurations) {
        final observer = RouterObserver(
          settings: settings,
          listeners: [recorder],
        );
        observer.didStopUserGesture();
        expect(recorder.events, isEmpty);
      }
      final observer = RouterObserver(
        settings: const RouterObserverSettings(includeGestureEvents: true),
        listeners: [recorder],
      );
      observer.didStopUserGesture();
      expect(recorder.events.single, isA<NavGestureEnd>());
    });

    testWidgets(
      'listeners cannot mutate snapshots delivered to other listeners',
      (tester) async {
        await pumpApp(
          tester,
          listeners: [
            NavCallbackListener(
              onEvent: (event) {
                expect(
                  () => event.stackSnapshot[0] = 'corrupted',
                  throwsUnsupportedError,
                );
              },
            ),
            recorder,
          ],
        );
        navigatorKey.currentState!.pushNamed('/details');
        await tester.pumpAndSettle();
        expect(recorder.pushes.single.stackSnapshot, ['/', '/details']);
        expect(recorder.pushes.single.toJson()['stack'], ['/', '/details']);
      },
    );

    testWidgets('a reused observer clears a detached navigator stack', (
      tester,
    ) async {
      final observer = await pumpApp(tester);
      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      expect(observer.stackDepth, 2);
      await tester.pumpWidget(const SizedBox());
      // Deliberately do not read the observer while it is detached.
      navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(observer));
      expect(observer.currentStack.map((route) => route.name), ['/']);
      expect(observer.stackDepth, 1);
      expect(observer.currentRoute!.name, '/');
      await tester.pumpWidget(const SizedBox());
      expect(observer.stackDepth, 0);
      expect(observer.currentRoute, isNull);
    });

    testWidgets('dispose closes listeners and the stream', (tester) async {
      var closed = false;
      final observer = await pumpApp(
        tester,
        listeners: [
          NavCallbackListener(onEvent: (_) {}, onClose: () => closed = true),
        ],
      );
      final done = observer.events.drain<void>();
      await observer.dispose();
      expect(closed, isTrue);
      await done; // stream completed
    });
  });
}
