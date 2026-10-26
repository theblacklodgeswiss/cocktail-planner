import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

/// Tap target with press feedback shared by the base widgets: scales to 0.97
/// on pointer down, or dims instead when the OS asks for reduced motion.
/// [minSize] enlarges the hit area without changing the visual size.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.minSize = 0,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double minSize;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduced = AppMotion.reduced(context);
    final pressed = _down && enabled;

    Widget content = widget.child;
    if (reduced) {
      content = Opacity(opacity: pressed ? 0.7 : 1, child: content);
    } else {
      content = AnimatedScale(
        scale: pressed ? AppSize.pressScale : 1,
        duration: AppMotion.press,
        curve: AppMotion.easeOut,
        child: content,
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minSize,
            minHeight: widget.minSize,
          ),
          child: Center(widthFactor: 1, heightFactor: 1, child: content),
        ),
      ),
    );
  }
}
