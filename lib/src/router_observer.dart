import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:logging/logging.dart';

/// ---------------------------
/// Configuration & Utilities
/// ---------------------------

/// Telemetry severity (independent of any external logging library).
enum NavSeverity {
  /// Highest severity. Used for unexpected or destructive transitions.
  error,

  /// Something noteworthy that is not necessarily an error (e.g. a removal).
  warn,

  /// Default severity for ordinary navigation events.
  info,

  /// Verbose detail useful while debugging.
  debug,

  /// The most verbose level (e.g. user gestures).
  trace,
}

/// Event type emitted by the observer.
enum NavEventType {
  /// A route was pushed onto the navigator.
  push,

  /// A route was popped off the navigator.
  pop,

  /// A route was removed without an explicit pop animation.
  remove,

  /// A route was replaced by another route.
  replace,

  /// The user started an interactive (gesture-driven) transition.
  startUserGesture,

  /// The user stopped an interactive (gesture-driven) transition.
  stopUserGesture,

  /// The top-most route changed (Flutter's `didChangeTop` callback).
  changeTop,
}

/// An immutable, structured telemetry event.
@immutable
class NavEvent {
  /// Creates a structured navigation telemetry event.
  ///
  /// All positional context (route identity, stack depth, snapshot) is captured
  /// by [NavTelemetryObserver] at emission time; construct instances directly
  /// only in tests or custom sinks.
  const NavEvent({
    required this.type,
    required this.timestamp,
    required this.navigatorKey,
    required this.navigatorHash,
    required this.stackDepth,
    required this.routeId,
    required this.routeName,
    required this.routeType,
    required this.routeIsCurrent, // best-effort snapshot
    required this.routeSettings,
    required this.stackSnapshot,
    this.previousRouteId,
    this.previousRouteName,
    this.previousRouteType,
    this.resultSummary,
    this.severity = NavSeverity.info,
    this.metadata = const <String, Object?>{},
  });

  /// The kind of navigation transition this event describes.
  final NavEventType type;

  /// Wall-clock time the event was emitted.
  final DateTime timestamp;

  /// A human-readable navigator identifier (label + hash).
  ///
  /// Useful to distinguish nested navigators.
  final String navigatorKey;

  /// The `hashCode` of the originating navigator.
  final int navigatorHash;

  /// Depth of the tracked stack at emission time.
  ///
  /// Computed by an internal stack tracker.
  final int stackDepth;

  /// Identity for the current route; stable for its lifetime (best-effort).
  final int routeId;

  /// The route's settings name, or `<anonymous>` when unnamed.
  final String routeName;

  /// The runtime type of the route, as a string.
  final String routeType;

  /// Whether the route was the current (top) route at emission time.
  final bool routeIsCurrent;

  /// Sanitized / summarized [RouteSettings] (name and optional arguments).
  final Map<String, Object?> routeSettings;

  /// Snapshot of the current stack (sanitized route names).
  final List<String> stackSnapshot;

  /// Identity of the previous route, when one is relevant.
  final int? previousRouteId;

  /// Name of the previous route, when one is relevant.
  final String? previousRouteName;

  /// Runtime type of the previous route, when one is relevant.
  final String? previousRouteType;

  /// Optional, redacted result summary for pop/remove/replace events.
  final Object? resultSummary;

  /// Logging severity for this event.
  final NavSeverity severity;

  /// Arbitrary extra data (should be PII-safe).
  final Map<String, Object?> metadata;

  /// Serializes this event into a JSON-encodable map.
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type.name,
        'ts': timestamp.toIso8601String(),
        'navigatorKey': navigatorKey,
        'navigatorHash': navigatorHash,
        'stackDepth': stackDepth,
        'route': {
          'id': routeId,
          'name': routeName,
          'type': routeType,
          'isCurrent': routeIsCurrent,
          'settings': routeSettings,
        },
        if (previousRouteId != null)
          'previousRoute': {
            'id': previousRouteId,
            'name': previousRouteName,
            'type': previousRouteType,
          },
        if (resultSummary != null) 'result': resultSummary,
        'stackSnapshot': stackSnapshot,
        'severity': severity.name,
        if (metadata.isNotEmpty) 'meta': metadata,
      };
}

/// PII redactor for route arguments/result. Replace or scrub sensitive values.
///
/// Return any JSON-encodable object or primitive.
/// IMPORTANT: Must be pure and fast.
typedef ArgumentRedactor = Object? Function(
  Object? value, {
  required Set<Pattern> maskKeys,
  required int maxChars,
});

