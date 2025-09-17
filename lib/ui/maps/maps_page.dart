import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/dream.dart';
// Unified Term model for rendering
import '../../models/task.dart';
import '../../providers/db_provider.dart';
import '../../providers/term_providers.dart';
import '../../providers/task_providers.dart';
import '../terms/terms_page.dart' show TermDetailSheet; // reuse sheet
import '../todo/term_todo_page.dart';
import '../terms/tags_page.dart';
import '../../models/tag.dart';
import '../../repositories/term_repositories.dart';
import '../widgets/add_item_flow.dart';

class MapsPage extends ConsumerWidget {
  const MapsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(isarInitProvider);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Maps'),
        actions: [
          IconButton(
            tooltip: 'タグ管理',
            icon: const Icon(Icons.label_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagsPage()),
              );
            },
          ),
          IconButton(
            onPressed: () async {
              // Unified add flow shared with Home
              // ignore: use_build_context_synchronously
              await AddItemFlow.show(context, ref);
            },
            icon: const Icon(Icons.add),
            tooltip: '追加',
          ),
        ],
      ),
      body: init.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('DB初期化エラー: $e')),
        data: (_) => const _MapCanvas(),
      ),
    );
  }
}

class _MapCanvas extends ConsumerStatefulWidget {
  const _MapCanvas();

  @override
  ConsumerState<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends ConsumerState<_MapCanvas> {
  final TransformationController _tc = TransformationController();
  int _layoutHash = 0;
  static const double _minScale = 0.3;
  static const double _maxScale = 2.5;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dreams = ref.watch(dreamsProvider).value ?? const <Dream>[];
    final topTerms = ref.watch(allTopTermsProvider).value ?? const <Term>[];
    final childTerms = ref.watch(allChildTermsProvider).value ?? const <Term>[];
    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];

    // Build hierarchy
    final nodes = <_Node>[];
    for (final d in dreams) {
      nodes.add(_Node.level0(d));
      final parents = topTerms.where((g) => g.dreamId == d.id).toList();
      for (final p in parents) {
        nodes.add(_Node.level1Term(p, parentId: d.id));
        final children = childTerms.where((c) => c.parentId == p.id).toList();
        for (final c in children) {
          nodes.add(_Node.level2Term(c, parentId: p.id));
        }
        // Append tasks under each parent term as level 3 nodes
        final childrenT = tasks.where((t) => t.shortTermId == p.id).toList();
        for (final t in childrenT) {
          nodes.add(_Node.level3(t, parentId: p.id));
        }
      }
    }

    // Layout constants
    const nodeW = 160.0;
    const nodeH = 150.0;
    const hGap = 60.0;
    const vGap = 140.0;
    const taskH = 80.0; // compact height for task cards
    const taskHGap = 12.0; // horizontal gap between task cards
    const pad = 60.0;

    // Determine positions
    final dreamIds = dreams.map((e) => e.id).toList();
    final positions = <String, Offset>{};
    // First pass positions (may include negative values)
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    // Pre-calc canvas height from rows
    double totalHeight = pad * 2 +
        nodeH * 3 +
        vGap * 2 +
        taskH +
        vGap; // leave space for tasks row

    for (var i = 0; i < dreamIds.length; i++) {
      final dx = pad + i * (nodeW + 240);
      positions['dream:${dreamIds[i]}'] = Offset(dx, pad);
      minX = math.min(minX, dx);
      minY = math.min(minY, pad);
      maxX = math.max(maxX, dx + nodeW);
      maxY = math.max(maxY, pad + nodeH);
      final lp = topTerms.where((g) => g.dreamId == dreamIds[i]).toList();
      if (lp.isEmpty) continue;
      final baseX = dx - ((lp.length - 1) / 2) * (nodeW + hGap);
      for (var j = 0; j < lp.length; j++) {
        final lx = baseX + j * (nodeW + hGap);
        final ly = pad + nodeH + vGap;
        positions['term:${lp[j].id}'] = Offset(lx, ly);
        minX = math.min(minX, lx);
        minY = math.min(minY, ly);
        maxX = math.max(maxX, lx + nodeW);
        maxY = math.max(maxY, ly + nodeH);
        final sp = childTerms.where((s) => s.parentId == lp[j].id).toList();
        if (sp.isEmpty) continue;
        final sBaseX = lx - ((sp.length - 1) / 2) * (nodeW + hGap / 2);
        for (var k = 0; k < sp.length; k++) {
          final sx = sBaseX + k * (nodeW + hGap / 2);
          final sy = pad + (nodeH + vGap) * 2;
          positions['term:${sp[k].id}'] = Offset(sx, sy);
          minX = math.min(minX, sx);
          minY = math.min(minY, sy);
          maxX = math.max(maxX, sx + nodeW);
          maxY = math.max(maxY, sy + nodeH);
        }
      }
    }

