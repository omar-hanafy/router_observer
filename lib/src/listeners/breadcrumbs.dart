import 'package:router_observer/src/events.dart';
import 'package:router_observer/src/listeners/listener.dart';

/// A [NavListener] that keeps the last N navigation events in memory,
/// ready to attach to crash reports.
///
/// ```dart
/// final breadcrumbs = NavBreadcrumbs(capacity: 50);
/// final observer = RouterObserver(listeners: [breadcrumbs]);
///
/// // In your crash handler:
/// crashReporter.attach('navigation', breadcrumbs.describe());
/// ```
///
/// Use [onCrumb] to forward each event immediately to a crash SDK's own
/// breadcrumb API (Sentry, Crashlytics, ...) instead of, or in addition to,
/// buffering.
class NavBreadcrumbs implements NavListener {
  /// Creates a breadcrumb buffer holding at most [capacity] events.
  NavBreadcrumbs({this.capacity = 100, this.onCrumb})
      : assert(capacity > 0, 'capacity must be positive');

  /// Maximum number of events retained; older events are evicted first.
  final int capacity;

  /// Invoked for every event, before buffering.
  final void Function(NavEvent event)? onCrumb;

  final List<NavEvent> _buffer = <NavEvent>[];

  /// Buffered events, oldest first.
  List<NavEvent> get entries => List<NavEvent>.unmodifiable(_buffer);

  /// Serializes the buffer to a JSON-encodable list, oldest first.
  List<Map<String, Object?>> dump() =>
      _buffer.map((e) => e.toJson()).toList(growable: false);

  /// Renders the buffer as a multiline, human-readable trail, oldest first.
  ///
  /// One line per event: `12:01:33.456 [root] push /details (depth 2)`.
  String describe() {
    final StringBuffer buffer = StringBuffer();
    for (final NavEvent event in _buffer) {
      final DateTime t = event.timestamp;
      final String time = '${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}'
          '.${t.millisecond.toString().padLeft(3, '0')}';
      buffer.writeln(
        '$time [${event.navigatorLabel}] ${event.typeName} '
        '${event.route.name} (depth ${event.stackDepth})',
      );
    }
    return buffer.toString();
  }

  /// Removes all buffered events.
  void clear() => _buffer.clear();

  @override
  void onNavEvent(NavEvent event) {
    onCrumb?.call(event);
    _buffer.add(event);
    if (_buffer.length > capacity) {
      _buffer.removeRange(0, _buffer.length - capacity);
    }
  }

  @override
  void close() => clear();

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
