import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:router_observer/src/events.dart';
import 'package:router_observer/src/listeners/listener.dart';

/// Builds the log line for an event; return `null` to skip the event.
typedef NavLogFormatter = String? Function(NavEvent event);

/// A [NavListener] that prints readable one-line logs for every event.
///
/// Default output:
///
/// ```text
/// [root] -> push      /details (from /home) depth=2
/// [root] <- pop       /details (to /home) depth=1
/// ```
///
/// Options control colors, stack rendering, argument display, JSON output,
/// and the print function itself. Provide [formatter] to take over line
/// building entirely.
class ConsoleNavLogger implements NavListener {
  /// Creates a console logger.
  ConsoleNavLogger({
    this.useColors = false,
    this.showStack = false,
    this.showArguments = false,
    this.json = false,
    this.formatter,
    void Function(String line)? printer,
  }) : _printer = printer ?? debugPrint;

  /// Whether to wrap output in ANSI color codes.
  ///
  /// Off by default because not every console renders ANSI escapes.
  final bool useColors;

  /// Whether to append the current stack snapshot to each line.
  final bool showStack;

  /// Whether to append captured route arguments to each line.
  ///
  /// Arguments only appear when the observer's `captureArguments` setting
  /// is enabled.
  final bool showArguments;

  /// When `true`, prints each event as single-line JSON instead of the
  /// human-readable format.
  final bool json;

  /// Overrides line building entirely; return `null` to skip an event.
  final NavLogFormatter? formatter;

  final void Function(String line) _printer;

  @override
  void onNavEvent(NavEvent event) {
    final NavLogFormatter? custom = formatter;
    if (custom != null) {
      final String? line = custom(event);
      if (line != null) _printer(line);
      return;
    }
    if (json) {
      _printer(jsonEncode(event.toJson()));
      return;
    }
    _printer(_format(event));
  }

  String _format(NavEvent event) {
    final String glyph = switch (event) {
      NavPush() => '->',
      NavPop() => '<-',
      NavRemove() => 'x-',
      NavReplace() => '<>',
      NavTopChange() => '^^',
      NavGestureStart() => '~>',
      NavGestureEnd() => '~|',
    };

    final String relation = switch (event) {
      NavPop() when event.previousRoute != null =>
        ' (to ${event.previousRoute!.name})',
      NavReplace() when event.oldRoute != null =>
        ' (was ${event.oldRoute!.name})',
      _ when event.previousRoute != null =>
        ' (from ${event.previousRoute!.name})',
      _ => '',
    };

    final StringBuffer buffer = StringBuffer()
      ..write('[${event.navigatorLabel}] ')
      ..write('$glyph ${event.typeName.padRight(12)} ')
      ..write(event.route.name)
      ..write(relation)
      ..write(' depth=${event.stackDepth}');

    if (showArguments && event.route.arguments != null) {
      buffer.write(' args=${event.route.arguments}');
    }
    if (showStack && event.stackSnapshot.isNotEmpty) {
      buffer.write(' stack=[${event.stackSnapshot.join(' / ')}]');
    }

    final String line = buffer.toString();
    if (!useColors) return line;
    final String color = switch (event) {
      NavPush() => '\x1B[32m', // green
      NavPop() => '\x1B[36m', // cyan
      NavRemove() => '\x1B[31m', // red
      NavReplace() => '\x1B[33m', // yellow
      NavTopChange() => '\x1B[35m', // magenta
      NavGestureStart() || NavGestureEnd() => '\x1B[90m', // gray
    };
    return '$color$line\x1B[0m';
  }

  @override
  void close() {}
}
