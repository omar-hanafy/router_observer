import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

RouteInfo _info(String name, {bool isPopup = false}) =>
    RouteInfo(name: name, type: 'Route', id: name.hashCode, isPopup: isPopup);

NavEvent _push(
  String name, {
  String? from,
  DateTime? at,
  String navigator = 'root',
  bool isPopup = false,
}) => NavPush(
  route: _info(name, isPopup: isPopup),
  previousRoute: from == null ? null : _info(from),
  timestamp: at ?? DateTime.utc(2026),
  sequence: 1,
  navigatorLabel: navigator,
  stackSnapshot: [name],
);

NavEvent _pop(String popped, {required String revealing, DateTime? at}) =>
    NavPop(
      route: _info(popped),
      previousRoute: _info(revealing),
      timestamp: at ?? DateTime.utc(2026),
      sequence: 2,
      navigatorLabel: 'root',
      stackSnapshot: [revealing],
    );

void main() {
  group('ScreenTracker', () {
    test('emits a view when a screen is pushed', () {
      final views = <ScreenView>[];
      ScreenTracker(onScreenView: views.add)
        ..onNavEvent(_push('/home'))
        ..onNavEvent(_push('/details', from: '/home'));
      expect(views.map((v) => v.name), ['/home', '/details']);
      expect(views.last.previousName, '/home');
    });

    test('measures time on previous screen', () {
      final views = <ScreenView>[];
      final tracker = ScreenTracker(onScreenView: views.add)
        ..onNavEvent(_push('/home', at: DateTime.utc(2026, 1, 1, 12)))
        ..onNavEvent(
          _push(
            '/details',
            from: '/home',
            at: DateTime.utc(2026, 1, 1, 12, 0, 30),
          ),
        );
      tracker.onNavEvent(
        _pop(
          '/details',
          revealing: '/home',
          at: DateTime.utc(2026, 1, 1, 12, 1),
        ),
      );
      expect(views[1].timeOnPreviousScreen, const Duration(seconds: 30));
      expect(views[2].name, '/home');
      expect(views[2].timeOnPreviousScreen, const Duration(seconds: 30));
    });

    test('ignores popups by default', () {
      final views = <ScreenView>[];
      ScreenTracker(onScreenView: views.add)
        ..onNavEvent(_push('/home'))
        ..onNavEvent(_push('[dialog]', isPopup: true));
      expect(views.map((v) => v.name), ['/home']);
    });

    test('counts popups when treatPopupsAsScreens is true', () {
      final views = <ScreenView>[];
      ScreenTracker(onScreenView: views.add, treatPopupsAsScreens: true)
        ..onNavEvent(_push('/home'))
        ..onNavEvent(_push('[dialog]', isPopup: true));
      expect(views.map((v) => v.name), ['/home', '[dialog]']);
    });

    test('deduplicates repeated views of the same screen', () {
      final views = <ScreenView>[];
      ScreenTracker(onScreenView: views.add)
        ..onNavEvent(_push('/home'))
        ..onNavEvent(
          NavTopChange(
            route: _info('/home'),
            timestamp: DateTime.utc(2026),
            sequence: 2,
            navigatorLabel: 'root',
            stackSnapshot: const ['/home'],
          ),
        );
      expect(views, hasLength(1));
    });

    test('tracks navigators independently', () {
      final views = <ScreenView>[];
      ScreenTracker(onScreenView: views.add)
        ..onNavEvent(_push('/home'))
        ..onNavEvent(_push('feed', navigator: 'tab:feed'));
      expect(views, hasLength(2));
      expect(views[1].navigatorLabel, 'tab:feed');
      expect(views[1].previousName, isNull);
    });

    test('starts a new session after an empty stack', () {
      final views = <ScreenView>[];
      final tracker = ScreenTracker(onScreenView: views.add)
        ..onNavEvent(_push('/home'));
      tracker.onNavEvent(
        NavRemove(
          route: _info('/home'),
          timestamp: DateTime.utc(2026),
          sequence: 2,
          navigatorLabel: 'root',
          stackSnapshot: const [],
        ),
      );
      tracker.onNavEvent(_push('/home'));
      expect(views, hasLength(2));
      expect(views.last.previousName, isNull);
      expect(views.last.timeOnPreviousScreen, isNull);
    });

    test('starts a new session when a navigator is recreated', () {
      final views = <ScreenView>[];
      ScreenTracker(onScreenView: views.add)
        ..onNavEvent(_push('/home'))
        ..onNavEvent(_push('/home'));
      expect(views, hasLength(2));
      expect(views.last.previousName, isNull);
    });

    for (final bool includeTopChanges in [true, false]) {
      group('real Navigator with top changes $includeTopChanges', () {
        late GlobalKey<NavigatorState> navigatorKey;
        late List<ScreenView> views;
        late RouterObserver observer;

        setUp(() {
          navigatorKey = GlobalKey<NavigatorState>();
          views = <ScreenView>[];
          observer = RouterObserver(
            listeners: [ScreenTracker(onScreenView: views.add)],
            settings: RouterObserverSettings(
              captureArguments: true,
              includeTopChanges: includeTopChanges,
            ),
          );
        });

        Future<void> pumpApp(WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigatorKey,
              navigatorObservers: [observer],
              routes: {
                '/': (_) => const Scaffold(body: Text('home')),
                '/details': (_) => const Scaffold(body: Text('details')),
                '/settings': (_) => const Scaffold(body: Text('settings')),
              },
            ),
          );
        }

        MaterialPageRoute<void> route(String name) => MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => Scaffold(body: Text(name)),
        );

        testWidgets(
          'removing a hidden route leaves the visible screen intact',
          (tester) async {
            await pumpApp(tester);
            final hidden = route('/details');
            navigatorKey.currentState!.push(hidden);
            await tester.pumpAndSettle();
            navigatorKey.currentState!.pushNamed('/settings');
            await tester.pumpAndSettle();
            views.clear();
            navigatorKey.currentState!.removeRoute(hidden);
            await tester.pumpAndSettle();
            expect(views, isEmpty);
            expect(find.text('settings'), findsOneWidget);
            navigatorKey.currentState!.pop();
            await tester.pumpAndSettle();
            expect(views.map((view) => view.name), ['/']);
          },
        );

        testWidgets(
          'replacing a hidden route leaves the visible screen intact',
          (tester) async {
            await pumpApp(tester);
            final hidden = route('/details');
            navigatorKey.currentState!.push(hidden);
            await tester.pumpAndSettle();
            navigatorKey.currentState!.pushNamed('/settings');
            await tester.pumpAndSettle();
            views.clear();
            navigatorKey.currentState!.replace(
              oldRoute: hidden,
              newRoute: route('/replacement'),
            );
            await tester.pumpAndSettle();
            expect(views, isEmpty);
            navigatorKey.currentState!.pop();
            await tester.pumpAndSettle();
            expect(views.map((view) => view.name), ['/replacement']);
          },
        );

        testWidgets('pushAndRemoveUntil emits only the new screen', (
          tester,
        ) async {
          await pumpApp(tester);
          navigatorKey.currentState!.pushNamed('/details');
          await tester.pumpAndSettle();
          views.clear();
          navigatorKey.currentState!.pushNamedAndRemoveUntil(
            '/settings',
            (route) => route.isFirst,
          );
          await tester.pumpAndSettle();
          expect(views.map((view) => view.name), ['/settings']);
          expect(views.single.previousName, '/details');
        });

        testWidgets('pop restores the revealed screen redacted arguments', (
          tester,
        ) async {
          await pumpApp(tester);
          navigatorKey.currentState!.pushNamed(
            '/details',
            arguments: {'id': 42, 'token': 'secret'},
          );
          await tester.pumpAndSettle();
          navigatorKey.currentState!.pushNamed('/settings');
          await tester.pumpAndSettle();
          views.clear();
          navigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
          expect(views.map((view) => view.name), ['/details']);
          expect(views.single.arguments, {'id': 42, 'token': maskedValue});
        });

        testWidgets(
          'batched page removals skip screens that never become top',
          (tester) async {
            const root = MaterialPage<void>(
              key: ValueKey('root'),
              name: '/',
              child: Scaffold(body: Text('home')),
            );
            final pages = ValueNotifier<List<Page<void>>>([
              root,
              const MaterialPage<void>(
                key: ValueKey('details'),
                name: '/details',
                child: Scaffold(body: Text('details')),
              ),
              const MaterialPage<void>(
                key: ValueKey('settings'),
                name: '/settings',
                child: Scaffold(body: Text('settings')),
              ),
            ]);
            addTearDown(pages.dispose);
            await tester.pumpWidget(
              MaterialApp(
                home: ValueListenableBuilder<List<Page<void>>>(
                  valueListenable: pages,
                  builder: (context, value, child) => Navigator(
                    key: navigatorKey,
                    observers: [observer],
                    pages: value,
                    onDidRemovePage: (_) {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(views.map((view) => view.name), ['/settings']);
            views.clear();
            pages.value = [root];
            await tester.pumpAndSettle();
            expect(views.map((view) => view.name), ['/']);
          },
        );

        if (includeTopChanges) {
          testWidgets(
            'reordered existing pages report the new visible screen',
            (tester) async {
              const home = MaterialPage<void>(
                key: ValueKey('home'),
                name: '/',
                child: Scaffold(body: Text('home')),
              );
              const details = MaterialPage<void>(
                key: ValueKey('details'),
                name: '/details',
                child: Scaffold(body: Text('details')),
              );
              final pages = ValueNotifier<List<Page<void>>>([home, details]);
              addTearDown(pages.dispose);
              await tester.pumpWidget(
                MaterialApp(
                  home: ValueListenableBuilder<List<Page<void>>>(
                    valueListenable: pages,
                    builder: (context, value, child) => Navigator(
                      key: navigatorKey,
                      observers: [observer],
                      pages: value,
                      onDidRemovePage: (_) {},
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              views.clear();
              pages.value = [details, home];
              await tester.pumpAndSettle();
              expect(find.text('home'), findsOneWidget);
              expect(views.map((view) => view.name), ['/']);
            },
          );
        }

        testWidgets(
          'hidden routes with duplicate names do not affect tracking',
          (tester) async {
            await pumpApp(tester);
            final hidden = route('/same');
            navigatorKey.currentState!.push(hidden);
            await tester.pumpAndSettle();
            navigatorKey.currentState!.push(route('/same'));
            await tester.pumpAndSettle();
            views.clear();
            navigatorKey.currentState!.replace(
              oldRoute: hidden,
              newRoute: route('/replacement'),
            );
            await tester.pumpAndSettle();
            expect(views, isEmpty);
            navigatorKey.currentState!.pop();
            await tester.pumpAndSettle();
            expect(views.map((view) => view.name), ['/replacement']);
          },
        );
      });
    }

    test('toJson includes durations in milliseconds', () {
      final view = ScreenView(
        name: '/a',
        previousName: '/b',
        navigatorLabel: 'root',
        timestamp: DateTime.utc(2026),
        timeOnPreviousScreen: const Duration(milliseconds: 1500),
      );
      final json = view.toJson();
      expect(json['timeOnPreviousScreenMs'], 1500);
      expect(json['previousName'], '/b');
    });
  });
}
