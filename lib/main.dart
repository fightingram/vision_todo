import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ui/home/home_page.dart';
import 'ui/todo/todo_page.dart';
import 'ui/maps/maps_page.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => _ScaffoldWithNav(child: child),
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomePage(),
              ),
            ),
            GoRoute(
              path: '/todo',
              name: 'todo',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: TodoPage(),
              ),
            ),
            GoRoute(
              path: '/maps',
              name: 'maps',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: MapsPage(),
              ),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Vision TODO',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class _ScaffoldWithNav extends StatelessWidget {
  const _ScaffoldWithNav({required this.child});
  final Widget child;

  int _locationToIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/maps')) return 2;
    if (loc.startsWith('/todo')) return 1;
    return 0;
  }

  void _onTap(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/todo');
        break;
      case 2:
        context.go('/maps');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _locationToIndex(context);
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), label: 'TODO'),
          NavigationDestination(icon: Icon(Icons.account_tree_outlined), label: 'Maps'),
        ],
      ),
    );
  }
}