    // Append tasks as a separate row under all shorts.
    // First, build clusters per Term and lay them out left-to-right without overlap.
    final longPositions = <int, Offset>{
      for (final e in positions.entries)
        if (e.key.startsWith('term:')) int.parse(e.key.split(':')[1]): e.value
    };
    // Collect clusters (centered at long center)
    final clusters = <_TaskCluster>[];
    for (final g in topTerms) {
      final lp = longPositions[g.id];
      if (lp == null) continue;
      final ts = tasks.where((t) => t.shortTermId == g.id).toList();
      if (ts.isEmpty) continue;
      clusters.add(_TaskCluster(
        longId: g.id,
        centerX: lp.dx + nodeW / 2,
        tasks: ts,
      ));
    }

    // Sort clusters by centerX
    clusters.sort((a, b) => a.centerX.compareTo(b.centerX));
    double lastRight = -double.infinity;
    const minClusterGap = 24.0; // minimum gap between clusters
    final taskRowY =
        pad + (nodeH + vGap) * 2 + nodeH + vGap; // below shorts with extra gap
    for (final c in clusters) {
      final width = c.tasks.length * (nodeW + taskHGap) - taskHGap;
      double left = c.centerX - width / 2;
      if (left < lastRight + minClusterGap) {
        left = lastRight + minClusterGap;
      }
      // Place each task in the cluster
      for (var i = 0; i < c.tasks.length; i++) {
        final tx = left + i * (nodeW + taskHGap);
        final key = 'task:${c.tasks[i].id}';
        positions[key] = Offset(tx, taskRowY);
        minX = math.min(minX, tx);
        minY = math.min(minY, taskRowY);
        maxX = math.max(maxX, tx + nodeW);
        maxY = math.max(maxY, taskRowY + taskH);
      }
      lastRight = left + width;
    }

    // Handle empty case
    if (positions.isEmpty) {
      minX = 0;
      minY = 0;
      maxX = 600;
      maxY = totalHeight;
    }

    // Normalize positions so that all nodes are within padding
    final shiftX = pad - math.min(minX, pad);
    final shiftY = pad - math.min(minY, pad);
    final normalized = <String, Offset>{
      for (final e in positions.entries) e.key: e.value + Offset(shiftX, shiftY)
    };

    final contentWidth = (maxX - minX) + pad * 2;
    final contentHeight = (maxY - minY) + pad * 2;

    // Build edges list
    final edges = <(_Node, _Node)>[];
    for (final n in nodes) {
      if (n.level == 1) {
        final p = nodes.firstWhere((e) => e.id == n.parentId && e.level == 0,
            orElse: () => _Node.empty());
        if (!p.isEmpty) edges.add((p, n));
      } else if (n.level == 2) {
        final p = nodes.firstWhere((e) => e.id == n.parentId && e.level == 1,
            orElse: () => _Node.empty());
        if (!p.isEmpty) edges.add((p, n));
      } else if (n.level == 3) {
        final p = nodes.firstWhere((e) => e.id == n.parentId && e.level == 1,
            orElse: () => _Node.empty());
        if (!p.isEmpty) edges.add((p, n));
      }
    }

    // Canvas with pan/zoom
    // Fit-to-view setup
    final newHash = nodes.fold<int>(
        0, (acc, n) => acc ^ n.id ^ (n.level << 4) ^ n.type.hashCode);

    return LayoutBuilder(builder: (context, viewport) {
      // Auto-fit on content change
      if (newHash != _layoutHash && contentWidth > 0 && contentHeight > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _layoutHash = newHash;
          _fitToView(Size(viewport.maxWidth, viewport.maxHeight), contentWidth,
              contentHeight);
        });
      }

