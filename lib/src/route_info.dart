import 'package:flutter/material.dart';

import 'package:router_observer/src/name_resolver.dart';

/// An immutable snapshot of a [Route] at the moment an event was emitted.
///
/// Captured by `RouterObserver`; construct directly only in tests.
@immutable
class RouteInfo {
  /// Creates a route snapshot.
  const RouteInfo({
    required this.name,
    required this.type,
    required this.id,
    this.arguments,
    this.isFirst = false,
    this.isPopup = false,
    this.isModal = false,
    this.pageKey,
  });

  /// Captures a snapshot of [route].
  ///
  /// [nameResolver] resolves the display name (see [defaultNameResolver]).
  /// [arguments] should already be redacted by the caller; pass `null` when
  /// argument capture is disabled.
  factory RouteInfo.capture(
    Route<dynamic> route, {
    RouteNameResolver nameResolver = defaultNameResolver,
    Object? arguments,
  }) {
    final RouteSettings settings = route.settings;
    String? pageKey;
    if (settings is Page) {
      final LocalKey? key = (settings as Page<Object?>).key;
      if (key != null) {
        pageKey = key is ValueKey<String> ? key.value : key.toString();
      }
    }
    return RouteInfo(
      name: nameResolver(route),
      type: route.runtimeType.toString(),
      id: identityHashCode(route),
      arguments: arguments,
      isFirst: route.isFirst,
      isPopup: route is PopupRoute,
      isModal: route is ModalRoute,
      pageKey: pageKey,
    );
  }

  /// The resolved, human-readable route name.
  final String name;

  /// The route's runtime type as a string, e.g. `MaterialPageRoute<dynamic>`.
  final String type;

  /// An identity-based id, stable for the lifetime of the route instance.
  final int id;

  /// Redacted route arguments, or `null` when capture is disabled or the
  /// route has no arguments.
  final Object? arguments;

  /// Whether this route was the first route in its navigator.
  final bool isFirst;

  /// Whether this route is a [PopupRoute] (dialog, menu, bottom sheet).
  final bool isPopup;

  /// Whether this route is a [ModalRoute].
  final bool isModal;

  /// A readable rendering of the [Page.key], when the route is page-based.
  final String? pageKey;

  /// Serializes this snapshot into a JSON-encodable map.
  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'type': type,
        'id': id,
        if (arguments != null) 'arguments': arguments,
        'isFirst': isFirst,
        'isPopup': isPopup,
        if (pageKey != null) 'pageKey': pageKey,
      };

  @override
  String toString() => 'RouteInfo($name, type: $type)';
}
