/// Structured navigation telemetry for any Flutter [Navigator].
///
/// `router_observer` provides [NavTelemetryObserver], a drop-in
/// [NavigatorObserver] that emits immutable, structured [NavEvent]s to
/// pluggable [NavEventSink]s. It works with Material/Cupertino apps,
/// `go_router`, and nested navigators alike.
///
/// Features:
///
/// - **Structured events** - push/pop/remove/replace/gesture/changeTop, each
///   carrying route identity, a stack snapshot, and a timestamp.
/// - **Pluggable sinks** - [PrintSink], [LoggingSink] (`package:logging`),
///   [CompositeSink], or your own metrics/tracing backend.
/// - **Production-safe** - severity filtering, sampling, per-minute rate
///   limiting, and PII redaction via [NavObserverConfig].
///
/// ## Quick start
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:router_observer/router_observer.dart';
///
/// void main() {
///   runApp(
///     MaterialApp(
///       navigatorObservers: [NavTelemetryObserver()],
///       home: const HomePage(),
///     ),
///   );
/// }
/// ```
library;

export 'src/router_observer.dart'
    show
        ArgumentRedactor,
        CompositeSink,
        LoggingSink,
        NavEvent,
        NavEventSink,
        NavEventType,
        NavObserverConfig,
        NavSeverity,
        NavTelemetryObserver,
        PrintSink,
        defaultRedactor;