      void zoomIn() => _zoomTo(
          (_tc.value.getMaxScaleOnAxis() * 1.2).clamp(_minScale, _maxScale));
      void zoomOut() => _zoomTo(
          (_tc.value.getMaxScaleOnAxis() / 1.2).clamp(_minScale, _maxScale));
      void fit() => _fitToView(Size(viewport.maxWidth, viewport.maxHeight),
          contentWidth, contentHeight);

      return Stack(
        children: [
          InteractiveViewer(
            transformationController: _tc,
            minScale: _minScale,
            maxScale: _maxScale,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(1000),
            clipBehavior: Clip.none,
            child: Stack(
              children: [
                // subtle tinted background per design bg.base
                Container(
                  width: contentWidth,
                  height: contentHeight,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF2EBDD), Color(0xFFF8F5EE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Edges
                Positioned.fill(
                  child: CustomPaint(
                    painter: _EdgesPainter(
                      nodes: nodes,
                      positions: normalized,
                      nodeSize: const Size(nodeW, nodeH),
                      edges: edges,
                    ),
                  ),
                ),
                // Nodes
                ...nodes.map((n) {
                  final pos =
                      normalized['${n.type}:${n.id}'] ?? const Offset(0, 0);
                  return Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    width: nodeW,
                    height: n.level == 3 ? taskH : nodeH,
                    child: _NodeCard(node: n),
                  );
                }),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _ZoomControls(onIn: zoomIn, onOut: zoomOut, onFit: fit),
          ),
        ],
      );
    });
  }

  void _zoomTo(double targetScale) {
    final current = _tc.value.getMaxScaleOnAxis();
    if (current == targetScale) return;
    final factor = targetScale / current;
    final m = _tc.value.clone()..scale(factor);
    _tc.value = m;
  }

  void _fitToView(Size viewport, double contentWidth, double contentHeight) {
    final vw = viewport.width;
    final vh = viewport.height;
    final scale = math
        .min(vw / contentWidth, vh / contentHeight)
        .clamp(_minScale, _maxScale);
    final tx = (vw - contentWidth * scale) / 2;
    final ty = (vh - contentHeight * scale) / 2;
    _tc.value = Matrix4.identity()
      ..scale(scale)
      ..translate(tx / scale, ty / scale);
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls(
      {required this.onIn, required this.onOut, required this.onFit});
  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                tooltip: '拡大', icon: const Icon(Icons.add), onPressed: onIn),
            IconButton(
                tooltip: '縮小',
                icon: const Icon(Icons.remove),
                onPressed: onOut),
            IconButton(
                tooltip: 'フィット',
                icon: const Icon(Icons.fit_screen),
                onPressed: onFit),
          ],
        ),
      ),
    );
  }
}

class _Node {
  _Node(
      {required this.id,
      required this.title,
      required this.level,
      this.parentId,
      required this.type,
      this.priority,
      this.done,
      this.dueAt});
  final int id;
  final String title;
  final int level; // 0 dream, 1 long, 2 short
  final int? parentId;
  final String type; // 'dream' | 'long' | 'short' | 'task'
  final int? priority; // for task
  final bool? done; // for task
  final DateTime? dueAt; // for task

  static _Node level0(Dream d) =>
      _Node(id: d.id, title: d.title, level: 0, type: 'dream');
  static _Node level1Term(Term g, {required int parentId}) => _Node(
      id: g.id, title: g.title, level: 1, parentId: parentId, type: 'term');
  static _Node level2Term(Term g, {required int parentId}) => _Node(
      id: g.id, title: g.title, level: 2, parentId: parentId, type: 'term');
  static _Node level3(Task t, {required int parentId}) => _Node(
        id: t.id,
        title: t.title,
        level: 3,
        parentId: parentId,
        type: 'task',
        priority: t.priority,
        done: t.status == TaskStatus.done,
        dueAt: t.dueAt,
      );

  bool get isEmpty => id == -1;
  static _Node empty() => _Node(id: -1, title: '', level: -1, type: '');
}

