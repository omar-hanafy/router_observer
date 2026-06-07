# Changelog

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
