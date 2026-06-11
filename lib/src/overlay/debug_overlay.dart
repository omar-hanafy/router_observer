import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:router_observer/src/events.dart';
import 'package:router_observer/src/observer.dart';
import 'package:router_observer/src/route_info.dart';

/// An in-app navigation inspector: a draggable bubble that expands into a
/// live event timeline plus the current route stack of every observer.
///
/// Wrap your app content, typically via [MaterialApp.builder] so it floats
/// above every route:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [observer],
///   builder: (context, child) => NavDebugOverlay(
///     observers: [observer],
///     child: child!,
///   ),
/// )
/// ```
///
/// The overlay is enabled only in debug mode by default; in release builds
/// it renders [child] untouched, so it is safe to leave in place.
class NavDebugOverlay extends StatefulWidget {
  /// Creates a navigation debug overlay.
  const NavDebugOverlay({
    required this.observers,
    required this.child,
    this.enabled,
    this.maxEvents = 200,
    super.key,
  });

  /// The observers to inspect. Their [RouterObserver.events] streams feed
  /// the timeline.
  final List<RouterObserver> observers;

  /// The app content rendered beneath the overlay.
  final Widget child;

  /// Whether the overlay is shown. Defaults to [kDebugMode].
  final bool? enabled;

  /// Maximum number of timeline entries kept in memory.
  final int maxEvents;

  @override
  State<NavDebugOverlay> createState() => _NavDebugOverlayState();
}

class _NavDebugOverlayState extends State<NavDebugOverlay> {
  final List<NavEvent> _events = <NavEvent>[];
  final List<StreamSubscription<NavEvent>> _subscriptions =
      <StreamSubscription<NavEvent>>[];
  bool _open = false;
  Offset? _bubbleOffset;

  bool get _enabled => widget.enabled ?? kDebugMode;

  @override
  void initState() {
    super.initState();
    if (_enabled) _subscribe();
  }

  @override
  void didUpdateWidget(NavDebugOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.observers, widget.observers) ||
        oldWidget.enabled != widget.enabled) {
      _unsubscribe();
      if (_enabled) _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    for (final RouterObserver observer in widget.observers) {
      _subscriptions.add(observer.events.listen(_onEvent));
    }
  }

  void _unsubscribe() {
    for (final StreamSubscription<NavEvent> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  void _onEvent(NavEvent event) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, event);
      if (_events.length > widget.maxEvents) {
        _events.removeRange(widget.maxEvents, _events.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;

    final TextDirection direction =
        Directionality.maybeOf(context) ?? TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Stack(
        children: <Widget>[
          widget.child,
          if (_open) _buildPanel(context),
          _buildBubble(context),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final Size size = MediaQuery.maybeOf(context)?.size ?? const Size(400, 800);
    final Offset offset =
        _bubbleOffset ?? Offset(size.width - 72, size.height - 160);

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        key: const ValueKey<String>('nav_debug_overlay_bubble'),
        onPanUpdate: (DragUpdateDetails details) {
          setState(() => _bubbleOffset = offset + details.delta);
        },
        onTap: () => setState(() => _open = !_open),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xE6263238),
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(blurRadius: 6, color: Colors.black38),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.alt_route, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              key: const ValueKey<String>('nav_debug_overlay_panel'),
              color: const Color(0xFF263238),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHeader(),
                  _buildStacks(),
                  const Divider(height: 1, color: Colors.white24),
                  Expanded(child: _buildTimeline()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'Navigation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // No tooltips here: the overlay lives above the Navigator, where
          // no Overlay widget exists to host them.
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () => setState(_events.clear),
          ),
          IconButton(
            key: const ValueKey<String>('nav_debug_overlay_close'),
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => setState(() => _open = false),
          ),
        ],
      ),
    );
  }

  Widget _buildStacks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final RouterObserver observer in widget.observers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${observer.navigatorLabel}: '
                '${observer.currentStack.map((RouteInfo r) => r.name).join(' / ')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (_events.isEmpty) {
      return const Center(
        child: Text(
          'No navigation events yet',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _events.length,
      itemBuilder: (BuildContext context, int index) {
        final NavEvent event = _events[index];
        final DateTime t = event.timestamp;
        final String time = '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}:'
            '${t.second.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                child: Text(
                  event.typeName,
                  style: TextStyle(color: _typeColor(event), fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  '[${event.navigatorLabel}] ${event.route.name}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _typeColor(NavEvent event) => switch (event) {
        NavPush() => Colors.greenAccent,
        NavPop() => Colors.cyanAccent,
        NavRemove() => Colors.redAccent,
        NavReplace() => Colors.amberAccent,
        NavTopChange() => Colors.purpleAccent,
        NavGestureStart() || NavGestureEnd() => Colors.white54,
      };
}