class _EdgesPainter extends CustomPainter {
  _EdgesPainter(
      {required this.nodes,
      required this.positions,
      required this.nodeSize,
      required this.edges});
  final List<_Node> nodes;
  final Map<String, Offset> positions;
  final Size nodeSize;
  final List<(_Node, _Node)> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9C2B3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final (p, c) in edges) {
      final pPos = positions['${p.type}:${p.id}'] ?? Offset.zero;
      final cPos = positions['${c.type}:${c.id}'] ?? Offset.zero;
      final pCenter =
          Offset(pPos.dx + nodeSize.width / 2, pPos.dy + nodeSize.height);
      final cCenter = Offset(cPos.dx + nodeSize.width / 2, cPos.dy);

      final midY = (pCenter.dy + cCenter.dy) / 2;
      final path = Path()
        ..moveTo(pCenter.dx, pCenter.dy)
        ..cubicTo(pCenter.dx, midY, cCenter.dx, midY, cCenter.dx, cCenter.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgesPainter oldDelegate) {
    return oldDelegate.positions != positions ||
        oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges;
  }
}

class _NodeCard extends ConsumerWidget {
  const _NodeCard({required this.node});
  final _Node node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final border = switch (node.level) {
      0 => BorderSide(color: Colors.indigo.shade400, width: 2),
      1 => BorderSide(color: Colors.teal.shade400, width: 2),
      2 => BorderSide(color: Colors.orange.shade400, width: 2),
      _ => BorderSide(color: Colors.blueGrey.shade300, width: 1.5),
    };
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: border,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          if (node.level == 0) {
            // Dream detail page
            if (context.mounted) {
              context.push('/maps/dream/${node.id}', extra: node.title);
            }
          } else if (node.level == 1) {
            // Use router navigation so footer nav works
            context.push('/todo/term/${node.id}', extra: node.title);
          } else if (node.level == 2) {
            // Navigate to Term detail page
            context.push('/todo/term/${node.id}', extra: node.title);
          } else if (node.type == 'task') {
            // Tap TODO in Maps navigates to TODO detail
            if (context.mounted) {
              context.push('/todo/task/${node.id}', extra: node.title);
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(
                child: switch (node.level) {
                  1 => _TermNodeContent(node: node),
                  3 => _TaskNodeContent(node: node),
                  _ => Text(
                      node.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskNodeContent extends StatelessWidget {
  const _TaskNodeContent({required this.node});
  final _Node node;

  Color _priorityColor(int? p) {
    switch (p) {
      case 3:
        return const Color(0xFFE25555); // danger
      case 2:
        return const Color(0xFFE8A13A); // warning
      case 1:
        return const Color(0xFF2B6BE4); // brand
      default:
        return const Color(0xFF5E6672); // secondary
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          node.done == true ? Icons.check_circle : Icons.radio_button_unchecked,
          color: node.done == true
              ? const Color(0xFF3CB371)
              : const Color(0xFF5E6672),
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                node.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: _priorityColor(node.priority),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  if (node.dueAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.35)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${node.dueAt!.month}/${node.dueAt!.day}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskCluster {
  _TaskCluster(
      {required this.longId, required this.centerX, required this.tasks});
  final int longId;
  final double centerX;
  final List<Task> tasks;
}

class _TagPickerDialog extends StatefulWidget {
  const _TagPickerDialog({required this.allTags, required this.initial});
  final List<Tag> allTags;
  final List<Tag> initial;

  @override
  State<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _EditDreamDialog extends StatefulWidget {
  const _EditDreamDialog({required this.initial});
  final Dream initial;

  @override
  State<_EditDreamDialog> createState() => _EditDreamDialogState();
}

class _EditDreamDialogState extends State<_EditDreamDialog> {
  late TextEditingController _title;
  // Priority/Due are no longer editable for Dream; keep existing values.
  late int _priority;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _priority = widget.initial.priority;
    _dueAt = widget.initial.dueAt;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        initialDate: _dueAt ?? DateTime.now(),
      );
      if (picked != null) setState(() => _dueAt = picked);
    }

    return AlertDialog(
      title: const Text('夢を編集'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'タイトル'),
                  autofocus: true),
              // 夢には優先度・期限は不要のため、編集項目から除外
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            final d = Dream(
              id: widget.initial.id,
              title: _title.text.trim().isEmpty
                  ? widget.initial.title
                  : _title.text.trim(),
              // Keep existing values for non-editable fields
              priority: widget.initial.priority,
              dueAt: widget.initial.dueAt,
              color: widget.initial.color,
              archived: widget.initial.archived,
            )
              ..createdAt = widget.initial.createdAt
              ..updatedAt = DateTime.now();
            Navigator.pop(context, d);
          },
          child: const Text('保存'),
        )
      ],
    );
  }
}

class _EditTermDialog extends StatefulWidget {
  const _EditTermDialog(
      {required this.initial,
      required this.allTags,
      required this.initialTags});
  final Term initial;
  final List<Tag> allTags;
  final List<Tag> initialTags;

  @override
  State<_EditTermDialog> createState() => _EditTermDialogState();
}

class _EditTermDialogState extends State<_EditTermDialog> {
  late TextEditingController _title;
  late int _priority;
  DateTime? _dueAt;
  late Set<int> _selectedTagIds;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _priority = widget.initial.priority;
    _dueAt = widget.initial.dueAt;
    _selectedTagIds = widget.initialTags.map((t) => t.id).toSet();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        initialDate: _dueAt ?? DateTime.now(),
      );
      if (picked != null) setState(() => _dueAt = picked);
    }

    return AlertDialog(
      title: const Text('Termを編集'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'タイトル'),
                  autofocus: true),
              const SizedBox(height: 12),
              const Text('タグ'),
              const SizedBox(height: 8),
              if (widget.allTags.isEmpty)
                const Text('タグがありません。右上の「タグ管理」から作成してください。')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: -8,
                  children: widget.allTags
                      .map((t) => FilterChip(
                            selected: _selectedTagIds.contains(t.id),
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _selectedTagIds.add(t.id);
                                } else {
                                  _selectedTagIds.remove(t.id);
                                }
                              });
                            },
                            label: Text(t.name),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 12),
              const Text('期限'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                      label: const Text('なし'),
                      selected: _dueAt == null,
                      onSelected: (_) => setState(() => _dueAt = null)),
                  ChoiceChip(
                      label: const Text('今日'),
                      selected: false,
                      onSelected: (_) =>
                          setState(() => _dueAt = DateTime.now())),
                  ChoiceChip(
                      label: const Text('明日'),
                      selected: false,
                      onSelected: (_) => setState(() => _dueAt =
                          DateTime.now().add(const Duration(days: 1)))),
                  ActionChip(label: const Text('日付指定'), onPressed: pickDate),
                ],
              ),
              const SizedBox(height: 12),
              const Text('優先度'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                      label: const Text('低'),
                      selected: _priority == 0,
                      onSelected: (_) => setState(() => _priority = 0)),
                  ChoiceChip(
                      label: const Text('中'),
                      selected: _priority == 1,
                      onSelected: (_) => setState(() => _priority = 1)),
                  ChoiceChip(
                      label: const Text('高'),
                      selected: _priority == 2,
                      onSelected: (_) => setState(() => _priority = 2)),
                  ChoiceChip(
                      label: const Text('最優先'),
                      selected: _priority == 3,
                      onSelected: (_) => setState(() => _priority = 3)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            final updated = Term(
              id: widget.initial.id,
              title: _title.text.trim().isEmpty
                  ? widget.initial.title
                  : _title.text.trim(),
              parentId: widget.initial.parentId,
              dreamId: widget.initial.dreamId,
              priority: _priority,
              dueAt: _dueAt,
              archived: widget.initial.archived,
              color: widget.initial.color,
            );
            final selectedTags = widget.allTags
                .where((t) => _selectedTagIds.contains(t.id))
                .toList();
            Navigator.pop(
                context, _TermEditResult(item: updated, tags: selectedTags));
          },
          child: const Text('保存'),
        )
      ],
    );
  }
}

