// Demonstrates every router_observer feature: console logging, breadcrumbs,
// screen tracking, nested navigators with shared listeners, popup routes,
// and the in-app debug overlay.
//
// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:router_observer/router_observer.dart';

// Shared listeners: one instance covers every navigator; events carry the
// navigator label.
final breadcrumbs = NavBreadcrumbs(capacity: 50);
final consoleLogger = ConsoleNavLogger(showStack: true, showArguments: true);
final screenTracker = ScreenTracker(
  onScreenView: (view) => debugPrint(
    'SCREEN VIEW: ${view.name} on ${view.navigatorLabel}'
    '${view.timeOnPreviousScreen != null ? ' (previous screen shown for ${view.timeOnPreviousScreen!.inSeconds}s)' : ''}',
  ),
);

// One observer per navigator.
final rootObserver = RouterObserver(
  listeners: [consoleLogger, breadcrumbs, screenTracker],
  settings: const RouterObserverSettings(captureArguments: true),
);
final tabObserver = RouterObserver(
  navigatorLabel: 'tab:explore',
  listeners: [consoleLogger, breadcrumbs, screenTracker],
);

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'router_observer demo',
      navigatorObservers: [rootObserver],
      builder: (context, child) => NavDebugOverlay(
        observers: [rootObserver, tabObserver],
        child: child!,
      ),
      routes: {
        '/': (_) => const HomePage(),
        '/details': (_) => const DetailsPage(),
        '/tabs': (_) => const TabsPage(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('router_observer demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: () => Navigator.pushNamed(
              context,
              '/details',
              arguments: {'productId': 42, 'token': 'super-secret'},
            ),
            child: const Text('Push named route (with redacted args)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AnonymousPage()),
            ),
            child: const Text('Push anonymous route'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/tabs'),
            child: const Text('Open nested tab navigator'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('A dialog'),
                content: Text('Logged as [dialog] by the name resolver.'),
              ),
            ),
            child: const Text('Show dialog'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => const SizedBox(
                height: 160,
                child: Center(child: Text('Logged as [bottom-sheet]')),
              ),
            ),
            child: const Text('Show bottom sheet'),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Breadcrumb trail'),
                content: SingleChildScrollView(
                  child: Text(
                    breadcrumbs.describe(),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
            child: const Text('Dump breadcrumbs (crash-report style)'),
          ),
        ],
      ),
    );
  }
}

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/tabs'),
          child: const Text('Replace with tabs page'),
        ),
      ),
    );
  }
}

class AnonymousPage extends StatelessWidget {
  const AnonymousPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anonymous route')),
      body: const Center(
        child: Text('This route has no name; the resolver labels it by type.'),
      ),
    );
  }
}

class TabsPage extends StatelessWidget {
  const TabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nested navigator')),
      body: Navigator(
        observers: [tabObserver],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings.name == '/' || settings.name == null
              ? const RouteSettings(name: 'tab-root')
              : settings,
          builder: (_) => const TabRootPage(),
        ),
      ),
    );
  }
}

class TabRootPage extends StatelessWidget {
  const TabRootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'tab-detail'),
            builder: (_) => const Scaffold(
              body: Center(child: Text('Tab detail')),
            ),
          ),
        ),
        child: const Text('Push inside nested navigator'),
      ),
    );
  }
}