/// A very safe default redactor.
///
/// - Masks values for keys matching [maskKeys] (e.g., token/email).
/// - Stringifies everything, truncates to [maxChars], avoids large prints.
/// - Never throws; falls back to a type label.
Object? defaultRedactor(
  Object? value, {
  required Set<Pattern> maskKeys,
  required int maxChars,
}) {
  Object truncate(Object v) {
    final String s = v.toString();
    if (s.length <= maxChars) return s;
    return '${s.substring(0, maxChars)}...(${s.length - maxChars} more)';
  }

  try {
    if (value == null) return null;

    // Map: recursively redact keys.
    if (value is Map) {
      final Map<String, Object?> out = <String, Object?>{};
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        final String key = entry.key.toString();
        final bool mask = maskKeys.any(key.contains);
        out[key] = mask
            ? '***'
            : defaultRedactor(
                entry.value,
                maskKeys: maskKeys,
                maxChars: maxChars,
              );
      }
      return out;
    }

    // Iterable: recurse
    if (value is Iterable) {
      Object? redactIterableValue(Object? element) => defaultRedactor(
            element,
            maskKeys: maskKeys,
            maxChars: maxChars,
          );

      return value
          .take(50) // avoid massive lists
          .map(redactIterableValue)
          .toList(growable: false);
    }

    // Strings & primitives: truncate
    if (value is String || value is num || value is bool) {
      return truncate(value);
    }

    // RouteSettings etc: stringify safely and truncate
    return truncate(value);
  } catch (_) {
    return '<unserializable:${value.runtimeType}>';
  }
}

/// Sink abstraction so you can plug in Logging, Metrics, Tracing, etc.
abstract class NavEventSink {
  /// Handles a single emitted [event]. Implementations must never throw.
  void add(NavEvent event);

  /// Flushes and releases any resources held by the sink.
  Future<void> close() async {}
}

/// Example sink: prints each event as single-line JSON.
class PrintSink implements NavEventSink {
  /// Creates a sink that prints events using [printer] (defaults to
  /// [debugPrint]). [pretty] is reserved for future formatting options.
  PrintSink({
    this.pretty = false,
    void Function(String)? printer,
  }) : _printer = printer ?? debugPrint;

  /// Whether output should be formatted for human reading.
  final bool pretty;
  final void Function(String) _printer;

  @override
  void add(NavEvent event) => _printer(jsonEncode(event.toJson()));

  @override
  Future<void> close() async {}
}

/// Example sink using `package:logging`.
class LoggingSink implements NavEventSink {
  /// Creates a sink that forwards events to a [Logger] named [loggerName].
  LoggingSink({String loggerName = 'NavTelemetry'})
      : _logger = Logger(loggerName);
  final Logger _logger;

  @override
  void add(NavEvent event) {
    final msg = jsonEncode(event.toJson());
    switch (event.severity) {
      case NavSeverity.error:
        _logger.severe(msg);
      case NavSeverity.warn:
        _logger.warning(msg);
      case NavSeverity.info:
        _logger.info(msg);
      case NavSeverity.debug:
        _logger.fine(msg);
      case NavSeverity.trace:
        _logger.finer(msg);
    }
  }

  @override
  Future<void> close() async {}
}

/// Fan-out sink: send to multiple sinks.
class CompositeSink implements NavEventSink {
  /// Creates a sink that forwards every event to each sink in [_sinks].
  CompositeSink(this._sinks);

  final List<NavEventSink> _sinks;

  @override
  void add(NavEvent event) {
    for (final s in _sinks) {
      try {
        s.add(event);
      } catch (e, st) {
        // Never let telemetry sinks crash navigation.
        // Optionally route to a safe fallback here.
        debugPrint('NavTelemetry sink error: $e\n$st');
      }
    }
  }

  @override
  Future<void> close() async {
    for (final s in _sinks) {
      try {
        await s.close();
      } catch (_) {}
    }
  }
}

/// Config with reasonable defaults for huge apps (noise-safe).
class NavObserverConfig {
  /// Creates an observer configuration. Every field has a noise-safe default
  /// suitable for production use in large apps.
  const NavObserverConfig({
    this.enabled = true,
    this.minSeverity = NavSeverity.info,
    this.captureArguments = false,
    this.capturePopResult = false,
    this.captureStackSnapshot = true,
    this.includePopupRoutes = true,
    this.includeChangeTopEvents = true,
    this.includeGestureEvents = true,
    this.maskKeys = const {'token', 'email', 'password', 'authorization'},
    this.maxChars = 200,
    this.sampleRate = 1.0, // 1.0 means log everything
    this.rateLimitPerMinute = 180, // reasonable default for large apps
    this.shouldIgnoreRouteName,
    this.argumentRedactor = defaultRedactor,
    this.clock,
    this.navigatorLabel,
  });