class _CreateTermDialog extends StatefulWidget {
  const _CreateTermDialog({required this.allTags});
  final List<Tag> allTags;

  @override
  State<_CreateTermDialog> createState() => _CreateTermDialogState();
}

class _CreateTermDialogState extends State<_CreateTermDialog> {
  final TextEditingController _title = TextEditingController();
  final Set<int> _selectedTagIds = {};
  int _priority = 1;
  DateTime? _dueAt;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        initialDate: _dueAt ?? DateTime.now(),
      );
      if (picked != null) setState(() => _dueAt = picked);
    }

    return AlertDialog(
      title: const Text('Termを作成'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'タイトル'),
                  autofocus: true),
              const SizedBox(height: 12),
              const Text('タグ'),
              const SizedBox(height: 8),
              if (widget.allTags.isEmpty)
                const Text('タグがありません。右上の「タグ管理」から作成してください。')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: -8,
                  children: widget.allTags
                      .map((t) => FilterChip(
                            selected: _selectedTagIds.contains(t.id),
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _selectedTagIds.add(t.id);
                                } else {
                                  _selectedTagIds.remove(t.id);
                                }
                              });
                            },
                            label: Text(t.name),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 12),
              const Text('期限'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                      label: const Text('なし'),
                      selected: _dueAt == null,
                      onSelected: (_) => setState(() => _dueAt = null)),
                  ChoiceChip(
                      label: const Text('今日'),
                      selected: false,
                      onSelected: (_) =>
                          setState(() => _dueAt = DateTime.now())),
                  ChoiceChip(
                      label: const Text('明日'),
                      selected: false,
                      onSelected: (_) => setState(() => _dueAt =
                          DateTime.now().add(const Duration(days: 1)))),
                  ActionChip(label: const Text('日付指定'), onPressed: pickDate),
                ],
              ),
              const SizedBox(height: 12),
              const Text('優先度'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                      label: const Text('低'),
                      selected: _priority == 0,
                      onSelected: (_) => setState(() => _priority = 0)),
                  ChoiceChip(
                      label: const Text('中'),
                      selected: _priority == 1,
                      onSelected: (_) => setState(() => _priority = 1)),
                  ChoiceChip(
                      label: const Text('高'),
                      selected: _priority == 2,
                      onSelected: (_) => setState(() => _priority = 2)),
                  ChoiceChip(
                      label: const Text('最優先'),
                      selected: _priority == 3,
                      onSelected: (_) => setState(() => _priority = 3)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            final t = _title.text.trim();
            if (t.isEmpty) {
              Navigator.pop(context);
              return;
            }
            final tags = widget.allTags
                .where((e) => _selectedTagIds.contains(e.id))
                .toList();
            Navigator.pop(
                context,
                _TermCreateResult(
                    title: t, tags: tags, priority: _priority, dueAt: _dueAt));
          },
          child: const Text('作成'),
        ),
      ],
    );
  }
}

