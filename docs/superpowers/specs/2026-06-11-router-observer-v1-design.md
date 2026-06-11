# router_observer v1.0.0 - Design

Date: 2026-06-11
Status: Approved (sections 1 approved interactively; section 2 auto-approved with recommended options per user instruction)

## Goal

Rebuild `router_observer` from the ground up as v1.0.0: the most comprehensive
navigation observer/logger toolkit on pub.dev. Grounded in the Flutter 3.44
`NavigatorObserver` API (all 7 callbacks: `didPush`, `didPop`, `didRemove`,
`didReplace`, `didChangeTop`, `didStartUserGesture`, `didStopUserGesture`).

## Decisions

- Scope: full toolkit (telemetry core + analytics + breadcrumbs + console logger + debug overlay).
- Clean API break from 0.1.0-dev.2; fresh names; no deprecation shims.
- Zero dependencies beyond the Flutter SDK (drop `package:logging`).
- Publish straight to 1.0.0.
- Architecture: Approach A - single `RouterObserver` per navigator, one event
  stream, all toolkit features are composable `NavListener`s. Listeners are
  shared instances across multiple observers; events carry a navigator label.

## Architecture

```
Navigator callbacks
      |
RouterObserver (one per navigator)
      |-- StackTracker (internal route stack mirror)
      |-- Event builder (RouteInfo snapshots, name resolution, redaction)
      |-- Filters (enabled, popups, gestures, routeFilter, eventFilter)
      |
      +--> listeners: [ConsoleNavLogger, NavBreadcrumbs, ScreenTracker, ...]
      +--> events (broadcast Stream<NavEvent>)
      +--> live inspection: currentStack, currentRoute
```

## Core model

### NavEvent (sealed)

Sealed class with one subclass per transition for exhaustive switching:

- `NavPush`, `NavPop`, `NavRemove`, `NavReplace`, `NavTopChange`,
  `NavGestureStart`, `NavGestureEnd`.

Common fields: `RouteInfo route`, `RouteInfo? previousRoute`,
`DateTime timestamp`, `int sequence` (monotonic per observer),
`String navigatorLabel`, `List<String> stackSnapshot`, `int stackDepth`.
`NavReplace` exposes `oldRoute` (alias of `previousRoute`) and `newRoute`.
All events have `toJson()` producing a JSON-encodable map, and a readable
`toString()`.

### RouteInfo

Immutable snapshot of a route at event time: `name` (resolved), `type`
(runtime type string), `arguments` (redacted; null unless capture enabled),
`id` (stable per route instance lifetime), `isFirst`, `isPopup`
(`PopupRoute`), `isModal` (`ModalRoute`), `pageKey` (string, for Page-based
routes).

### Route name resolution

`RouteNameResolver` = `String Function(Route<dynamic> route)`. Default
resolution order:

1. `route.settings.name` if non-empty.
2. If `route.settings is Page`: `page.name`, then `page.key` rendered.
3. Friendly type fallbacks: `[dialog]` for `DialogRoute`/`RawDialogRoute`,
   `[bottom-sheet]` for `ModalBottomSheetRoute`, `[popup]` for other
   `PopupRoute`s, else `[<RuntimeType>]`.

Fully overridable via `RouterObserverSettings.nameResolver`.

### Redaction

`Redactor` typedef; `defaultRedactor` masks values whose keys match
`maskKeys` (defaults: token, password, secret, email, authorization, apikey,
api_key - case-insensitive contains), recurses through maps/iterables with
caps, truncates strings to `maxChars`, never throws. Arguments capture is OFF
by default.

## RouterObserver

```dart
final observer = RouterObserver(
  navigatorLabel: 'root',
  listeners: [...],
  settings: RouterObserverSettings(
    enabled: true,
    captureArguments: false,
    includePopupRoutes: true,
    includeGestureEvents: false,
    includeTopChanges: true,
    routeFilter: (RouteInfo info) => true,
    eventFilter: (NavEvent event) => true,
    nameResolver: defaultNameResolver,
    redactor: defaultRedactor,
    maskKeys: {...},
    maxChars: 200,
    clock: DateTime.now,
  ),
);
```

- `eventFilter` replaces 0.1.0's `sampleRate`/`rateLimitPerMinute`; README
  documents sampling and rate-limit recipes built on it.
- Live inspection: `observer.currentStack` (unmodifiable `List<RouteInfo>`),
  `observer.currentRoute`, `observer.stackDepth`, `observer.events`
  (broadcast `Stream<NavEvent>`).
- One observer per navigator (Flutter constraint); listeners are shared
  instances and events carry `navigatorLabel`.
