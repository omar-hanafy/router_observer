# router_observer v1.0.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild router_observer as a zero-dependency v1.0.0 navigation observability toolkit: sealed NavEvent model, RouterObserver with composable listeners, console logger, breadcrumbs, screen tracker, and debug overlay.

**Architecture:** Single `RouterObserver` (one per navigator) mirrors the route stack, builds immutable `RouteInfo`/`NavEvent` snapshots, applies filters/redaction, and fans out to shared `NavListener`s plus a broadcast stream. All toolkit features are listeners.

**Tech Stack:** Flutter SDK only (3.27+), Dart 3 sealed classes, flutter_test.

Spec: `docs/superpowers/specs/2026-06-11-router-observer-v1-design.md`

---

### Task 1: Remove old implementation, scaffold layout

**Files:**
- Delete: `lib/src/router_observer.dart`, `test/router_observer_test.dart`
- Modify: `lib/router_observer.dart` (export barrel)
- Create: empty files per layout in spec "Package layout"

- [ ] Delete old source/test, create directory structure
- [ ] Update `pubspec.yaml`: version 1.0.0, remove `logging` dep, update description
- [ ] Commit: `refactor: clear 0.1.0 implementation for v1 rebuild`

### Task 2: RouteInfo + name resolver + redaction (core value types)

**Files:**
- Create: `lib/src/route_info.dart`, `lib/src/name_resolver.dart`, `lib/src/redaction.dart`
- Test: `test/name_resolver_test.dart`, `test/redaction_test.dart`, `test/route_info_test.dart`

API:
```dart
typedef RouteNameResolver = String Function(Route<dynamic> route);
String defaultNameResolver(Route<dynamic> route); // settings.name -> Page.name/key -> [dialog]/[bottom-sheet]/[popup]/[Type]

typedef Redactor = Object? Function(Object? value, {required Set<String> maskKeys, required int maxChars});
Object? defaultRedactor(...); // case-insensitive contains-mask, recursion caps, truncation, never throws

@immutable class RouteInfo {
  const RouteInfo({required this.name, required this.type, required this.id,
    this.arguments, this.isFirst = false, this.isPopup = false,
    this.isModal = false, this.pageKey});
  factory RouteInfo.capture(Route<dynamic> route, {required RouteNameResolver nameResolver, Object? arguments});
  Map<String, Object?> toJson();
}
```

- [ ] Write tests: resolver order (named, Page.name, Page.key, dialog/sheet/popup/typed fallback); redactor (mask keys case-insensitive, nested maps, iterables capped at 50, truncation, throwing toString -> `<unserializable:...>`); RouteInfo.capture fields + toJson
- [ ] Run tests, verify fail; implement; verify pass
- [ ] Commit: `feat: add RouteInfo, name resolution, redaction`

### Task 3: NavEvent sealed hierarchy

**Files:**
- Create: `lib/src/events.dart`
- Test: `test/events_test.dart`

API:
```dart
sealed class NavEvent {
  final RouteInfo route; final RouteInfo? previousRoute;
  final DateTime timestamp; final int sequence; final String navigatorLabel;
  final List<String> stackSnapshot; int get stackDepth;
  Map<String, Object?> toJson(); String get typeName;
}
final class NavPush extends NavEvent {}
final class NavPop extends NavEvent { final Object? result; } // result reserved, null in v1 (observer API gives none)
final class NavRemove extends NavEvent {}
final class NavReplace extends NavEvent { RouteInfo get newRoute => route; RouteInfo? get oldRoute => previousRoute; }
final class NavTopChange extends NavEvent {}
final class NavGestureStart extends NavEvent {}
final class NavGestureEnd extends NavEvent {}
```

- [ ] Tests: toJson shape per subtype, exhaustive switch compiles, toString readable
- [ ] Implement, pass, commit: `feat: add sealed NavEvent hierarchy`

### Task 4: Settings + NavListener contracts

**Files:**
- Create: `lib/src/settings.dart`, `lib/src/listeners/listener.dart`
- Test: `test/listener_test.dart`

API:
```dart
class RouterObserverSettings { // all fields final, const ctor, copyWith
  enabled, captureArguments, includePopupRoutes, includeGestureEvents,
  includeTopChanges, routeFilter (bool Function(RouteInfo)?),
  eventFilter (bool Function(NavEvent)?), nameResolver, redactor,
  maskKeys (Set<String>), maxChars (int), clock (DateTime Function());
}
abstract class NavListener { void onNavEvent(NavEvent event); void close() {} }
class NavCallbackListener implements NavListener { ... }
class RecordingNavListener implements NavListener {
  List<NavEvent> events; pushes/pops/removes/replaces/topChanges getters; clear();
}
```

- [ ] Tests: copyWith, callback listener forwards, recording listener filters by type
- [ ] Implement, pass, commit: `feat: add settings and listener contracts`

### Task 5: Stack tracker (internal)

**Files:**
- Create: `lib/src/stack_tracker.dart`
- Test: `test/stack_tracker_test.dart`

Behavior: mirrors Navigator stack by identity; `push(route, previous)` inserts after previous (append fallback), duplicate-safe; `remove(route)`; `replace(old, new)` in place (push fallback); `ensure(route, previous)` self-heal for didChangeTop-first; `routes` snapshot; `find(route)`.

- [ ] Tests: ordered push, insert-above-previous, remove middle (popUntil pattern), replace missing old, duplicate push ignored, self-heal
- [ ] Implement, pass, commit: `feat: add internal stack tracker`

### Task 6: RouterObserver

