import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ui/home/home_page.dart';
import 'ui/todo/todo_page.dart';
import 'ui/todo/term_todo_page.dart';
import 'ui/todo/task_detail_page.dart';
import 'ui/maps/maps_page.dart';
import 'ui/triage/triage_page.dart';
import 'providers/task_providers.dart';
import 'providers/db_provider.dart';
import 'providers/settings_provider.dart';
import 'utils/date_utils.dart' as du;
import 'models/task.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  bool _startupTriageTriggered = false;
  DateTime? _lastHandledWeekStart;
  bool _triagePushInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // アプリ起動時（DB初期化直後）に一度だけチェックして開く
    ref.listen<AsyncValue<void>>(isarInitProvider, (prev, next) {
      if (_startupTriageTriggered) return;
      if (next is AsyncData) {
        _startupTriageTriggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final items = ref.read(triageTasksProvider);
          final ws = du.startOfWeek(DateTime.now(), ref.read(settingsProvider).weekStart);
          _lastHandledWeekStart = ws;
          if (mounted && items.isNotEmpty) {
            _triagePushInProgress = true;
            context.push('/triage').whenComplete(() {
              _triagePushInProgress = false;
            });
          }
        });
      }
    });

    // 同週内で未仕分けが増えたら自動で開く（オプション）
    ref.listen<List<Task>>(triageTasksProvider, (prev, next) {
      if (!_startupTriageTriggered) return; // 起動直後の初期化が完了してから
      final settings = ref.read(settingsProvider);
      final currentWeek = du.startOfWeek(DateTime.now(), settings.weekStart);
      // 同週のみ対象
      if (_lastHandledWeekStart == null || !du.isSameDate(_lastHandledWeekStart!, currentWeek)) {
        return;
      }
      final prevLen = (prev?.length ?? 0);
      final nextLen = (next?.length ?? 0);
      final increased = nextLen > prevLen;
      if (!increased || nextLen == 0) return;
      // 既にトリアージ画面、または遷移中なら何もしない
      if (_triagePushInProgress) return;
      final loc = GoRouterState.of(context).uri.toString();
      if (loc.startsWith('/triage')) return;
      if (mounted) {
        _triagePushInProgress = true;
        context.push('/triage').whenComplete(() {
          _triagePushInProgress = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // フォアグラウンド復帰時に週替わりを検知
      final weekStartNow = du.startOfWeek(DateTime.now(), ref.read(settingsProvider).weekStart);
      final hasChanged = _lastHandledWeekStart == null || !du.isSameDate(_lastHandledWeekStart!, weekStartNow);
      if (hasChanged) {
        _lastHandledWeekStart = weekStartNow; // 同週での重複表示を防止
        // 既に仕分け画面なら何もしない
        final loc = GoRouterState.of(context).uri.toString();
        if (loc.startsWith('/triage')) return;
        final items = ref.read(triageTasksProvider);
        if (items.isNotEmpty && mounted) {
          // 現在の画面の上に仕分けを表示
          _triagePushInProgress = true;
          context.push('/triage').whenComplete(() {
            _triagePushInProgress = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/triage',
          name: 'triage',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: TriagePage(),
          ),
        ),
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
              path: '/todo/term/:id',
              name: 'term_detail',
              pageBuilder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                final title = (state.extra is String) ? state.extra as String : 'Term';
                return MaterialPage(
                  key: state.pageKey,
                  child: TermTodoPage(termId: id, termTitle: title),
                );
              },
            ),
            GoRoute(
              path: '/todo/task/:id',
              name: 'task_detail',
              pageBuilder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                final title = (state.extra is String) ? state.extra as String : 'TODO';
                return MaterialPage(
                  key: state.pageKey,
                  child: TaskDetailPage(taskId: id, initialTitle: title),
                );
              },
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