- Crash-proof: every listener invocation is wrapped; errors reported via
  `FlutterError.reportError` and never propagate into navigation.
- `dispose()` closes the stream and `close()`s owned listeners.

## Toolkit listeners

`NavListener`: `void onNavEvent(NavEvent event)` + `void close()`.

- `NavCallbackListener(onEvent: ..., onClose: ...)` - inline adapter.
- `ConsoleNavLogger` - human-readable one-line logs with optional ANSI colors,
  direction glyphs, stack rendering, args display; options: `useColors`,
  `showStack`, `showArguments`, `printer` (defaults to `debugPrint`),
  `formatter` override. Also a `json: true` mode printing `jsonEncode(event)`.
- `NavBreadcrumbs` - ring buffer (default capacity 100): `entries`,
  `dump()` (list of JSON maps), `describe()` (multiline string for crash
  report attachments), `onCrumb` forward callback, `clear()`.
- `ScreenTracker` - distills raw events into analytics-grade screen views.
  Tracks the top-most non-popup route per navigator; when it changes, emits
  `ScreenView(name, previousName, navigatorLabel, timestamp, timeOnPreviousScreen)`
  via `onScreenView`. `treatPopupsAsScreens` option. Time-on-screen uses the
  observer-provided event timestamps (injectable clock flows through).
- `RecordingNavListener` - public test utility: records all events, exposes
  `events`, typed getters (`pushes`, `pops`, ...), `clear()`.

## Debug overlay

`NavDebugOverlay` - wrap app content (e.g. `MaterialApp.builder`):

```dart
MaterialApp(
  navigatorObservers: [observer],
  builder: (context, child) =>
      NavDebugOverlay(observers: [observer], child: child!),
)
```

Draggable floating bubble; tapping opens a panel with a live event timeline
(latest first, type glyph + route name + time) and the current stack of each
observer. `enabled` defaults to `kDebugMode`; renders nothing when disabled.
Implemented with plain `Stack`/`Overlay`-free composition so it works under
any router. No Material dependency assumptions beyond what `flutter/material`
provides.

## Errors and edge cases

- Listener throws: caught, reported via `FlutterError.reportError`, never rethrown.
- Redactor throws: caught, argument becomes `<unserializable:Type>`.
- `didReplace` with null old/new: tracked stack updated defensively; event
  only emitted when `newRoute != null`.
- `didStopUserGesture` has no route context: event carries current top route
  if known, else synthesized `RouteInfo` named `[unknown]`.
- Multiple removes (`removeRouteBelow`, `popUntil`): each callback handled
  independently; stack mirror uses identity lookups with fallbacks.
- Observer attached after routes exist (`didChangeTop` first): stack mirror
  self-heals by inserting unknown routes.

## Testing

- Unit: name resolver, redactor, breadcrumbs ring buffer, screen tracker
  (with fake clock), event JSON shape, stack tracker edge cases.
- Widget: real `Navigator` flows - push/pop/replace/remove/popUntil, dialogs
  and bottom sheets (popup filtering), Pages API (`Navigator.pages`),
  nested navigators with shared listeners, listener-throw safety,
  `NavDebugOverlay` smoke test (bubble renders, panel opens, disabled mode
  renders child only).
- All tests use `RecordingNavListener` and injectable clock.

## Package layout

```
lib/router_observer.dart            # public exports
lib/src/events.dart                 # NavEvent sealed hierarchy
lib/src/route_info.dart
lib/src/name_resolver.dart
lib/src/redaction.dart
lib/src/settings.dart
lib/src/stack_tracker.dart          # internal
lib/src/observer.dart               # RouterObserver
lib/src/listeners/listener.dart     # NavListener, NavCallbackListener, RecordingNavListener
lib/src/listeners/console_logger.dart
lib/src/listeners/breadcrumbs.dart
lib/src/listeners/screen_tracker.dart
lib/src/overlay/debug_overlay.dart
```

## Docs and release

- README: hero pitch, feature table, quick start, configuration reference,
  recipes (Firebase Analytics, Sentry/Crashlytics breadcrumbs, go_router,
  nested navigators, sampling/rate limiting via eventFilter, release-mode
  stripping), testing guide, overlay screenshot section.
- Full dartdoc on every public member (`public_member_api_docs` clean).
- Example app exercising every feature: named routes, anonymous routes,
  dialogs, bottom sheets, nested tab navigators, overlay toggle.
- CHANGELOG 1.0.0 with breaking-change notes from 0.1.0-dev.2.
- pubspec: version 1.0.0, zero deps beyond flutter, same topics/platforms.
