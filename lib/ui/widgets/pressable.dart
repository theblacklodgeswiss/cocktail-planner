import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion.dart';
import '../tokens.dart';

/// Tap target with press feedback shared by the base widgets: scales to 0.97
/// on pointer down, or dims instead when the OS asks for reduced motion.
/// [minSize] enlarges the hit area without changing the visual size. Also
/// focusable (Enter/Space activate, visible focus ring) unless disabled.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.minSize = 0,
    this.radius = AppRadius.control,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double minSize;

  /// Corner radius of the focus ring; match the child's shape.
  final double radius;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focused = false;

  void _setDown(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  void _activate() => widget.onTap?.call();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduced = AppMotion.reduced(context);
    final pressed = _down && enabled;
    final palette = AppPalette.of(context);

    Widget content = widget.child;
    if (_focused && enabled) {
      content = DecoratedBox(
        key: const ValueKey('focus-ring'),
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: palette.primary, width: AppSize.focusRing),
        ),
        child: content,
      );
    }
    if (reduced) {
      content = Opacity(
        opacity: pressed ? AppSize.pressedOpacity : 1,
        child: content,
      );
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
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        // Listener, not onTapDown: the latter waits for the press timeout.
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: enabled ? (_) => _setDown(true) : null,
          onPointerUp: (_) => _setDown(false),
          onPointerCancel: (_) => _setDown(false),
          onPointerMove: (e) {
            final box = context.size;
            if (box != null && !(Offset.zero & box).contains(e.localPosition)) {
              _setDown(false);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.minSize,
                minHeight: widget.minSize,
              ),
              child: Center(widthFactor: 1, heightFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
