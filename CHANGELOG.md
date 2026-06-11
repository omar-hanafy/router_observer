# Changelog

## 1.0.0-dev.1

Complete ground-up rebuild as a full navigation observability toolkit.
Grounded in the Flutter 3.x `NavigatorObserver` API (all seven callbacks).

### New

- **Sealed event model**: `NavEvent` is now a sealed hierarchy (`NavPush`,
  `NavPop`, `NavRemove`, `NavReplace`, `NavTopChange`, `NavGestureStart`,
  `NavGestureEnd`) supporting exhaustive `switch`. Events carry `RouteInfo`
  snapshots, timestamps, monotonic sequence numbers, navigator labels, and
  stack snapshots.
- **Smart route name resolution** (`defaultNameResolver`): resolves
  `settings.name`, `Page.name`/`Page.key`, and labels dialogs `[dialog]`,
  bottom sheets `[bottom-sheet]`, popups `[popup]` instead of `<anonymous>`.
- **Composable listeners** (`NavListener`): share one listener instance
  across multiple observers/navigators.
  - `ConsoleNavLogger`: readable one-line logs, optional ANSI colors,
    stack/argument display, JSON mode, custom formatter.
  - `NavBreadcrumbs`: ring buffer with `dump()`/`describe()` for crash
    reports and an `onCrumb` forward callback.
  - `ScreenTracker`: analytics-grade screen views with time-on-screen
    measurement and popup awareness.
  - `NavCallbackListener` and `RecordingNavListener` (test utility).
- **`NavDebugOverlay`**: in-app draggable bubble with a live navigation
  timeline and per-observer current stacks; debug-mode-only by default.
- **Live inspection**: `RouterObserver.currentStack`, `currentRoute`,
  `stackDepth`, and a broadcast `events` stream.
- **Crash-proof delivery**: listener exceptions are reported via
  `FlutterError.reportError` and never reach the navigation code path.

### Breaking changes (from 0.1.0-dev)

- `NavTelemetryObserver` is now `RouterObserver`; `NavObserverConfig` is now
  `RouterObserverSettings`.
- Sinks (`NavEventSink`, `PrintSink`, `LoggingSink`, `CompositeSink`) are
  replaced by listeners (`NavListener`, `ConsoleNavLogger`, ...). Fan-out is
  built in: pass multiple listeners.
- `NavEventType`/`NavSeverity` enums are replaced by the sealed `NavEvent`
  subtypes; severity is gone (filter with `routeFilter`/`eventFilter`).
- `sampleRate` and `rateLimitPerMinute` are replaced by the general
  `eventFilter` predicate (see README recipes).
- The `package:logging` dependency is removed; the package now depends only
  on the Flutter SDK. Forward events to any logger with a 3-line
  `NavCallbackListener`.

## 0.1.0-dev.2

- Validate the automated (GitHub Actions + OIDC Trusted Publisher) release
  pipeline.
- No functional or API changes since `0.1.0-dev.1`.

## 0.1.0-dev.1

Initial preview release.

- `NavTelemetryObserver`: a `NavigatorObserver` that emits structured
  `NavEvent`s for push/pop/remove/replace/gesture/`changeTop` transitions.
- `NavObserverConfig`: severity filtering, sampling, per-minute rate limiting,
  popup/gesture inclusion toggles, and pluggable PII redaction
  (`ArgumentRedactor` / `defaultRedactor`).
- Sinks: `NavEventSink` abstraction with `PrintSink`, `LoggingSink`
  (`package:logging`), and `CompositeSink` fan-out.
- `NavEvent.toJson()` for JSON-encodable structured output.
- Zero DI coupling: optional `loadConfigFromDI` / `loadSinkFromDI` hooks on
  `NavTelemetryObserver.observers(...)`.