  /// Master switch; when `false` no events are emitted.
  final bool enabled;

  /// Events more verbose than this level are dropped.
  final NavSeverity minSeverity;

  /// Whether to capture (redacted) route arguments.
  final bool captureArguments;

  /// Whether to capture (redacted) pop/replace results.
  final bool capturePopResult;

  /// Whether to include a snapshot of the route stack on each event.
  final bool captureStackSnapshot;

  /// Whether events for [PopupRoute]s (dialogs, menus) are emitted.
  final bool includePopupRoutes;

  /// Whether `didChangeTop` events are emitted.
  final bool includeChangeTopEvents;

  /// Whether interactive gesture start/stop events are emitted.
  final bool includeGestureEvents;

  /// Keys to mask from arguments/results maps.
  final Set<Pattern> maskKeys;

  /// Truncation length of payload text.
  final int maxChars;

  /// Sampling in [0..1]. Use `< 1.0` in extremely chatty apps.
  final double sampleRate;

  /// Cap events/minute per observer instance.
  final int rateLimitPerMinute;

  /// Drop events for certain names (e.g., internal debug overlays).
  final bool Function(String routeName)? shouldIgnoreRouteName;

  /// Redactor implementation.
  final ArgumentRedactor argumentRedactor;

  /// Pluggable clock (for tests).
  final DateTime Function()? clock;

  /// Optional label to distinguish navigators in logs
  /// (e.g., "root", "tab:feed").
  final String? navigatorLabel;

  /// Returns a copy of this config with the provided fields overridden.
  NavObserverConfig copyWith({
    bool? enabled,
    NavSeverity? minSeverity,
    bool? captureArguments,
    bool? capturePopResult,
    bool? captureStackSnapshot,
    bool? includePopupRoutes,
    bool? includeChangeTopEvents,
    bool? includeGestureEvents,
    Set<Pattern>? maskKeys,
    int? maxChars,
    double? sampleRate,
    int? rateLimitPerMinute,
    bool Function(String routeName)? shouldIgnoreRouteName,
    ArgumentRedactor? argumentRedactor,
    DateTime Function()? clock,
    String? navigatorLabel,
  }) {
    return NavObserverConfig(
      enabled: enabled ?? this.enabled,
      minSeverity: minSeverity ?? this.minSeverity,
      captureArguments: captureArguments ?? this.captureArguments,
      capturePopResult: capturePopResult ?? this.capturePopResult,
      captureStackSnapshot: captureStackSnapshot ?? this.captureStackSnapshot,
      includePopupRoutes: includePopupRoutes ?? this.includePopupRoutes,
      includeChangeTopEvents:
          includeChangeTopEvents ?? this.includeChangeTopEvents,
      includeGestureEvents: includeGestureEvents ?? this.includeGestureEvents,
      maskKeys: maskKeys ?? this.maskKeys,
      maxChars: maxChars ?? this.maxChars,
      sampleRate: sampleRate ?? this.sampleRate,
      rateLimitPerMinute: rateLimitPerMinute ?? this.rateLimitPerMinute,
      shouldIgnoreRouteName:
          shouldIgnoreRouteName ?? this.shouldIgnoreRouteName,
      argumentRedactor: argumentRedactor ?? this.argumentRedactor,
      clock: clock ?? this.clock,
      navigatorLabel: navigatorLabel ?? this.navigatorLabel,
    );
  }
}

/// ---------------------------
/// Internal: Stack & Shaping
/// ---------------------------

/// Internal route descriptor tracked by the observer.
class _TrackedRoute {
  _TrackedRoute(this.route);

  final Route<dynamic> route;
  final int id = identityHashCode(Object()); // stable per instance lifetime
  String get name => route.settings.name ?? '<anonymous>';

  String get type => route.runtimeType.toString();
}

/// Tracks a simple stack by listening to observer events. Independent of
/// Navigator internals (no private access).
class _RouteStack {
  final List<_TrackedRoute> _stack = <_TrackedRoute>[];

  int get length => _stack.length;

  List<_TrackedRoute> snapshot() => List.unmodifiable(_stack);

  _TrackedRoute _wrap(Route<dynamic> r) => _TrackedRoute(r);

  _TrackedRoute? _find(Route<dynamic> r) {
    return _stack.cast<_TrackedRoute?>().firstWhere(
          (tr) => tr!.route == r,
          orElse: () => null,
        );
  }

