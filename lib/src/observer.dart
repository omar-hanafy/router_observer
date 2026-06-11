import 'dart:async';

import 'package:flutter/material.dart';

import 'package:router_observer/src/events.dart';
import 'package:router_observer/src/listeners/listener.dart';
import 'package:router_observer/src/route_info.dart';
import 'package:router_observer/src/settings.dart';
import 'package:router_observer/src/stack_tracker.dart';

/// A [NavigatorObserver] that turns navigation callbacks into structured
/// [NavEvent]s and delivers them to [NavListener]s and an event [events]
/// stream.
///
/// Attach one instance per navigator:
///
/// ```dart
/// final observer = RouterObserver(
///   listeners: [ConsoleNavLogger(), NavBreadcrumbs()],
/// );
///
/// MaterialApp(
///   navigatorObservers: [observer],
///   home: const HomePage(),
/// );
/// ```
///
/// Flutter does not allow a single [NavigatorObserver] to observe multiple
/// navigators, so for nested navigators create one `RouterObserver` per
/// navigator with a distinct [navigatorLabel] and share listener instances
/// between them; every event carries its source label.
///
/// Listener and stream delivery is crash-proof: exceptions thrown by
/// listeners are reported through [FlutterError.reportError] and never
/// propagate into the navigation code path.
class RouterObserver extends NavigatorObserver {
  /// Creates an observer.
  RouterObserver({
    this.navigatorLabel = 'root',
    List<NavListener> listeners = const <NavListener>[],
    this.settings = const RouterObserverSettings(),
  }) : _listeners = List<NavListener>.of(listeners);

  /// Identifies this observer's navigator in emitted events.
  final String navigatorLabel;

  /// Behavior configuration; see [RouterObserverSettings].
  final RouterObserverSettings settings;

  final List<NavListener> _listeners;
  final StackTracker _tracker = StackTracker();
  StreamController<NavEvent>? _controller;
  int _sequence = 0;

  /// A broadcast stream of every delivered event.
  ///
  /// Useful for ad-hoc listening (debug overlays, one-off subscriptions)
  /// without writing a [NavListener].
  Stream<NavEvent> get events =>
      (_controller ??= StreamController<NavEvent>.broadcast()).stream;

  /// Snapshot of the currently tracked route stack, bottom-most first.
  List<RouteInfo> get currentStack => _tracker.routes
      .map(
        (route) =>
            RouteInfo.capture(route, nameResolver: settings.nameResolver),
      )
      .toList(growable: false);

  /// The currently tracked top-most route, if any.
  RouteInfo? get currentRoute {
    final Route<dynamic>? top = _tracker.top;
    if (top == null) return null;
    return RouteInfo.capture(top, nameResolver: settings.nameResolver);
  }

  /// Depth of the currently tracked route stack.
  int get stackDepth => _tracker.depth;

  /// Closes the [events] stream and every attached listener.
  Future<void> dispose() async {
    for (final NavListener listener in _listeners) {
      try {
        listener.close();
      } catch (error, stackTrace) {
        _reportError(error, stackTrace, 'closing a NavListener');
      }
    }
    await _controller?.close();
  }

