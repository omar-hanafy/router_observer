import 'package:router_observer/src/events.dart';

/// Receives [NavEvent]s from one or more `RouterObserver`s.
///
/// A single listener instance can be shared across several observers; events
/// carry [NavEvent.navigatorLabel] so the source navigator is always known.
///
/// Implementations should be fast and must tolerate being called from the
/// navigation path. Exceptions thrown from [onNavEvent] are caught and
/// reported by the observer; they never break navigation.
abstract class NavListener {
  /// Handles a single emitted [event].
  void onNavEvent(NavEvent event);

  /// Releases any resources held by this listener.
  ///
  /// Called by `RouterObserver.dispose` for listeners it owns.
  void close() {}
}

/// A [NavListener] built from callbacks, for quick inline use.
///
/// ```dart
/// RouterObserver(listeners: [
///   NavCallbackListener(onEvent: (event) => print(event)),
/// ])
/// ```
class NavCallbackListener implements NavListener {
  /// Creates a callback-backed listener.
  NavCallbackListener({required this.onEvent, this.onClose});

  /// Invoked for every event.
  final void Function(NavEvent event) onEvent;

  /// Invoked when the listener is closed.
  final void Function()? onClose;

  @override
  void onNavEvent(NavEvent event) => onEvent(event);

  @override
  void close() => onClose?.call();
}

/// A [NavListener] that records every event it receives.
///
/// Intended for tests:
///
/// ```dart
/// final recorder = RecordingNavListener();
/// final observer = RouterObserver(listeners: [recorder]);
/// // ...pump navigation...
/// expect(recorder.pushes.single.route.name, '/details');
/// ```
class RecordingNavListener implements NavListener {
  final List<NavEvent> _events = <NavEvent>[];

  /// All recorded events, oldest first.
  List<NavEvent> get events => List<NavEvent>.unmodifiable(_events);

  /// Recorded [NavPush] events.
  List<NavPush> get pushes => _events.whereType<NavPush>().toList();

  /// Recorded [NavPop] events.
  List<NavPop> get pops => _events.whereType<NavPop>().toList();

  /// Recorded [NavRemove] events.
  List<NavRemove> get removes => _events.whereType<NavRemove>().toList();

  /// Recorded [NavReplace] events.
  List<NavReplace> get replaces => _events.whereType<NavReplace>().toList();

  /// Recorded [NavTopChange] events.
  List<NavTopChange> get topChanges =>
      _events.whereType<NavTopChange>().toList();

  /// Removes all recorded events.
  void clear() => _events.clear();

  @override
  void onNavEvent(NavEvent event) => _events.add(event);

  @override
  void close() {}
}