  void push(Route<dynamic> route, {Route<dynamic>? previous}) {
    final existing = _find(route);
    if (existing != null) return; // duplicate safety
    final tr = _wrap(route);

    if (previous == null || _stack.isEmpty) {
      _stack.add(tr);
      return;
    }
    final idx = _stack.indexWhere((e) => e.route == previous);
    if (idx == -1) {
      _stack.add(tr); // fallback
    } else {
      _stack.insert(idx + 1, tr);
    }
  }

  void remove(Route<dynamic> route) {
    _stack.removeWhere((e) => e.route == route);
  }

  void replace({Route<dynamic>? oldRoute, Route<dynamic>? newRoute}) {
    if (oldRoute == null || newRoute == null) return;
    final idx = _stack.indexWhere((e) => e.route == oldRoute);
    if (idx == -1) {
      push(newRoute);
      return;
    }
    _stack[idx] = _wrap(newRoute);
  }
}

/// ---------------------------
/// Observer Implementation
/// ---------------------------

/// A [NavigatorObserver] that emits structured [NavEvent]s to a [NavEventSink].
///
/// Works with any Flutter [Navigator] (Material/Cupertino apps, `go_router`,
/// nested navigators, etc.). Behavior is shaped by [NavObserverConfig]:
/// severity filtering, sampling, per-minute rate limiting, PII redaction, and
/// popup/gesture inclusion. Telemetry never throws into the navigation path.
class NavTelemetryObserver extends NavigatorObserver {
  /// Creates an observer.
  ///
  /// [config] controls filtering/redaction; [sink] receives the events and
  /// defaults to a [PrintSink].
  NavTelemetryObserver({
    NavObserverConfig config = const NavObserverConfig(),
    NavEventSink? sink,
  })  : _cfg = config,
        _sink = sink ?? PrintSink(pretty: true),
        _stack = _RouteStack();

  final NavObserverConfig _cfg;
  final NavEventSink _sink;
  final _RouteStack _stack;

  /// Rate-limit window (per minute).
  int _emittedWithinWindow = 0;
  DateTime _windowStart = DateTime.fromMillisecondsSinceEpoch(0);

  // Helpers
  DateTime _now() => _cfg.clock?.call() ?? DateTime.now();

  bool _shouldSample() =>
      _cfg.sampleRate >= 1.0 ||
      (kIsWeb || (Object().hashCode & 0xFFFF) / 0xFFFF < _cfg.sampleRate);

  bool _rateOk() {
    final now = _now();
    if (now.difference(_windowStart).inMinutes >= 1) {
      _windowStart = now;
      _emittedWithinWindow = 0;
      return true;
    }
    if (_emittedWithinWindow < _cfg.rateLimitPerMinute) {
      return true;
    }
    return false;
  }

  String _describeNavigator() {
    final String label = _cfg.navigatorLabel ?? 'nav';
    final int hash = navigator?.hashCode ?? 0;
    return '$label#$hash';
  }

