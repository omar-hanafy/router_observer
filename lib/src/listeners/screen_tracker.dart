import 'package:flutter/foundation.dart';

import 'package:router_observer/src/events.dart';
import 'package:router_observer/src/listeners/listener.dart';
import 'package:router_observer/src/route_info.dart';

/// An analytics-grade "screen view": the user-visible screen changed.
@immutable
class ScreenView {
  /// Creates a screen view record.
  const ScreenView({
    required this.name,
    required this.navigatorLabel,
    required this.timestamp,
    this.previousName,
    this.timeOnPreviousScreen,
    this.arguments,
  });

  /// The resolved name of the screen now visible.
  final String name;

  /// The screen that was visible before this one, if any.
  final String? previousName;

  /// The navigator this view belongs to.
  final String navigatorLabel;

  /// When the screen became visible.
  final DateTime timestamp;

  /// How long the previous screen was visible, when known.
  ///
  /// Ready to feed engagement/time-on-screen analytics.
  final Duration? timeOnPreviousScreen;

  /// Redacted arguments of the new screen's route, when captured.
  final Object? arguments;

  /// Serializes this view into a JSON-encodable map.
  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        if (previousName != null) 'previousName': previousName,
        'navigator': navigatorLabel,
        'timestamp': timestamp.toIso8601String(),
        if (timeOnPreviousScreen != null)
          'timeOnPreviousScreenMs': timeOnPreviousScreen!.inMilliseconds,
        if (arguments != null) 'arguments': arguments,
      };

  @override
  String toString() =>
      'ScreenView($name on $navigatorLabel'
      '${previousName != null ? ', from $previousName' : ''})';
}

/// A [NavListener] that distills raw navigation events into [ScreenView]s,
/// the unit analytics tools care about.
///
/// Raw events are noisy: a single user action can produce a push, a top
/// change, and popup traffic. `ScreenTracker` collapses them into "the
/// visible screen changed" callbacks with time-on-screen measurement:
///
/// ```dart
/// ScreenTracker(
///   onScreenView: (view) => analytics.logScreenView(
///     screenName: view.name,
///   ),
/// )
/// ```
///
/// Popups (dialogs, bottom sheets) are not treated as screens unless
/// [treatPopupsAsScreens] is `true`. A shared instance tracks every
/// navigator independently by label.
class ScreenTracker implements NavListener {
  /// Creates a screen tracker delivering views to [onScreenView].
  ScreenTracker({required this.onScreenView, this.treatPopupsAsScreens = false});

  /// Invoked whenever the visible screen of a navigator changes.
  final void Function(ScreenView view) onScreenView;

  /// Whether [PopupRoute]s (dialogs, menus, sheets) count as screens.
  final bool treatPopupsAsScreens;

  final Map<String, _CurrentScreen> _current = <String, _CurrentScreen>{};

  @override
  void onNavEvent(NavEvent event) {
    final RouteInfo? candidate = switch (event) {
      NavPush() || NavReplace() || NavTopChange() => event.route,
      NavPop() || NavRemove() => event.previousRoute,
      NavGestureStart() || NavGestureEnd() => null,
    };
    if (candidate == null) return;
    if (candidate.isPopup && !treatPopupsAsScreens) return;

    final _CurrentScreen? previous = _current[event.navigatorLabel];
    if (previous != null && previous.name == candidate.name) return;

    final ScreenView view = ScreenView(
      name: candidate.name,
      previousName: previous?.name,
      navigatorLabel: event.navigatorLabel,
      timestamp: event.timestamp,
      timeOnPreviousScreen:
          previous == null ? null : event.timestamp.difference(previous.since),
      arguments: candidate.arguments,
    );
    _current[event.navigatorLabel] =
        _CurrentScreen(candidate.name, event.timestamp);
    onScreenView(view);
  }

  @override
  void close() => _current.clear();
}

class _CurrentScreen {
  const _CurrentScreen(this.name, this.since);

  final String name;
  final DateTime since;
}
