import 'package:flutter/material.dart';

/// Resolves a human-readable name for a [Route].
///
/// Used by `RouterObserver` to label every event with a meaningful route
/// name, even for anonymous routes, [Page]-based routes, dialogs, and
/// bottom sheets. See [defaultNameResolver] for the default strategy.
typedef RouteNameResolver = String Function(Route<dynamic> route);

/// The default [RouteNameResolver].
///
/// Resolution order:
///
/// 1. [RouteSettings.name], when non-null and non-empty.
/// 2. For [Page]-based routes: [Page.name], then a readable rendering of
///    [Page.key].
/// 3. Friendly fallbacks by route type: `[dialog]` for [DialogRoute] and
///    [RawDialogRoute], `[bottom-sheet]` for [ModalBottomSheetRoute],
///    `[popup]` for any other [PopupRoute].
/// 4. The route's runtime type wrapped in brackets, e.g.
///    `[MaterialPageRoute<dynamic>]`.
///
/// Never returns an empty string and never throws.
String defaultNameResolver(Route<dynamic> route) {
  final RouteSettings settings = route.settings;

  final String? name = settings.name;
  if (name != null && name.isNotEmpty) return name;

  if (settings is Page) {
    final Page<Object?> page = settings as Page<Object?>;
    final String? pageName = page.name;
    if (pageName != null && pageName.isNotEmpty) return pageName;
    final LocalKey? key = page.key;
    if (key != null) {
      if (key is ValueKey<String>) return key.value;
      return '[page:$key]';
    }
  }

  if (route is DialogRoute || route is RawDialogRoute) return '[dialog]';
  if (route is ModalBottomSheetRoute) return '[bottom-sheet]';
  if (route is PopupRoute) return '[popup]';

  return '[${route.runtimeType}]';
}
