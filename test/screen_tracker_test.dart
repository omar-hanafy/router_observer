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
}) =>
    NavPush(
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
          _push('/details', at: DateTime.utc(2026, 1, 1, 12, 0, 30)),
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
