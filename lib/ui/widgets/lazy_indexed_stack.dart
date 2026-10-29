import 'package:flutter/material.dart';

/// Shows one child at a time like [IndexedStack], but builds a child only
/// when it is first selected and keeps it alive afterwards, so switching
/// pages keeps scroll position and typed text.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
  });

  final int index;
  final List<WidgetBuilder> builders;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final Set<int> _built = {widget.index};

  @override
  Widget build(BuildContext context) {
    _built.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.builders.length; i++)
          if (_built.contains(i))
            widget.builders[i](context)
          else
            const SizedBox.shrink(),
      ],
    );
  }
}
