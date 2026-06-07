# router_observer

[![pub package](https://img.shields.io/pub/v/router_observer.svg)](https://pub.dev/packages/router_observer)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Structured navigation telemetry for any Flutter `Navigator`.

`router_observer` gives you a drop-in `NavigatorObserver`
(`NavTelemetryObserver`) that turns raw navigation callbacks into immutable,
structured `NavEvent`s and forwards them to pluggable sinks. It works with
`MaterialApp`, `CupertinoApp`, `go_router`, and nested navigators - anything
that accepts a `NavigatorObserver`.

It is built to be safe in large production apps: severity filtering, sampling,
per-minute rate limiting, and PII redaction are all first-class, and telemetry
never throws into the navigation path.

## Features

- **Structured events** - `push`, `pop`, `remove`, `replace`,
  `startUserGesture`, `stopUserGesture`, and `changeTop`, each carrying route
  identity, runtime type, a sanitized stack snapshot, and a timestamp.
- **Pluggable sinks** - ship with `PrintSink`, `LoggingSink`
  (`package:logging`) and `CompositeSink`, or implement `NavEventSink` to fan
  events into your own metrics/tracing/crash backend.
- **Production-safe by default** - `NavObserverConfig` controls severity floor,
  sampling rate, rate limiting, popup/gesture inclusion, and argument capture.
- **PII redaction** - route arguments and results are masked and truncated by a
  configurable `ArgumentRedactor` (`defaultRedactor` masks `token`, `email`,
  `password`, `authorization` out of the box).
- **JSON-ready** - `NavEvent.toJson()` produces an encodable map.
- **No DI lock-in** - depends only on `flutter` and `logging`; optional hooks
  let you source config/sink from your own DI container.

## Install

```yaml
dependencies:
  router_observer: ^0.1.0-dev.1
```

## Quick start

Attach the observer to any navigator:

```dart
import 'package:flutter/material.dart';
import 'package:router_observer/router_observer.dart';

void main() {
  runApp(
    MaterialApp(
      navigatorObservers: [NavTelemetryObserver()],
      home: const HomePage(),
    ),
  );
}
```

By default events are printed as single-line JSON via `debugPrint`.

## Configuration

```dart
NavTelemetryObserver(
  config: const NavObserverConfig(
    minSeverity: NavSeverity.info,
    captureArguments: true,        // redacted before emit
    capturePopResult: false,
    includePopupRoutes: true,
    includeGestureEvents: false,
    sampleRate: 1.0,               // 0..1, lower in chatty apps
    rateLimitPerMinute: 180,
    navigatorLabel: 'root',
  ),
  sink: NavTelemetryObserver.defaultSink(), // Print + logging
);
```

Disable in release builds with a single flag - `observers()` returns an empty
list when disabled, so nothing is attached:

```dart
final observers = NavTelemetryObserver.observers(
  config: NavObserverConfig(enabled: !kReleaseMode),
);
```

## Custom sink

```dart
class AnalyticsSink implements NavEventSink {
  @override
  void add(NavEvent event) {
    myAnalytics.track('nav', event.toJson());
  }

  @override
  Future<void> close() async {}
}

NavTelemetryObserver(
  sink: CompositeSink([
    AnalyticsSink(),
    LoggingSink(loggerName: 'nav'),
  ]),
);
```

## With go_router

```dart
GoRouter(
  observers: [NavTelemetryObserver(config: const NavObserverConfig())],
  routes: [...],
);
```

## PII redaction

Argument and result capture is off by default. When you enable it, values are
passed through `NavObserverConfig.argumentRedactor`. The bundled
`defaultRedactor` masks keys matching `maskKeys` and truncates everything to
`maxChars`. Provide your own `ArgumentRedactor` for stricter policies.

## Testing

`NavObserverConfig.clock` lets you inject a deterministic time source, and a
custom `NavEventSink` lets you assert on emitted `NavEvent`s without touching
real navigation.

## License

MIT - see [LICENSE](LICENSE).
