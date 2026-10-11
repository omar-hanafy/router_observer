import 'package:flutter/widgets.dart';

/// Internal mirror of a navigator's route stack.
///
/// Maintained purely from observer callbacks; uses identity comparison and
/// degrades gracefully when callbacks arrive in unexpected orders (e.g. when
/// the observer is attached after routes already exist).
class StackTracker {
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];

  /// The tracked routes, bottom-most first.
  List<Route<dynamic>> get routes => List<Route<dynamic>>.unmodifiable(_stack);

  /// Number of tracked routes.
  int get depth => _stack.length;

  /// The tracked top-most route, if any.
  Route<dynamic>? get top => _stack.isEmpty ? null : _stack.last;

  /// Whether [route] is currently tracked.
  bool contains(Route<dynamic> route) => _stack.any((r) => identical(r, route));

  /// Records a push of [route] above [previous].
  ///
  /// Duplicate pushes are ignored. When [previous] is unknown, the route is
  /// appended to the top.
  void push(Route<dynamic> route, {Route<dynamic>? previous}) {
    if (contains(route)) return;
    if (previous == null || _stack.isEmpty) {
      _stack.add(route);
      return;
    }
    final int idx = _stack.lastIndexWhere((r) => identical(r, previous));
    if (idx == -1) {
      _stack.add(route);
    } else {
      _stack.insert(idx + 1, route);
    }
  }

  /// Records the removal (pop or remove) of [route].
  void remove(Route<dynamic> route) {
    _stack.removeWhere((r) => identical(r, route));
  }

  /// Records an in-place replacement of [oldRoute] by [newRoute].
  ///
  /// Falls back to a push when [oldRoute] is unknown.
  void replace({Route<dynamic>? oldRoute, Route<dynamic>? newRoute}) {
    if (newRoute == null) {
      if (oldRoute != null) remove(oldRoute);
      return;
    }
    if (oldRoute == null) {
      push(newRoute);
      return;
    }
    final int idx = _stack.indexWhere((r) => identical(r, oldRoute));
    if (idx == -1) {
      push(newRoute);
    } else {
      _stack[idx] = newRoute;
    }
  }

  /// Ensures [route] is tracked at the top of the stack.
  ///
  /// Used to self-heal when the first callback received for a route is
  /// `didChangeTop`, or when an existing page is moved to the top. Observer
  /// callbacks do not describe reordering among routes below the top.
  void ensure(Route<dynamic> route, {Route<dynamic>? previous}) {
    if (identical(top, route)) return;
    remove(route);
    _stack.add(route);
  }

  /// Clears all tracked routes.
  void clear() => _stack.clear();
}
