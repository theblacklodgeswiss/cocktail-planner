import 'package:flutter/material.dart';

import '../tokens.dart';
import 'pressable.dart';

class PillOption<T> {
  const PillOption(this.value, this.label, {this.count});

  final T value;
  final String label;
  final int? count;
}

/// Horizontal row of filter pills; the active one is filled black.
class PillFilter<T> extends StatelessWidget {
  const PillFilter({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<PillOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in options) ...[
            Pressable(
              minSize: AppSize.minTap,
              selected: o.value == value,
              onTap: () => onChanged(o.value),
              child: _Pill(
                text: o.count == null ? o.label : '${o.label} ${o.count}',
                active: o.value == value,
                palette: p,
              ),
            ),
            if (o != options.last) const SizedBox(width: AppSpace.s4),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.active,
    required this.palette,
  });

  final String text;
  final bool active;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? palette.primary : palette.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: active ? palette.primary : palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8,
        ),
        child: Text(
          text,
          style: AppText.pill.copyWith(
            color: active ? palette.onPrimary : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