  // ---------------------------------------------------------------------
  // NavigatorObserver overrides
  // ---------------------------------------------------------------------

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _tracker.push(route, previous: previousRoute);
    _emit(route, previousRoute, _EventKind.push);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _tracker.remove(route);
    _emit(route, previousRoute, _EventKind.pop);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _tracker.remove(route);
    _emit(route, previousRoute, _EventKind.remove);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _tracker.replace(oldRoute: oldRoute, newRoute: newRoute);
    if (newRoute == null) return;
    _emit(newRoute, oldRoute, _EventKind.replace);
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _tracker.ensure(topRoute, previous: previousTopRoute);
    if (!settings.includeTopChanges) return;
    _emit(topRoute, previousTopRoute, _EventKind.topChange);
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    if (!settings.includeGestureEvents) return;
    _emit(route, previousRoute, _EventKind.gestureStart);
  }

  @override
  void didStopUserGesture() {
    if (!settings.includeGestureEvents) return;
    final Route<dynamic>? top = _tracker.top;
    if (top != null) {
      _emit(top, null, _EventKind.gestureEnd);
      return;
    }
    _deliver(
      _build(
        _EventKind.gestureEnd,
        const RouteInfo(name: '[unknown]', type: 'unknown', id: 0),
        null,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Emission pipeline
  // ---------------------------------------------------------------------

  void _emit(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
    _EventKind kind,
  ) {
    if (!settings.enabled) return;
    if (route is PopupRoute && !settings.includePopupRoutes) return;

    final RouteInfo info = _capture(route, withArguments: true);
    if (!(settings.routeFilter?.call(info) ?? true)) return;

    final RouteInfo? previousInfo =
        previousRoute == null ? null : _capture(previousRoute);

    final NavEvent event = _build(kind, info, previousInfo);
    if (!(settings.eventFilter?.call(event) ?? true)) return;
    _deliver(event);
  }

  RouteInfo _capture(Route<dynamic> route, {bool withArguments = false}) {
    Object? arguments;
    if (withArguments &&
        settings.captureArguments &&
        route.settings.arguments != null) {
      try {
        arguments = settings.redactor(
          route.settings.arguments,
          maskKeys: settings.maskKeys,
          maxChars: settings.maxChars,
        );
      } catch (_) {
        arguments = '<unserializable:${route.settings.arguments.runtimeType}>';
      }
    }
    return RouteInfo.capture(
      route,
      nameResolver: settings.nameResolver,
      arguments: arguments,
    );
  }

  NavEvent _build(_EventKind kind, RouteInfo route, RouteInfo? previousRoute) {
    final DateTime timestamp = settings.clock?.call() ?? DateTime.now();
    final int sequence = ++_sequence;
    final List<String> snapshot = _tracker.routes
        .map(settings.nameResolver)
        .toList(growable: false);

    return switch (kind) {
      _EventKind.push => NavPush(
          route: route,
          previousRoute: previousRoute,
          timestamp: timestamp,
          sequence: sequence,
          navigatorLabel: navigatorLabel,
          stackSnapshot: snapshot,
        ),
      _EventKind.pop => NavPop(
          route: route,
          previousRoute: previousRoute,
          timestamp: timestamp,
          sequence: sequence,
          navigatorLabel: navigatorLabel,
          stackSnapshot: snapshot,
        ),
      _EventKind.remove => NavRemove(
          route: route,
          previousRoute: previousRoute,
          timestamp: timestamp,
          sequence: sequence,
          navigatorLabel: navigatorLabel,
          stackSnapshot: snapshot,
        ),
      _EventKind.replace => NavReplace(
          route: route,
          previousRoute: previousRoute,
          timestamp: timestamp,
          sequence: sequence,
          navigatorLabel: navigatorLabel,
          stackSnapshot: snapshot,
        ),
      _EventKind.topChange => NavTopChange(
          route: route,
          previousRoute: previousRoute,
          timestamp: timestamp,
          sequence: sequence,
          navigatorLabel: navigatorLabel,
          stackSnapshot: snapshot,
        ),
      _EventKind.gestureStart => NavGestureStart(
          route: route,
          previousRoute: previousRoute,
          timestamp: timestamp,
          sequence: sequence,
          navigatorLabel: navigatorLabel,
          stackSnapshot: snapshot,
        ),
      _EventKind.gestureEnd => NavGestureEnd(
          route: route,
          previousRoute: previousRoute,
          timestamp: timestamp,
          sequence: sequence,
          navigatorLabel: navigatorLabel,
          stackSnapshot: snapshot,
        ),
    };
  }

  void _deliver(NavEvent event) {
    for (final NavListener listener in _listeners) {
      try {
        listener.onNavEvent(event);
      } catch (error, stackTrace) {
        _reportError(error, stackTrace, 'delivering a NavEvent to a listener');
      }
    }
    final StreamController<NavEvent>? controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.add(event);
    }
  }

  void _reportError(Object error, StackTrace stackTrace, String activity) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'router_observer',
        context: ErrorDescription(activity),
      ),
    );
  }
}

enum _EventKind {
  push,
  pop,
  remove,
  replace,
  topChange,
  gestureStart,
  gestureEnd,
}
