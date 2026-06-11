import 'package:flutter/foundation.dart';

import 'package:router_observer/src/route_info.dart';

/// Base class for all navigation events emitted by `RouterObserver`.
///
/// This is a sealed hierarchy; switch over it exhaustively:
///
/// ```dart
/// switch (event) {
///   case NavPush():         // route was pushed
///   case NavPop():          // route was popped
///   case NavRemove():       // route was removed without popping
///   case NavReplace():      // route was replaced
///   case NavTopChange():    // top-most route changed
///   case NavGestureStart(): // back-swipe gesture started
///   case NavGestureEnd():   // back-swipe gesture ended
/// }
/// ```
@immutable
sealed class NavEvent {
  /// Creates a navigation event.
  const NavEvent({
    required this.route,
    required this.timestamp,
    required this.sequence,
    required this.navigatorLabel,
    required this.stackSnapshot,
    this.previousRoute,
  });

  /// The route this event is primarily about.
  final RouteInfo route;

  /// The other route involved in the transition, when one exists.
  ///
  /// For [NavPush] this is the route below the pushed route; for [NavPop]
  /// the newly revealed route; for [NavReplace] the replaced route.
  final RouteInfo? previousRoute;

  /// Wall-clock time the event was emitted (from the configured clock).
  final DateTime timestamp;

  /// Monotonically increasing per-observer sequence number, starting at 1.
  final int sequence;

  /// The label of the observer that emitted this event.
  ///
  /// Distinguishes navigators when listeners are shared across several
  /// observers (e.g. `'root'`, `'tab:home'`).
  final String navigatorLabel;

  /// Resolved route names of the tracked stack at emission time,
  /// bottom-most first.
  final List<String> stackSnapshot;

  /// Depth of the tracked stack at emission time.
  int get stackDepth => stackSnapshot.length;

  /// A short lower-case name for this event's type, e.g. `'push'`.
  String get typeName;

  /// Serializes this event into a JSON-encodable map.
  @mustCallSuper
  Map<String, Object?> toJson() => <String, Object?>{
        'type': typeName,
        'timestamp': timestamp.toIso8601String(),
        'sequence': sequence,
        'navigator': navigatorLabel,
        'route': route.toJson(),
        if (previousRoute != null) 'previousRoute': previousRoute!.toJson(),
        'stack': stackSnapshot,
        'stackDepth': stackDepth,
      };

  @override
  String toString() =>
      'NavEvent.$typeName(#$sequence [$navigatorLabel] ${route.name}'
      '${previousRoute != null ? ' <- ${previousRoute!.name}' : ''})';
}

/// A route was pushed onto the navigator.
final class NavPush extends NavEvent {
  /// Creates a push event.
  const NavPush({
    required super.route,
    required super.timestamp,
    required super.sequence,
    required super.navigatorLabel,
    required super.stackSnapshot,
    super.previousRoute,
  });

  @override
  String get typeName => 'push';
}

/// A route was popped off the navigator.
final class NavPop extends NavEvent {
  /// Creates a pop event.
  const NavPop({
    required super.route,
    required super.timestamp,
    required super.sequence,
    required super.navigatorLabel,
    required super.stackSnapshot,
    super.previousRoute,
  });

  @override
  String get typeName => 'pop';
}

/// A route was removed without an explicit pop transition
/// (e.g. [NavigatorState.removeRoute] or `pushAndRemoveUntil`).
final class NavRemove extends NavEvent {
  /// Creates a remove event.
  const NavRemove({
    required super.route,
    required super.timestamp,
    required super.sequence,
    required super.navigatorLabel,
    required super.stackSnapshot,
    super.previousRoute,
  });

  @override
  String get typeName => 'remove';
}

/// A route was replaced in place by another route.
final class NavReplace extends NavEvent {
  /// Creates a replace event.
  const NavReplace({
    required super.route,
    required super.timestamp,
    required super.sequence,
    required super.navigatorLabel,
    required super.stackSnapshot,
    super.previousRoute,
  });

  /// The route that took the old route's place. Alias of [route].
  RouteInfo get newRoute => route;

  /// The route that was replaced. Alias of [previousRoute].
  RouteInfo? get oldRoute => previousRoute;

  @override
  String get typeName => 'replace';
}

/// The top-most route of the navigator changed.
final class NavTopChange extends NavEvent {
  /// Creates a top-change event.
  const NavTopChange({
    required super.route,
    required super.timestamp,
    required super.sequence,
    required super.navigatorLabel,
    required super.stackSnapshot,
    super.previousRoute,
  });

  @override
  String get typeName => 'topChange';
}

/// The user started an interactive transition (e.g. iOS back swipe).
final class NavGestureStart extends NavEvent {
  /// Creates a gesture-start event.
  const NavGestureStart({
    required super.route,
    required super.timestamp,
    required super.sequence,
    required super.navigatorLabel,
    required super.stackSnapshot,
    super.previousRoute,
  });

  @override
  String get typeName => 'gestureStart';
}

/// The user's interactive transition ended.
final class NavGestureEnd extends NavEvent {
  /// Creates a gesture-end event.
  const NavGestureEnd({
    required super.route,
    required super.timestamp,
    required super.sequence,
    required super.navigatorLabel,
    required super.stackSnapshot,
    super.previousRoute,
  });

  @override
  String get typeName => 'gestureEnd';
}
