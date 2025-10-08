import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import '../../models/task.dart';
import '../../providers/task_providers.dart';
import '../../providers/term_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/db_provider.dart';
import '../../repositories/term_repositories.dart';
import '../../utils/date_utils.dart' as du;

class ActivityReportPage extends ConsumerStatefulWidget {
  const ActivityReportPage({super.key});

  @override
  ConsumerState<ActivityReportPage> createState() => _ActivityReportPageState();
}

class _ActivityReportPageState extends ConsumerState<ActivityReportPage> {
  final GlobalKey _captureKeyVisible = GlobalKey();
  // Used for offscreen capture in an Overlay
  final GlobalKey _captureKeyExport = GlobalKey();
  late DateTime _start;
  late DateTime _end;
  int? _selectedDreamId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = du.startOfDay(now.subtract(const Duration(days: 6)));
    _end = du.endOfDay(now);
  }

  @override
  Widget build(BuildContext context) {
    final init = ref.watch(isarInitProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('活動記録'),
        actions: [
          IconButton(
            tooltip: '共有',
            onPressed: () => _shareImage(context),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: init.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('DB初期化エラー: $e')),
        data: (_) => Column(
          children: [
            _Filters(
              start: _start,
              end: _end,
              selectedDreamId: _selectedDreamId,
              onChangedRange: (s, e) => setState(() {
                _start = s;
                _end = e;
              }),
              onChangedDream: (id) => setState(() => _selectedDreamId = id),
            ),
            const Divider(height: 1),
            Expanded(
              child: RepaintBoundary(
                key: _captureKeyVisible,
                child: _ReportContent(
                  start: _start,
                  end: _end,
                  selectedDreamId: _selectedDreamId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareImage(BuildContext context) async {
    try {
      // Build an offscreen, scroll-free full-size report in an Overlay,
      // lay it out at intrinsic height, then capture via RepaintBoundary.
      final overlayState = Overlay.of(context);
      if (overlayState == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('共有エラー: Overlayが取得できません')),
          );
        }
        return;
      }

      final Size screenSize = MediaQuery.of(context).size;

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) {
          // Use Theme/MediaQuery from the page to keep styles consistent.
          return MediaQuery(
            data: MediaQuery.of(context),
            child: Theme(
              data: Theme.of(context),
              child: IgnorePointer(
                ignoring: true,
                child: Stack(
                  children: [
                    // Keep almost invisible to avoid visual flash while ensuring painting happens.
                    Opacity(
                      opacity: 0.01,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: OverflowBox(
                          maxWidth: screenSize.width,
                          minWidth: screenSize.width,
                          maxHeight: double.infinity,
                          child: RepaintBoundary(
                            key: _captureKeyExport,
                            child: Container(
                              color: Colors.white,
                              width: screenSize.width,
                              child: _ReportContent(
                                start: _start,
                                end: _end,
                                selectedDreamId: _selectedDreamId,
                                forExport: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      overlayState.insert(entry);
      // Wait for the overlay content to layout and paint.
      await Future.delayed(const Duration(milliseconds: 50));
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _captureKeyExport.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        entry.remove();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像生成に失敗しました')),
          );
        }
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像データの取得に失敗しました')),
          );
        }
        return;
      }
      final pngBytes = byteData.buffer.asUint8List();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final xfile = XFile.fromData(
        pngBytes,
        name: 'activity_report_$ts.png',
        mimeType: 'image/png',
      );
      await Share.shareXFiles([xfile], text: '活動記録');
      // Clean up overlay after sharing
      entry.remove();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('共有エラー: $e')),
        );
      }
    }
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({
    required this.start,
    required this.end,
    required this.selectedDreamId,
    required this.onChangedRange,
    required this.onChangedDream,
  });

  final DateTime start;
  final DateTime end;
  final int? selectedDreamId;
  final void Function(DateTime, DateTime) onChangedRange;
  final void Function(int?) onChangedDream;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dreamsAsync = ref.watch(dreamsProvider);
    final df = DateFormat('yyyy/MM/dd');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonal(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDateRange: DateTimeRange(start: start, end: end),
                        );
                        if (picked != null) {
                          onChangedRange(du.startOfDay(picked.start), du.endOfDay(picked.end));
                        }
                      },
                      child: Text('${df.format(start)} 〜 ${df.format(end)}'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.bedtime_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: dreamsAsync.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (e, _) => Text('夢の取得エラー: $e'),
                  data: (dreams) {
                    return DropdownButtonFormField<int?>(
                      isExpanded: true,
                      value: selectedDreamId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('すべての夢')),
                        ...dreams.map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.title),
                            )),
                      ],
                      onChanged: onChangedDream,
                      decoration: const InputDecoration(labelText: '対象の夢'),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportContent extends ConsumerWidget {
  const _ReportContent({
    required this.start,
    required this.end,
    required this.selectedDreamId,
    this.forExport = false,
  });

  final DateTime start;
  final DateTime end;
  final int? selectedDreamId;
  final bool forExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(allTasksStreamProvider).value ?? const <Task>[];
    final childTerms = ref.watch(allChildTermsProvider).value ?? const <Term>[];
    final topTerms = ref.watch(allTopTermsProvider).value ?? const <Term>[];
    final dreams = ref.watch(dreamsProvider).value ?? const [];

    // Build lookup maps
    final childById = {for (final t in childTerms) t.id: t};
    final topById = {for (final t in topTerms) t.id: t};
    final dreamById = {for (final d in dreams) d.id: d};

    // Filter tasks by done in range and dream filter (supports ShortTerm or LongTerm linking)
    bool inRange(DateTime? dt) => dt != null && !dt.isBefore(start) && !dt.isAfter(end);
    final filtered = allTasks.where((t) {
      if (t.status != TaskStatus.done || !inRange(t.doneAt)) return false;
      if (selectedDreamId == null) return true;
      if (t.shortTermId == null) return false;
      // Try resolve as ShortTerm first, then LongTerm
      final child = childById[t.shortTermId!];
      if (child != null) return child.dreamId == selectedDreamId;
      final top = topById[t.shortTermId!];
      return top?.dreamId == selectedDreamId;
    }).toList();

    // Group by ShortTerm id (nullable for unlinked)
    final grouped = <int?, List<Task>>{};
    for (final t in filtered) {
      (grouped[t.shortTermId] ??= <Task>[]).add(t);
    }

    // Build display list: order by resolved term title (child if exists, else top)
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1; // unlinked last
        if (b == null) return -1;
        String at = childById[a]?.title ?? topById[a]?.title ?? '';
        String bt = childById[b]?.title ?? topById[b]?.title ?? '';
        return at.compareTo(bt);
      });

    final df = DateFormat('yyyy/MM/dd');
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('期間: ${df.format(start)} 〜 ${df.format(end)}',
              style: Theme.of(context).textTheme.bodySmall),
          if (selectedDreamId != null)
            Text('対象の夢: ${dreamById[selectedDreamId]?.title ?? '—'}',
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );

    final List<Widget> body = [];
    body.add(header);
    if (grouped.isEmpty) {
      body.addAll([
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text('該当する完了TODOはありません',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(height: 12),
        _AchievedTermsSection(
          topTerms: topTerms,
          childTerms: childTerms,
          dreamsById: dreamById,
          selectedDreamId: selectedDreamId,
        ),
      ]);
    } else {
      body.addAll([
        const SizedBox(height: 8),
        Text('完了したTODO', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...keys.map((k) {
          final items = grouped[k]!..sort((a, b) => (a.doneAt ?? a.createdAt).compareTo(b.doneAt ?? b.createdAt));
          if (k == null) {
            return _UnlinkedTasksSection(items: items);
          }
          final child = childById[k];
          if (child != null) {
            final parent = child.parentId != null ? topById[child.parentId!] : null;
            final d = (child.dreamId != null) ? dreamById[child.dreamId!] : null;
            return _TermTasksSection(
              parentTitle: parent?.title,
              childTitle: child.title,
              dreamTitle: d?.title,
              items: items,
            );
          }
          // Fallback for LongTerm-linked tasks
          final top = topById[k];
          if (top != null) {
            final d = (top.dreamId != null) ? dreamById[top.dreamId!] : null;
            return _TermTasksSection(
              parentTitle: null,
              childTitle: top.title,
              dreamTitle: d?.title,
              items: items,
            );
          }
          // Unknown id (shouldn't happen) -> skip
          return const SizedBox.shrink();
        }).toList(),
        const SizedBox(height: 16),
        _AchievedTermsSection(
          topTerms: topTerms,
          childTerms: childTerms,
          dreamsById: dreamById,
          selectedDreamId: selectedDreamId,
        ),
      ]);
    }

    if (forExport) {
      // Render full-height, non-scrollable content for capture
      return Container(
        width: MediaQuery.of(context).size.width,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: body,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: body,
      ),
    );
  }
}

class _AchievedTermsSection extends StatelessWidget {
  const _AchievedTermsSection({
    required this.topTerms,
    required this.childTerms,
    required this.dreamsById,
    required this.selectedDreamId,
  });

  final List<Term> topTerms;
  final List<Term> childTerms;
  final Map<int, dynamic> dreamsById; // Dream
  final int? selectedDreamId;

  @override
  Widget build(BuildContext context) {
    // Note: Termには達成日時がないため期間フィルタは未対応。夢フィルタのみ適用。
    final achievedTop = topTerms
        .where((t) => t.archived && (selectedDreamId == null || t.dreamId == selectedDreamId))
        .toList()
      ..sort((a, b) => (a.title).compareTo(b.title));
    final achievedChild = childTerms
        .where((t) => t.archived && (selectedDreamId == null || t.dreamId == selectedDreamId))
        .toList()
      ..sort((a, b) => (a.title).compareTo(b.title));

    if (achievedTop.isEmpty && achievedChild.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('達成した目標', style: Theme.of(context).textTheme.titleMedium),
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 2.0),
          child: Text('※ 目標の達成日時が未記録のため、期間は適用されません',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
        ),
        ...achievedTop.map((t) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text(t.title),
                subtitle: t.dreamId != null
                    ? Text('夢: ${dreamsById[t.dreamId]?.title ?? '—'}')
                    : null,
              ),
            )),
        ...achievedChild.map((t) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.flag_circle_outlined),
                title: Text(t.title),
                subtitle: t.dreamId != null
                    ? Text('夢: ${dreamsById[t.dreamId]?.title ?? '—'} / サブ目標')
                    : const Text('サブ目標'),
              ),
            )),
      ],
    );
  }
}

class _TermTasksSection extends StatelessWidget {
  const _TermTasksSection({
    required this.parentTitle,
    required this.childTitle,
    required this.dreamTitle,
    required this.items,
  });

  final String? parentTitle;
  final String childTitle;
  final String? dreamTitle;
  final List<Task> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dreamTitle != null)
                        Text('夢: $dreamTitle',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[700])),
                      Text(
                        parentTitle == null ? childTitle : '$parentTitle / $childTitle',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Text('TODO ${items.length} 件',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFFE0E0E0), width: 2)),
              ),
              padding: const EdgeInsets.only(left: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: -8,
                children: items
                    .map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ActionChip(
                            label: Text(t.title, overflow: TextOverflow.ellipsis),
                            onPressed: null,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlinkedTasksSection extends StatelessWidget {
  const _UnlinkedTasksSection({required this.items});
  final List<Task> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link_off),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '紐付けなし',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text('TODO ${items.length} 件',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: -8,
              children: items
                  .map((t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ActionChip(
                          label: Text(t.title, overflow: TextOverflow.ellipsis),
                          onPressed: null,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
