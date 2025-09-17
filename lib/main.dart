import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import 'ui/home/home_page.dart';
import 'ui/theme/app_theme.dart';
import 'ui/todo/todo_page.dart';
import 'ui/todo/term_todo_page.dart';
import 'ui/todo/task_detail_page.dart';
import 'ui/maps/maps_page.dart';
import 'ui/dreams/dream_detail_page.dart';
import 'ui/triage/triage_page.dart';
import 'providers/task_providers.dart';
import 'providers/db_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/triage_provider.dart';
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
  int _lastKnownTriageCount = 0;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ルーターを先に構築しておき、コンテキストに依存せずに遷移できるようにする
    _router = GoRouter(
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
            GoRoute(
              path: '/maps/dream/:id',
              name: 'dream_detail',
              pageBuilder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                final title = (state.extra is String) ? state.extra as String : '夢';
                return MaterialPage(
                  key: state.pageKey,
                  child: DreamDetailPage(dreamId: id, initialTitle: title),
                );
              },
            ),
          ],
        ),
      ],
    );
    // アプリ起動時（DB初期化直後）に一度だけチェックして開く
    ref.listen<AsyncValue<void>>(isarInitProvider, (prev, next) {
      if (_startupTriageTriggered) return;
      if (next is AsyncData) {
        _startupTriageTriggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final items = ref.read(triageTasksProvider);
          final ws = du.startOfWeek(DateTime.now(), ref.read(settingsProvider).weekStart);
          _lastHandledWeekStart = ws;
          _lastKnownTriageCount = items.length;
          final skipWeek = ref.read(triageSkipWeekProvider);
          final shouldSkip = skipWeek != null && du.isSameDate(skipWeek, ws);
          if (mounted && items.isNotEmpty && !shouldSkip) {
            _triagePushInProgress = true;
            _router.push('/triage').whenComplete(() {
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
        // 週が変わった場合はここではカウントだけ更新
        _lastKnownTriageCount = next.length;
        return;
      }
      final prevLen = (prev?.length ?? 0);
      final nextLen = (next?.length ?? 0);
      final increased = nextLen > prevLen;
      // 既にトリアージ画面、または遷移中なら何もしない
      final skipWeek = ref.read(triageSkipWeekProvider);
      final shouldSkip = skipWeek != null && du.isSameDate(skipWeek, currentWeek);
      if (increased && nextLen > 0 && !_triagePushInProgress && !shouldSkip) {
        final loc = _router.routeInformationProvider.value.location ?? '';
        if (!loc.startsWith('/triage') && mounted) {
          _triagePushInProgress = true;
          _router.push('/triage').whenComplete(() {
            _triagePushInProgress = false;
          });
        }
      }
      // ベースラインとして最後の件数を記録
      _lastKnownTriageCount = nextLen;
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
        final loc = _router.routeInformationProvider.value.location ?? '';
        if (loc.startsWith('/triage')) return;
        final items = ref.read(triageTasksProvider);
        _lastKnownTriageCount = items.length; // 新しい週の基準を更新
        // New week: skip flag naturally does not match this week, so ignore it
        if (items.isNotEmpty && mounted) {
          // 現在の画面の上に仕分けを表示
          _triagePushInProgress = true;
          _router.push('/triage').whenComplete(() {
            _triagePushInProgress = false;
          });
        }
      } else {
        // 同週内のフォアグラウンド復帰時：前回基準より増えていれば表示
        final items = ref.read(triageTasksProvider);
        final nextLen = items.length;
        final increased = nextLen > _lastKnownTriageCount;
        final skipWeek = ref.read(triageSkipWeekProvider);
        final shouldSkip = skipWeek != null && du.isSameDate(skipWeek, weekStartNow);
        if (increased && nextLen > 0 && !_triagePushInProgress && !shouldSkip) {
          final loc = _router.routeInformationProvider.value.location ?? '';
          if (!loc.startsWith('/triage') && mounted) {
            _triagePushInProgress = true;
            _router.push('/triage').whenComplete(() {
              _triagePushInProgress = false;
            });
          }
        }
        // 復帰時点の件数を基準として更新
        _lastKnownTriageCount = nextLen;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vision TODO',
      theme: buildLightTheme(),
      builder: (context, child) {
        // Dismiss keyboard when tapping outside of inputs anywhere in the app
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
              currentFocus.unfocus();
            }
          },
          child: child,
        );
      },
      routerConfig: _router,
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
