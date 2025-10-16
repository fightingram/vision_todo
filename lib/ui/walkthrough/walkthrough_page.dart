import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../providers/prefs_provider.dart';

import '../theme/design_tokens.dart';

class WalkthroughPage extends ConsumerStatefulWidget {
  const WalkthroughPage({super.key});

  @override
  ConsumerState<WalkthroughPage> createState() => _WalkthroughPageState();
}

class _WalkthroughPageState extends ConsumerState<WalkthroughPage> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    // Mark walkthrough as seen on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final prefs = ref.read(prefsServiceProvider);
        // Fire and forget
        prefs.setWalkthroughSeen(true);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < 4) {
      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _prev() {
    if (_index > 0) {
      _controller.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Dream TODO ウォークスルー'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.only(top: DT.spaceM, bottom: DT.spaceM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: active ? 22 : 8,
                    decoration: BoxDecoration(
                      color: active ? DT.brandPrimary : DT.borderStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: const [
                  _StepOne(),
                  _StepTwo(),
                  _StepThree(),
                  _StepFour(),
                  _StepFive(),
                ],
              ),
            ),
            // Nav controls (except on last page which has its own CTAs)
            if (_index < 4)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _index == 0 ? null : _prev,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('戻る'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _next,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('次へ'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// STEP 1: 考えを整える
class _StepOne extends StatelessWidget {
  const _StepOne();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🌿 STEP 1：考えを整える', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('頭の中、ぐちゃぐちゃじゃない？', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('“やること”が増えるほど、頭が重くなる。\nDream TODO は、まず思考を整理するところから始めます。'),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: const _ChaosTasks(),
              ),
            ),
          ),
          // Intention text removed per request
        ],
      ),
    );
  }
}

class _ChaosTasks extends StatefulWidget {
  const _ChaosTasks();

  @override
  State<_ChaosTasks> createState() => _ChaosTasksState();
}

class _ChaosTasksState extends State<_ChaosTasks> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _anim;
  late final List<_ChaosItem> _items;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
    final seeds = [
      ('コーヒー買う', 0xfffca5a5, 0xff7f1d1d),
      ('資料提出', 0xfffdba74, 0xff9a3412),
      ('母に電話', 0xfffcd34d, 0xff78350f),
      ('会議参加', 0xfff9a8d4, 0xff831843),
      ('プレゼン対策', 0xffd8b4fe, 0xff581c87),
      ('洗濯', 0xff93c5fd, 0xff1e3a8a),
      ('メール確認', 0xfffca5a5, 0xff7f1d1d),
      ('書類作成', 0xffc7d2fe, 0xff312e81),
      ('打ち合わせ準備', 0xff86efac, 0xff166534),
      ('食器洗う', 0xffa5f3fc, 0xff164e63),
      ('レポート提出', 0xffbef264, 0xff365314),
      ('床掃除', 0xfff0abfc, 0xff6b21a8),
      ('営業報告', 0xfffb7185, 0xff831843),
      ('病院予約', 0xfffbbf24, 0xff78350f),
      ('デザイン修正', 0xff2dd4bf, 0xff134e4a),
      ('クライアント連絡', 0xffc4b5fd, 0xff5b21b6),
      ('買い物リスト', 0xfffed7aa, 0xff9a3412),
      ('スライド作成', 0xff7dd3fc, 0xff0c4a6e),
      ('忙しい...', 0xfffbcfe8, 0xff831843),
      ('何から始める?', 0xfffecaca, 0xff7f1d1d),
      ('頭が回らない', 0xfffef08a, 0xff78350f),
      ('優先度？', 0xffbfdbfe, 0xff1e3a8a),
      ('全部大事', 0xffbbf7d0, 0xff166534),
    ];
    final rnd = math.Random(42);
    _items = List.generate(seeds.length, (i) {
      final s = seeds[i];
      final baseX = rnd.nextDouble() * 0.75 + 0.05; // 5%..80%
      final baseY = rnd.nextDouble() * 0.75 + 0.05; // 5%..80%
      final ampX = (rnd.nextDouble() * 24 + 8) * (rnd.nextBool() ? 1 : -1);
      final ampY = (rnd.nextDouble() * 24 + 8) * (rnd.nextBool() ? 1 : -1);
      final phase = rnd.nextDouble() * math.pi * 2;
      return _ChaosItem(
        label: s.$1,
        color: Color(s.$2),
        text: Color(s.$3),
        baseX: baseX,
        baseY: baseY,
        ampX: ampX,
        ampY: ampY,
        phase: phase,
      );
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.radiusL)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(builder: (context, bc) {
            final w = bc.maxWidth;
            final h = bc.maxHeight;
            return AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                return Stack(
                  children: [
                    for (final it in _items)
                      Positioned(
                        left: (it.baseX * w + it.ampX * math.sin(_anim.value * 2 * math.pi + it.phase)).clamp(0.0, w - 120),
                        top: (it.baseY * h + it.ampY * math.cos(_anim.value * 2 * math.pi + it.phase)).clamp(0.0, h - 32),
                        child: _chaosPill(it),
                      ),
                  ],
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _chaosPill(_ChaosItem it) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: it.color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(it.label, style: TextStyle(color: it.text, fontWeight: FontWeight.w600)),
    );
  }
}

class _ChaosItem {
  _ChaosItem({
    required this.label,
    required this.color,
    required this.text,
    required this.baseX,
    required this.baseY,
    required this.ampX,
    required this.ampY,
    required this.phase,
  });
  final String label;
  final Color color;
  final Color text;
  final double baseX;
  final double baseY;
  final double ampX;
  final double ampY;
  final double phase;
}

// STEP 2: 構造理解
class _StepTwo extends StatelessWidget {
  const _StepTwo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🧠 STEP 2：なぜやるかから考える', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('“なぜやるか”から整理する。', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('夢 → 目標 → TODO。行動の前に、“目的の構造”を見える化します。'),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _NodeDiagram(),
              ),
            ),
          ),
          // Intention text removed per request
        ],
      ),
    );
  }
}

