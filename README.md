# router_observer

[![pub package](https://img.shields.io/pub/v/router_observer.svg)](https://pub.dev/packages/router_observer)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A complete navigation observability toolkit for Flutter. One observer, every
navigation insight: structured events, readable console logs, crash-report
breadcrumbs, analytics screen tracking with time-on-screen, live stack
inspection, and an in-app debug overlay.

Works with anything that accepts a `NavigatorObserver`: `MaterialApp`,
`CupertinoApp`, `go_router`, `auto_route`, nested navigators.

## Why this package

Flutter's `NavigatorObserver` gives you seven raw callbacks and leaves the
rest to you. `router_observer` turns them into a production-grade pipeline:

| Feature | What you get |
| --- | --- |
| **Structured events** | Sealed `NavEvent` hierarchy (`NavPush`, `NavPop`, `NavRemove`, `NavReplace`, `NavTopChange`, `NavGestureStart`, `NavGestureEnd`) with exhaustive `switch` support, JSON serialization, timestamps, sequence numbers, and stack snapshots |
| **Smart route names** | No more `<anonymous>`: resolves `settings.name`, `Page.name`/`Page.key`, and labels dialogs `[dialog]`, sheets `[bottom-sheet]`, popups `[popup]` |
| **Console logging** | One-line, color-capable, human-readable logs or single-line JSON |
| **Breadcrumbs** | Ring buffer of recent navigation, ready to attach to Sentry/Crashlytics reports |
| **Screen tracking** | Analytics-grade screen views with time-on-screen measurement, popup-aware |
| **Debug overlay** | Draggable in-app bubble that expands into a live navigation timeline + current stacks |
| **Stack inspection** | `observer.currentStack`, `currentRoute`, `stackDepth`, and a broadcast `events` stream |
| **PII safety** | Argument capture is opt-in and always redacted (tokens, passwords, emails masked by default) |
| **Crash-proof** | Listener exceptions are reported via `FlutterError.reportError` and never break navigation |
| **Zero dependencies** | Only the Flutter SDK |

## Quick start

```yaml
dependencies:
  router_observer: ^1.0.0-dev.1
```

```dart
import 'package:flutter/material.dart';
import 'package:router_observer/router_observer.dart';

void main() {
  runApp(
    MaterialApp(
      navigatorObservers: [
        RouterObserver(listeners: [ConsoleNavLogger()]),
      ],
      home: const HomePage(),
    ),
  );
}
```

Console output:

```text
[root] -> push         /details (from /home) depth=2
[root] <- pop          /details (to /home) depth=1
[root] <> replace      /signup (was /login) depth=1
```

## The event model

Every transition becomes an immutable `NavEvent` you can switch over
exhaustively:

```dart
NavCallbackListener(onEvent: (event) {
  switch (event) {
    case NavPush(:final route):
      analytics.track('push', {'screen': route.name});
    case NavPop(:final previousRoute):
      debugPrint('back to ${previousRoute?.name}');
    case NavRemove() || NavReplace():
      // stack surgery
    case NavTopChange() || NavGestureStart() || NavGestureEnd():
      break;
  }
})
```

Each event carries a `RouteInfo` snapshot (`name`, `type`, `id`, `isFirst`,
`isPopup`, redacted `arguments`, `pageKey`), the previous route when relevant,
a `timestamp`, a monotonic `sequence`, the `navigatorLabel`, and a
`stackSnapshot`. `event.toJson()` produces a JSON-encodable map.

## Configuration

```dart
RouterObserver(
  navigatorLabel: 'root',
  listeners: [ConsoleNavLogger(), NavBreadcrumbs()],
  settings: RouterObserverSettings(
    enabled: true,
    captureArguments: false,     // opt-in; redacted when enabled
    includePopupRoutes: true,    // dialogs, sheets, menus
    includeGestureEvents: false, // iOS back-swipe start/end
    includeTopChanges: true,     // didChangeTop events
    routeFilter: (route) => !route.name.startsWith('/debug'),
    eventFilter: (event) => true,
    nameResolver: defaultNameResolver,
    redactor: defaultRedactor,
    maskKeys: defaultMaskKeys,   // token, password, secret, email, ...
    maxChars: 200,
    clock: DateTime.now,         // injectable for tests
  ),
)
```

## Recipes

### Crash-report breadcrumbs (Sentry, Crashlytics, ...)

```dart
final breadcrumbs = NavBreadcrumbs(
  capacity: 50,
  // Optional: forward each event immediately to your crash SDK.
  onCrumb: (event) => Sentry.addBreadcrumb(
    Breadcrumb(category: 'navigation', message: event.toString()),
  ),
);

RouterObserver(listeners: [breadcrumbs]);

// Or attach the whole trail when a crash happens:
crashReporter.attach('navigation', breadcrumbs.describe());
```

### Screen-view analytics with time-on-screen (Firebase, Mixpanel, ...)

```dart
RouterObserver(listeners: [
  ScreenTracker(onScreenView: (view) {
    FirebaseAnalytics.instance.logScreenView(screenName: view.name);
    if (view.timeOnPreviousScreen != null) {
      analytics.track('screen_time', {
        'screen': view.previousName,
        'seconds': view.timeOnPreviousScreen!.inSeconds,
      });
    }
  }),
]);
```

`ScreenTracker` collapses noisy raw events (pushes, top changes, popup
traffic) into clean "the visible screen changed" callbacks.

### go_router

```dart
GoRouter(
  observers: [RouterObserver(listeners: [ConsoleNavLogger()])],
  routes: [...],
);
```

### Nested navigators

A `NavigatorObserver` can only watch one navigator, so create one
`RouterObserver` per navigator and share the listener instances. Events carry
the navigator label:

```dart
final logger = ConsoleNavLogger();
final rootObserver = RouterObserver(listeners: [logger]);
final tabObserver = RouterObserver(
  navigatorLabel: 'tab:feed',
  listeners: [logger],
);
```

### In-app debug overlay

```dart
MaterialApp(
  navigatorObservers: [observer],
  builder: (context, child) => NavDebugOverlay(
    observers: [rootObserver, tabObserver],
    child: child!,
  ),
)
```

A draggable bubble floats over your app; tap it for a live event timeline and
the current route stack of every observer. Enabled only in debug mode by
default, so it is safe to leave in place for release builds.

### Sampling and rate limiting

`eventFilter` is the general-purpose hook:

```dart
// Sample 10% of events.
final random = Random();
RouterObserverSettings(eventFilter: (_) => random.nextDouble() < 0.1);

// Rate-limit to 120 events per minute.
var windowStart = DateTime.now();
var count = 0;
RouterObserverSettings(eventFilter: (event) {
  if (event.timestamp.difference(windowStart) > const Duration(minutes: 1)) {
    windowStart = event.timestamp;
    count = 0;
  }
  return ++count <= 120;
});
```

### Stripping in release builds

```dart
MaterialApp(
  navigatorObservers: [
    if (!kReleaseMode) RouterObserver(listeners: [ConsoleNavLogger()]),
  ],
)
```

Or keep the observer and disable it: `RouterObserverSettings(enabled: kDebugMode)`.

### Custom listener

```dart
class TracingListener implements NavListener {
  @override
  void onNavEvent(NavEvent event) =>
      tracer.span('nav.${event.typeName}', event.toJson());

  @override
  void close() => tracer.flush();
}
```

## PII redaction

Argument capture is off by default. When enabled, values pass through the
configured `Redactor` first. `defaultRedactor` masks any map key containing
`token`, `password`, `secret`, `email`, `authorization`, `apikey`, or
`api_key` (case-insensitive), recurses through nested maps/lists with caps,
truncates long strings, and never throws.

## Testing your navigation

The package ships test utilities:

```dart
testWidgets('opens details', (tester) async {
  final recorder = RecordingNavListener();
  await tester.pumpWidget(MaterialApp(
    navigatorObservers: [
      RouterObserver(
        listeners: [recorder],
        settings: RouterObserverSettings(clock: () => DateTime.utc(2026)),
      ),
    ],
    // ...
  ));

  // ...drive the app...

  expect(recorder.pushes.last.route.name, '/details');
});
```

## License

MIT - see [LICENSE](LICENSE).
