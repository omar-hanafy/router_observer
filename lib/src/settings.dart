import 'package:flutter/material.dart';

import 'package:router_observer/src/events.dart';
import 'package:router_observer/src/name_resolver.dart';
import 'package:router_observer/src/redaction.dart';
import 'package:router_observer/src/route_info.dart';

/// Predicate deciding whether events for a route should be emitted at all.
typedef RouteFilter = bool Function(RouteInfo route);

/// Predicate deciding whether a fully built event should be delivered.
///
/// This is the general-purpose hook for sampling, rate limiting, or any
/// custom suppression logic.
typedef EventFilter = bool Function(NavEvent event);

/// Configuration for `RouterObserver`.
///
/// Every field has a production-safe default: arguments are not captured,
/// gestures are not logged, and nothing sensitive leaves the app unless you
/// opt in.
@immutable
class RouterObserverSettings {
  /// Creates observer settings.
  const RouterObserverSettings({
    this.enabled = true,
    this.captureArguments = false,
    this.includePopupRoutes = true,
    this.includeGestureEvents = false,
    this.includeTopChanges = true,
    this.routeFilter,
    this.eventFilter,
    this.nameResolver = defaultNameResolver,
    this.redactor = defaultRedactor,
    this.maskKeys = defaultMaskKeys,
    this.maxChars = 200,
    this.clock,
  });

  /// Master switch; when `false` no events are emitted.
  final bool enabled;

  /// Whether to attach (redacted) route arguments to events.
  ///
  /// Off by default; when enabled, arguments pass through [redactor] first.
  final bool captureArguments;

  /// Whether events for [PopupRoute]s (dialogs, menus, bottom sheets)
  /// are emitted.
  final bool includePopupRoutes;

  /// Whether [NavGestureStart] / [NavGestureEnd] events are emitted.
  final bool includeGestureEvents;

  /// Whether [NavTopChange] events are emitted.
  final bool includeTopChanges;

  /// Drops all events whose primary route fails this predicate.
  final RouteFilter? routeFilter;

  /// Drops fully built events failing this predicate.
  ///
  /// Use for sampling or rate limiting; see the package README for recipes.
  final EventFilter? eventFilter;

  /// Resolves route display names. Defaults to [defaultNameResolver].
  final RouteNameResolver nameResolver;

  /// Redacts captured arguments. Defaults to [defaultRedactor].
  final Redactor redactor;

  /// Key fragments masked by the [redactor].
  final Set<String> maskKeys;

  /// Maximum string length kept by the [redactor] before truncation.
  final int maxChars;

  /// Time source for event timestamps; defaults to [DateTime.now].
  ///
  /// Inject a fake clock in tests for deterministic timestamps.
  final DateTime Function()? clock;

  /// Returns a copy of these settings with the given fields replaced.
  RouterObserverSettings copyWith({
    bool? enabled,
    bool? captureArguments,
    bool? includePopupRoutes,
    bool? includeGestureEvents,
    bool? includeTopChanges,
    RouteFilter? routeFilter,
    EventFilter? eventFilter,
    RouteNameResolver? nameResolver,
    Redactor? redactor,
    Set<String>? maskKeys,
    int? maxChars,
    DateTime Function()? clock,
  }) {
    return RouterObserverSettings(
      enabled: enabled ?? this.enabled,
      captureArguments: captureArguments ?? this.captureArguments,
      includePopupRoutes: includePopupRoutes ?? this.includePopupRoutes,
      includeGestureEvents: includeGestureEvents ?? this.includeGestureEvents,
      includeTopChanges: includeTopChanges ?? this.includeTopChanges,
      routeFilter: routeFilter ?? this.routeFilter,
      eventFilter: eventFilter ?? this.eventFilter,
      nameResolver: nameResolver ?? this.nameResolver,
      redactor: redactor ?? this.redactor,
      maskKeys: maskKeys ?? this.maskKeys,
      maxChars: maxChars ?? this.maxChars,
      clock: clock ?? this.clock,
    );
  }
}
