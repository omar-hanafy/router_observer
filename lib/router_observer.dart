/// A complete navigation observability toolkit for Flutter.
///
/// Attach a [RouterObserver] to any navigator (`MaterialApp`,
/// `CupertinoApp`, `go_router`, nested navigators) and receive structured
/// [NavEvent]s through composable [NavListener]s: console logging,
/// crash-report breadcrumbs, analytics screen tracking, and an in-app
/// debug overlay.
///
/// ## Quick start
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:router_observer/router_observer.dart';
///
/// void main() {
///   runApp(
///     MaterialApp(
///       navigatorObservers: [
///         RouterObserver(listeners: [ConsoleNavLogger()]),
///       ],
///       home: const HomePage(),
///     ),
///   );
/// }
/// ```
library;

export 'src/events.dart';
export 'src/listeners/breadcrumbs.dart';
export 'src/listeners/console_logger.dart';
export 'src/listeners/listener.dart';
export 'src/listeners/screen_tracker.dart';
export 'src/name_resolver.dart';
export 'src/observer.dart';
export 'src/overlay/debug_overlay.dart';
export 'src/redaction.dart';
export 'src/route_info.dart';
export 'src/settings.dart';
