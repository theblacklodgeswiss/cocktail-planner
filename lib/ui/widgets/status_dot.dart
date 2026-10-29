import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../tokens.dart';

enum StatusKind { offer, accepted, completed, declined }

/// 6 px status dot with optional label. Only accepted is gold.
class StatusDot extends StatelessWidget {
  const StatusDot(this.kind, {super.key, this.showLabel = true});

  final StatusKind kind;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = switch (kind) {
      StatusKind.accepted => p.gold,
      StatusKind.offer => p.statusOffer,
      StatusKind.completed => p.statusDone,
      StatusKind.declined => p.error,
    };
    final dot = DecoratedBox(
      key: const ValueKey('status-dot'),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: AppSize.statusDot),
    );
    final label = 'status.${kind.name}'.tr();
    if (!showLabel) {
      return Semantics(
        label: label,
        child: ExcludeSemantics(child: dot),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: AppSpace.s4),
        Flexible(
          child: Text(
            label,
            style: AppText.status.copyWith(color: p.textSecondary),
          ),
        ),
      ],
    );
  }
}