class _NodeDiagram extends StatefulWidget {
  @override
  State<_NodeDiagram> createState() => _NodeDiagramState();
}

class _NodeDiagramState extends State<_NodeDiagram> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.radiusL)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, bc) {
              final w = bc.maxWidth;
              final h = bc.maxHeight;
              // Nodes
              final dream = _MMNode(label: '夢', icon: Icons.lightbulb_outline, pos: Offset(w * 0.18, h * 0.5));
              final goal1 = _MMNode(label: '目標A', icon: Icons.emoji_flags_outlined, pos: Offset(w * 0.46, h * 0.32));
              final goal2 = _MMNode(label: '目標B', icon: Icons.emoji_flags_outlined, pos: Offset(w * 0.46, h * 0.68));
              // TODO は目標ごとに一列（同一X）に配置し、等間隔で構造的に並べる
              final todoX1 = w * 0.76;
              final todoY1 = [h * 0.18, h * 0.30, h * 0.42];
              final todos1 = <_MMNode>[
                for (final yy in todoY1)
                  _MMNode(label: 'TODO', icon: Icons.check_circle_outline, pos: Offset(todoX1, yy)),
              ];
              final todoX2 = w * 0.76;
              final todoY2 = [h * 0.58, h * 0.70, h * 0.82];
              final todos2 = <_MMNode>[
                for (final yy in todoY2)
                  _MMNode(label: 'TODO', icon: Icons.check_circle_outline, pos: Offset(todoX2, yy)),
              ];
              final nodes = <_MMNode>[dream, goal1, goal2, ...todos1, ...todos2];
              final edges = <(_MMNode, _MMNode)>[
                (dream, goal1),
                (dream, goal2),
                for (final t in todos1) (goal1, t),
                for (final t in todos2) (goal2, t),
              ];
              return AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => Stack(
                  children: [
                    // Edges
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MindMapEdgesPainter(edges: edges, t: _anim.value),
                      ),
                    ),
                    // Nodes
                    ...nodes.map((n) => Positioned(
                          left: n.pos.dx - 44,
                          top: n.pos.dy - 20,
                          child: _MindMapNode(label: n.label, icon: n.icon),
                        )),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MMNode {
  _MMNode({required this.label, required this.icon, required this.pos});
  final String label;
  final IconData icon;
  final Offset pos;
}

class _MindMapEdgesPainter extends CustomPainter {
  _MindMapEdgesPainter({required this.edges, required this.t});
  final List<(_MMNode, _MMNode)> edges;
  final double t; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = DT.borderStrong
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final accent = Paint()
      ..color = DT.brandPrimary.withOpacity(0.25 + 0.35 * (0.5 + 0.5 * math.sin(t * 2 * math.pi)))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final e in edges) {
      final a = e.$1.pos;
      final b = e.$2.pos;
      final path = Path();
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.moveTo(a.dx, a.dy);
      path.quadraticBezierTo(mid.dx, (a.dy + b.dy) / 2, b.dx, b.dy);
      canvas.drawPath(path, base);
      canvas.drawPath(path, accent);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapEdgesPainter old) => old.t != t || old.edges != edges;
}

class _MindMapNode extends StatelessWidget {
  const _MindMapNode({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DT.bgSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
        border: Border.all(color: DT.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: DT.textSecondary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

// STEP 3: “やらない”を選ぶ
class _StepThree extends StatelessWidget {
  const _StepThree();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🧩 STEP 3：“やらない”を選ぶ', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('やらないことを決めると、頭が軽くなる。', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('毎週のトリアージで、“今週やらない”を選ぶだけ。やることを減らすと、自然に集中できる。'),
          const SizedBox(height: 16),
          const Expanded(child: _SwipeGuide()),
          // Intention text removed per request
        ],
      ),
    );
  }
}

