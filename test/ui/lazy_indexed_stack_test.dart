import 'package:cocktail_planer/ui/widgets/lazy_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds pages lazily and keeps their state', (tester) async {
    var built = 0;
    Widget stack(int index) => MaterialApp(
      home: Scaffold(
        body: LazyIndexedStack(
          index: index,
          builders: [
            (_) => const TextField(key: Key('a')),
            (_) {
              built++;
              return const TextField(key: Key('b'));
            },
          ],
        ),
      ),
    );

    await tester.pumpWidget(stack(0));
    expect(built, 0);
    await tester.enterText(find.byKey(const Key('a')), 'hallo');

    await tester.pumpWidget(stack(1));
    expect(built, 1);
    await tester.pumpWidget(stack(0));
    expect(find.text('hallo'), findsOneWidget);
    expect(find.byKey(const Key('b'), skipOffstage: false), findsOneWidget);
  });
}