  /// Central emission path with guards.
  void _emit({
    required NavEventType type,
    required Route<dynamic> route,
    Route<dynamic>? previousRoute,
    Object? popOrReplaceResult,
    NavSeverity severity = NavSeverity.info,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    if (!_cfg.enabled) return;
    if (severity.index > _cfg.minSeverity.index) return;
    if (!_shouldSample()) return;
    if (!_rateOk()) return;

    // Filter popup routes if disabled.
    final isPopup = route is PopupRoute;
    if (isPopup && !_cfg.includePopupRoutes) return;

    final name = route.settings.name ?? '<anonymous>';
    if (_cfg.shouldIgnoreRouteName?.call(name) ?? false) return;

    // Redact settings & result
    final Object? args = _cfg.captureArguments
        ? _cfg.argumentRedactor(
            route.settings.arguments,
            maskKeys: _cfg.maskKeys,
            maxChars: _cfg.maxChars,
          )
        : null;

    final Object? resultSummary =
        (popOrReplaceResult != null && _cfg.capturePopResult)
            ? _cfg.argumentRedactor(
                popOrReplaceResult,
                maskKeys: _cfg.maskKeys,
                maxChars: _cfg.maxChars,
              )
            : null;

    final tr = _stack._find(route) ?? _TrackedRoute(route);
    final pr = previousRoute == null
        ? null
        : _stack._find(previousRoute) ?? _TrackedRoute(previousRoute);

    final stackNames = _cfg.captureStackSnapshot
        ? _stack.snapshot().map((e) => e.name).toList(growable: false)
        : const <String>[];

    final event = NavEvent(
      type: type,
      timestamp: _now(),
      navigatorKey: _describeNavigator(),
      navigatorHash: navigator?.hashCode ?? 0,
      stackDepth: _stack.length,
      routeId: tr.id,
      routeName: tr.name,
      routeType: tr.type,
      routeIsCurrent: route.isCurrent,
      routeSettings: <String, Object?>{
        'name': tr.name,
        if (_cfg.captureArguments) 'args': args,
      },
      stackSnapshot: stackNames,
      previousRouteId: pr?.id,
      previousRouteName: pr?.name,
      previousRouteType: pr?.type,
      resultSummary: resultSummary,
      severity: severity,
      metadata: metadata,
    );

    _sink.add(event);
    _emittedWithinWindow++;
  }

  /// ---------------------------
  /// NavigatorObserver overrides
  /// ---------------------------

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.push(route, previous: previousRoute);
    _emit(
      type: NavEventType.push,
      route: route,
      previousRoute: previousRoute,
      severity: NavSeverity.info,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _emit(
      type: NavEventType.pop,
      route: route,
      previousRoute: previousRoute,
      // Pop can be benign; keep at info/debug in prod.
      severity: NavSeverity.info,
      // We cannot directly access pop result here, so nothing to pass.
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _emit(
      type: NavEventType.remove,
      route: route,
      previousRoute: previousRoute,
      // Removal often implies force close; treat as warning by default.
      severity: NavSeverity.warn,
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _stack.replace(oldRoute: oldRoute, newRoute: newRoute);
    if (newRoute == null || oldRoute == null) return;
    _emit(
      type: NavEventType.replace,
      route: newRoute,
      previousRoute: oldRoute,
      severity: NavSeverity.info,
    );
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    if (!_cfg.includeGestureEvents) return;
    _emit(
      type: NavEventType.startUserGesture,
      route: route,
      previousRoute: previousRoute,
      severity: NavSeverity.trace,
    );
  }

  @override
  void didStopUserGesture() {
    if (!_cfg.includeGestureEvents) return;
    // Route context is ambiguous here; try to pick top if available.
    final top =
        _stack.snapshot().isNotEmpty ? _stack.snapshot().last.route : null;
    if (top == null) return;
    _emit(
      type: NavEventType.stopUserGesture,
      route: top,
      severity: NavSeverity.trace,
    );
  }

  /// Newer Flutter API: called when the top-most route changes.
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (!_cfg.includeChangeTopEvents) return;
    // Ensure the stack contains the topRoute
    // (if this is the first callback received).
    if (_stack._find(topRoute) == null) {
      _stack.push(topRoute, previous: previousTopRoute);
    }
    _emit(
      type: NavEventType.changeTop,
      route: topRoute,
      previousRoute: previousTopRoute,
      severity: NavSeverity.debug,
    );
  }

  /// Allow manual disposal if sinks need to close resources.
  Future<void> dispose() => _sink.close();

  /// Static helper: build a sensible composite sink.
  ///
  /// Combines a [PrintSink] and a [LoggingSink].
  static NavEventSink defaultSink({
    bool pretty = false,
    String loggerName = 'NavTelemetry',
    void Function(String)? printer,
  }) {
    final void Function(String) resolvedPrinter = printer ?? debugPrint;
    return CompositeSink([
      PrintSink(pretty: pretty, printer: resolvedPrinter),
      LoggingSink(loggerName: loggerName),
    ]);
  }

  /// Builds the list of observers to attach to a [Navigator]/router.
  ///
  /// Returns an empty list when the resolved config is disabled, which lets you
  /// strip telemetry entirely in release builds. Provide [loadConfigFromDI] /
  /// [loadSinkFromDI] to source the config/sink from your own DI container
  /// (e.g. a provider) without coupling this package to any DI framework.
  static List<NavigatorObserver> observers({
    NavObserverConfig? config,
    NavEventSink? sink,
    NavObserverConfig Function()? loadConfigFromDI,
    NavEventSink Function()? loadSinkFromDI,
  }) {
    final resolvedCfg =
        loadConfigFromDI?.call() ?? config ?? const NavObserverConfig();
    final resolvedSink =
        loadSinkFromDI?.call() ?? (sink ?? defaultSink(pretty: true));
    if (!resolvedCfg.enabled) return const <NavigatorObserver>[];
    return <NavigatorObserver>[
      NavTelemetryObserver(config: resolvedCfg, sink: resolvedSink),
    ];
  }
}