class _SwipeGuide extends StatefulWidget {
  const _SwipeGuide();

  @override
  State<_SwipeGuide> createState() => _SwipeGuideState();
}

class _SwipeGuideState extends State<_SwipeGuide> {
  int _idx = 0;
  final tasks = ['リサーチの整理', '設計レビュー', '資料作成', '買い出し'];

  void _onDismissed(DismissDirection dir) {
    setState(() {
      _idx = (_idx + 1) % tasks.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = tasks[_idx];
    return LayoutBuilder(builder: (context, bc) {
      final narrow = bc.maxWidth < 700;
      return Column(
        children: [
          // Clear guidance cards
          if (narrow)
            Column(
              children: const [
                _SwipeInfoCard(directionLeft: true),
                SizedBox(height: 12),
                _SwipeInfoCard(directionLeft: false),
              ],
            )
          else
            Row(
              children: const [
                Expanded(child: _SwipeInfoCard(directionLeft: true)),
                SizedBox(width: 12),
                Expanded(child: _SwipeInfoCard(directionLeft: false)),
              ],
            ),
          const SizedBox(height: 16),
          Text('カードを左右にスワイプして体験できます',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DT.textSecondary)),
          const SizedBox(height: 8),
          // Interactive demo with strong backgrounds
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Dismissible(
                key: ValueKey(t),
                direction: DismissDirection.horizontal,
                onDismissed: _onDismissed,
                background: _swipeBg(true),
                secondaryBackground: _swipeBg(false),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.radiusL)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        const Icon(Icons.task_alt, color: DT.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(t, style: Theme.of(context).textTheme.titleMedium)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _swipeBg(bool startToEnd) {
    final color = startToEnd ? DT.stateSuccess : DT.stateDanger;
    final icon = startToEnd ? Icons.check_circle : Icons.cancel;
    final label = startToEnd ? '今週やる' : 'やらない';
    return Align(
      alignment: startToEnd ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        heightFactor: 0.85,
        widthFactor: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(DT.radiusL),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          alignment: startToEnd ? Alignment.centerLeft : Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment:
                startToEnd ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (startToEnd) Icon(icon, size: 26, color: color),
              if (startToEnd) const SizedBox(width: 8),
              Text(label),
              if (!startToEnd) const SizedBox(width: 8),
              if (!startToEnd) Icon(icon, size: 26, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeInfoCard extends StatelessWidget {
  const _SwipeInfoCard({required this.directionLeft});
  final bool directionLeft;

  @override
  Widget build(BuildContext context) {
    final isLeft = directionLeft;
    final color = isLeft ? DT.stateDanger : DT.stateSuccess;
    final title = isLeft ? '左にスワイプ: やらない' : '右にスワイプ: 今週やる';
    final icon = isLeft ? Icons.swipe_left : Icons.swipe_right;
    final arrow = isLeft ? Icons.arrow_back : Icons.arrow_forward;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    isLeft ? '今週はやらない項目を左へ' : '今週やる項目を右へ',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: DT.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(arrow, color: color),
          ],
        ),
      ),
    );
  }
}

// STEP 4: 週ごとにリセット
class _StepFour extends StatelessWidget {
  const _StepFour();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📅 STEP 4：週ごとにリセット', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('完璧じゃなく、週ごとに整える。', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('毎週リセットできるから、完璧を目指さなくていい。“いまの自分”に合わせて、考えと行動を整えよう。'),
          const SizedBox(height: 16),
          const Expanded(child: _WeeklyReset()),
          // Intention text removed per request
        ],
      ),
    );
  }
}

class _WeeklyReset extends StatefulWidget {
  const _WeeklyReset();
  @override
  State<_WeeklyReset> createState() => _WeeklyResetState();
}

class _WeeklyResetState extends State<_WeeklyReset> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.radiusL)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month, size: 56, color: DT.brandPrimary),
                  const SizedBox(height: 12),
                  Text('また新しい週が始まる', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: (0.2 + 0.6 * _anim.value).clamp(0.0, 1.0),
                      backgroundColor: DT.borderSubtle,
                      color: DT.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// STEP 5: はじめよう（CTA）
class _StepFive extends StatelessWidget {
  const _StepFive();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🌈 STEP 5：はじめよう', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('思考を整理して、行動を軽くする。', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('今週の“やること”を選んでみよう。ほんの数分で、頭の中がスッキリします。'),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    // Go Home first to register dreams/goals
                    context.go('/home');
                  },
                  child: const Text('はじめる（Homeへ）'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Optionally jump to triage
                    context.push('/triage');
                  },
                  child: const Text('トリアージへ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

Widget _pill(String label, {required Color color, required Color border}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
    ),
    child: Text(label),
  );
}