class _TermEditResult {
  _TermEditResult({required this.item, required this.tags});
  final Term item;
  final List<Tag> tags;
}

class _TermCreateResult {
  _TermCreateResult(
      {required this.title,
      required this.tags,
      required this.priority,
      required this.dueAt});
  final String title;
  final List<Tag> tags;
  final int priority;
  final DateTime? dueAt;
}

class _TagPickerDialogState extends State<_TagPickerDialog> {
  late Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initial.map((t) => t.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('タグを選択'),
      content: SizedBox(
        width: 360,
        height: 360,
        child: widget.allTags.isEmpty
            ? const Center(child: Text('タグがありません。右上の「タグ管理」から作成してください。'))
            : ListView(
                children: widget.allTags
                    .map((t) => CheckboxListTile(
                          value: _selectedIds.contains(t.id),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedIds.add(t.id);
                              } else {
                                _selectedIds.remove(t.id);
                              }
                            });
                          },
                          title: Text(t.name),
                          secondary:
                              CircleAvatar(backgroundColor: Color(t.color)),
                        ))
                    .toList(),
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            final result = widget.allTags
                .where((t) => _selectedIds.contains(t.id))
                .toList();
            Navigator.pop(context, result);
          },
          child: const Text('保存'),
        )
      ],
    );
  }
}

class _TermNodeContent extends ConsumerWidget {
  const _TermNodeContent({required this.node});
  final _Node node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(termWithTagsProvider(node.id)).value;
    final tags = data?.tags ?? const <Tag>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          node.title,
          maxLines: 3,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: SizedBox(
              height: 22,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: tags
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Chip(
                              label: Text('#${t.name}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 0),
                              backgroundColor:
                                  Color(t.color).withOpacity(0.15),
                              side: BorderSide(
                                  color: Color(t.color).withOpacity(0.35)),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<String?> _askTitle(BuildContext context, String title) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'タイトル'),
        onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('追加')),
      ],
    ),
  );
}