**Files:**
- Create: `lib/src/observer.dart`
- Modify: `lib/router_observer.dart` (exports)
- Test: `test/observer_test.dart` (widget tests with real Navigator)

API:
```dart
class RouterObserver extends NavigatorObserver {
  RouterObserver({String navigatorLabel = 'root',
    List<NavListener> listeners = const [],
    RouterObserverSettings settings = const RouterObserverSettings()});
  List<RouteInfo> get currentStack; RouteInfo? get currentRoute; int get stackDepth;
  Stream<NavEvent> get events; // broadcast, lazily created
  Future<void> dispose();
}
```
Emission path: update stack -> guards (enabled, popup, gesture, topChange, routeFilter) -> build RouteInfo pair (args redacted if captureArguments) -> build event (sequence++, clock, label, snapshot) -> eventFilter -> try/catch per listener with FlutterError.reportError -> stream.add.

- [ ] Widget tests: push/pop named + anonymous, replace, remove, popUntil, dialog included/excluded via includePopupRoutes, gesture toggles, topChange toggle, routeFilter drops, eventFilter sampling, captureArguments redacts, listener-throw does not break navigation, currentStack/currentRoute accuracy, events stream emits, nested navigators with shared listener get distinct labels, disabled emits nothing
- [ ] Implement, pass, commit: `feat: add RouterObserver core`

### Task 7: ConsoleNavLogger

**Files:**
- Create: `lib/src/listeners/console_logger.dart`
- Test: `test/console_logger_test.dart`

Options: `useColors` (default: only when stdout supports; simple bool default false to be debugPrint-safe), `showStack`, `showArguments`, `json`, `printer` (default debugPrint), `formatter` override. One line per event: `[root] -> push  /details (from /home) depth=2`.

- [ ] Tests: line content per event type via captured printer, json mode emits valid JSON, formatter override, colors wrap with ANSI when enabled
- [ ] Implement, pass, commit: `feat: add ConsoleNavLogger`

### Task 8: NavBreadcrumbs

**Files:**
- Create: `lib/src/listeners/breadcrumbs.dart`
- Test: `test/breadcrumbs_test.dart`

`NavBreadcrumbs({int capacity = 100, void Function(NavEvent)? onCrumb})`; `entries` (oldest first), `dump()` JSON list, `describe()` multiline, `clear()`.

- [ ] Tests: ring eviction, dump/describe shape, onCrumb forwarding
- [ ] Implement, pass, commit: `feat: add NavBreadcrumbs`

### Task 9: ScreenTracker

**Files:**
- Create: `lib/src/listeners/screen_tracker.dart`
- Test: `test/screen_tracker_test.dart`

```dart
@immutable class ScreenView { name, previousName, navigatorLabel, timestamp, timeOnPreviousScreen (Duration?); toJson(); }
class ScreenTracker implements NavListener {
  ScreenTracker({required void Function(ScreenView view) onScreenView, bool treatPopupsAsScreens = false});
}
```
Tracks top non-popup route per navigatorLabel from push/pop/replace/remove/topChange; emits on change with duration since previous view (event timestamps).

- [ ] Tests (fake clock through observer settings + synthetic events): push emits view, pop emits return view with duration, popup ignored by default / counted when enabled, multiple navigators tracked independently
- [ ] Implement, pass, commit: `feat: add ScreenTracker`

### Task 10: NavDebugOverlay

**Files:**
- Create: `lib/src/overlay/debug_overlay.dart`
- Test: `test/debug_overlay_test.dart`

`NavDebugOverlay({required List<RouterObserver> observers, required Widget child, bool? enabled})` - enabled defaults to kDebugMode. Stack(child, draggable bubble); tap opens panel (timeline newest-first + per-observer current stack); close button. Pure Stack composition, Directionality/Material-safe.

- [ ] Widget tests: disabled renders only child; bubble visible when enabled; tap opens panel; events appear in timeline; stack section lists current routes
- [ ] Implement, pass, commit: `feat: add NavDebugOverlay`

### Task 11: Barrel exports + analyze + format

- [ ] `lib/router_observer.dart` exports all public APIs (hide internals: stack_tracker)
- [ ] Run: `dart format .` then full `dart analyze` -> zero issues (package has public_member_api_docs via flutter_lints? ensure strict analysis_options)
- [ ] `flutter test` full suite green
- [ ] Commit: `chore: finalize exports, analyze clean`

### Task 12: Example app

**Files:**
- Modify: `example/lib/main.dart`, `example/pubspec.yaml`

Demo: named routes (home/details/settings), anonymous route, dialog, bottom sheet, nested tab navigators with labeled observers + shared listeners, ScreenTracker printout, NavDebugOverlay via builder, breadcrumb dump button.

- [ ] Implement; `dart analyze example` clean
- [ ] Commit: `docs: rebuild example app for v1`

### Task 13: README, CHANGELOG, pubspec polish

- [ ] README per spec "Docs and release" (recipes: Firebase, Sentry, go_router, nested navigators, sampling/rate-limit via eventFilter, release stripping, testing)
- [ ] CHANGELOG 1.0.0 with migration notes from 0.1.0-dev.2
- [ ] `flutter pub publish --dry-run` passes
- [ ] Commit: `docs: v1.0.0 README and CHANGELOG`

### Task 14: Final verification

- [ ] `dart format --set-exit-if-changed .` clean, `dart analyze` clean, `flutter test` green, dry-run publish OK
- [ ] Review diff vs spec for coverage gaps
- [ ] Commit any fixes
