import 'package:flutter/material.dart';
import 'package:router_observer/router_observer.dart';

/// A sink that keeps the most recent events in memory so the example can show
/// them on screen, while also printing them via the default print behavior.
class InMemorySink implements NavEventSink {
  InMemorySink(this.notifier);

  /// Receives the running list of event descriptions for display.
  final ValueNotifier<List<String>> notifier;

  @override
  void add(NavEvent event) {
    final line = '${event.type.name}: ${event.routeName}';
    notifier.value = [line, ...notifier.value].take(20).toList();
  }

  @override
  Future<void> close() async {}
}

void main() {
  final events = ValueNotifier<List<String>>(<String>[]);

  runApp(
    MaterialApp(
      title: 'router_observer example',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        NavTelemetryObserver(
          config: const NavObserverConfig(navigatorLabel: 'root'),
          sink: CompositeSink([
            InMemorySink(events),
            PrintSink(),
          ]),
        ),
      ],
      home: HomePage(events: events),
    ),
  );
}

/// Home page that pushes a details route and shows recent telemetry.
class HomePage extends StatelessWidget {
  /// Creates the home page bound to the [events] feed.
  const HomePage({required this.events, super.key});

  /// The shared, most-recent navigation events for display.
  final ValueNotifier<List<String>> events;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('router_observer')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'details'),
                  builder: (_) => const DetailsPage(),
                ),
              ),
              child: const Text('Open details'),
            ),
          ),
          const Divider(),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: events,
              builder: (context, lines, _) => ListView(
                children: [
                  for (final line in lines)
                    ListTile(dense: true, title: Text(line)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple details page to generate push/pop events.
class DetailsPage extends StatelessWidget {
  /// Creates the details page.
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Go back'),
        ),
      ),
    );
  }
}
