import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../providers/stats_provider.dart';

class CharacterBand extends ConsumerWidget {
  const CharacterBand({super.key});

  String _areaName(int km) {
    if (km < 20) return '森';
    if (km < 50) return '砂漠';
    if (km < 100) return '都市';
    if (km < 150) return '海';
    return 'ゴール';
  }

  Color _bg(int km) {
    if (km < 20) return Colors.green.shade100;
    if (km < 50) return Colors.amber.shade100;
    if (km < 100) return Colors.blueGrey.shade100;
    if (km < 150) return Colors.lightBlue.shade100;
    return Colors.purple.shade100;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counters = ref.watch(countersProvider);
    final total = counters.total;
    final area = _areaName(total);
    final animations = ref.watch(settingsProvider.select((s) => s.animations));
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        final pos = (total % 10) / 10.0; // simple progress within segment
        return AnimatedContainer(
          duration: animations ? const Duration(milliseconds: 400) : Duration.zero,
          color: _bg(total),
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Character moves only within a safe horizontal area to avoid text overlap
                Padding(
                  padding: EdgeInsets.only(left: width > 500 ? 220.0 : 160.0, right: 16.0),
                  child: Align(
                    alignment: Alignment.lerp(Alignment.centerLeft, Alignment.centerRight, pos)!,
                    child: Image.asset(
                      'assets/chara1.PNG',
                      height: height * 1.2, // 2x from previous 0.6 => 1.2
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Text area pinned to top-left
                Positioned(
                  left: 16,
                  top: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$total km · $area', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('今週 ${counters.week} · 今月 ${counters.month} · 累計 ${counters.total}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
