import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Call this when a task is marked done.
Future<void> showPostItCelebration(BuildContext context) async {
  final overlay = Overlay.of(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _PostItTearOverlay(
      onFinished: () {
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _PostItTearOverlay extends StatefulWidget {
  const _PostItTearOverlay({required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<_PostItTearOverlay> createState() => _PostItTearOverlayState();
}

class _PostItTearOverlayState extends State<_PostItTearOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fallCtrl;
  late final AnimationController _splitCtrl;
  late final AnimationController _fadeCtrl;
  final _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  void initState() {
    super.initState();
    // Slower (half speed): doubled durations
    _fallCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
    _splitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 840));
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));

    _run();
  }

  Future<void> _run() async {
    try {
      await _fallCtrl.forward();
      // Play tear sound right as the tear starts
      // Expecting an asset at assets/sounds/paper_tear.wav
      // If not present, ignore error silently.
      // ignore: unawaited_futures
      // Haptic feedback to enhance sense of accomplishment
      // Best-effort; on unsupported platforms this is a no-op.
      HapticFeedback.heavyImpact();
      _player.play(AssetSource('sounds/paper_tear.wav')).catchError((_) {});
      await _splitCtrl.forward();
      await _fadeCtrl.forward();
    } finally {
      if (mounted) widget.onFinished();
    }
  }

  @override
  void dispose() {
    _fallCtrl.dispose();
    _splitCtrl.dispose();
    _fadeCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Subtle backdrop fade
            AnimatedBuilder(
              animation: _fallCtrl,
              builder: (_, __) => Opacity(
                opacity: Curves.easeOut.transform((_fallCtrl.value * 0.35).clamp(0, 0.35)),
                child: Container(color: Colors.black.withOpacity(0.05)),
              ),
            ),

            // Falling post-it
            AnimatedBuilder(
              animation: Listenable.merge([_fallCtrl, _splitCtrl, _fadeCtrl]),
              builder: (context, _) {
                final fallY = Tween<double>(begin: -180, end: size.height * 0.35)
                    .chain(CurveTween(curve: Curves.easeIn))
                    .evaluate(_fallCtrl);
                final fallScale = Tween<double>(begin: 0.9, end: 1.0)
                    .chain(CurveTween(curve: Curves.easeOut))
                    .evaluate(_fallCtrl);

                // Split progress 0..1
                final split = _splitCtrl.value;
                final fade = _fadeCtrl.value;

                final leftDx = Tween<double>(begin: 0, end: -80).evaluate(_splitCtrl);
                final leftDy = Tween<double>(begin: 0, end: -40).evaluate(_splitCtrl);
                final rightDx = Tween<double>(begin: 0, end: 80).evaluate(_splitCtrl);
                final rightDy = Tween<double>(begin: 0, end: 40).evaluate(_splitCtrl);

                final leftRot = Tween<double>(begin: -0.03, end: -0.22).evaluate(_splitCtrl);
                final rightRot = Tween<double>(begin: 0.03, end: 0.22).evaluate(_splitCtrl);

                final base = Center(
                  child: Transform.translate(
                    offset: Offset(0, fallY - size.height * 0.5),
                    child: Transform.scale(
                      scale: fallScale,
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (split == 0)
                              _PostItNoteWidget(),
                            if (split > 0) ...[
                              // Left half
                              Opacity(
                                opacity: 1 - fade,
                                child: Transform.translate(
                                  offset: Offset(leftDx, leftDy),
                                  child: Transform.rotate(
                                    angle: leftRot,
                                    child: const _PostItHalf(left: true),
                                  ),
                                ),
                              ),
                              // Right half
                              Opacity(
                                opacity: 1 - fade,
                                child: Transform.translate(
                                  offset: Offset(rightDx, rightDy),
                                  child: Transform.rotate(
                                    angle: rightRot,
                                    child: const _PostItHalf(left: false),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                return base;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PostItNoteWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFFFF59D); // sticky note yellow
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          // top tape
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              width: 70,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0x80FFFFFF),
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
            ),
          ),
          // text
          Center(
            child: Text(
              'TODO',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF37474F),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostItHalf extends StatelessWidget {
  const _PostItHalf({required this.left});
  final bool left;

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFFFF59D);
    return ClipPath(
      clipper: _TearClipper(left: left),
      child: SizedBox(
        width: 150,
        height: 150,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 8))],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 70,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0x80FFFFFF),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TearClipper extends CustomClipper<Path> {
  _TearClipper({required this.left});
  final bool left;
  @override
  Path getClip(Size size) {
    final path = Path();
    if (left) {
      path.moveTo(0, 0);
      path.lineTo(size.width * 0.5, 0);
      // jagged vertical tear
      final step = size.height / 12.0;
      for (int i = 0; i <= 12; i++) {
        final y = step * i;
        final x = size.width * 0.5 + (i.isEven ? -4 : 4);
        path.lineTo(x, y);
      }
      path.lineTo(0, size.height);
      path.close();
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width * 0.5, 0);
      final step = size.height / 12.0;
      for (int i = 0; i <= 12; i++) {
        final y = step * i;
        final x = size.width * 0.5 + (i.isEven ? 4 : -4);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
