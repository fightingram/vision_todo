import 'package:flutter/material.dart';

/// GradientCard: design-system のオプションカード仕様に準拠
class GradientCard extends StatefulWidget {
  const GradientCard({
    super.key,
    required this.gradient,
    required this.title,
    this.subtitle,
    this.decoration,
    this.onTap,
    this.selected = false,
  });

  final Gradient gradient;
  final String title;
  final String? subtitle;
  final Widget? decoration; // 右側装飾（不透明度 12–18% 推奨）
  final VoidCallback? onTap;
  final bool selected;

  @override
  State<GradientCard> createState() => _GradientCardState();
}

class _GradientCardState extends State<GradientCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    final overlay = _pressed
        ? Colors.black.withOpacity(0.08)
        : Colors.transparent;
    final border = widget.selected
        ? Border.all(color: const Color(0xFF2B6BE4), width: 2)
        : null;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: const Cubic(0.2, 0.8, 0.2, 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: borderRadius,
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: borderRadius,
              border: border,
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.08),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              ],
            ),
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 68),
            child: Stack(
              children: [
                // content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // left texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 22 / 16,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFEEFFFFFF),
                                fontSize: 13,
                                height: 18 / 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // right decoration
                    if (widget.decoration != null)
                      Opacity(opacity: 0.16, child: widget.decoration!),
                  ],
                ),
                // pressed overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: overlay,
                      borderRadius: borderRadius,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

