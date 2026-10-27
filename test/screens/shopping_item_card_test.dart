import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/screens/shopping_list/widgets/shopping_item_card.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(
  Widget home, {
  ThemeData? theme,
  double textScale = 1,
  double keyboard = 0,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('de'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('de'),
    startLocale: const Locale('de'),
    child: Builder(
      builder: (context) => MaterialApp(
        theme: theme ?? AppTheme.light(),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
}

Future<void> pumpApp(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump(const Duration(milliseconds: 400));
}

const item = MaterialItem(
  unit: '0.7L',
  name: 'Baileys Irish Cream Original Likör',
  price: 14,
  currency: 'CHF',
  note: 'Kaufland',
);

Widget card({int quantity = 2, void Function(int)? onChanged}) {
  final controller = TextEditingController(text: '$quantity');
  return Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ShoppingItemCard(
        item: item,
        controller: controller,
        quantity: quantity,
        isSelected: quantity > 0,
        cocktails: const ['Mojito Classic', 'Shot B52 mit Sahne'],
        totalSelected: 4,
        onQuantityChanged: onChanged ?? (_) {},
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('plus and minus have at least 44x44 tap areas', (tester) async {
    await pumpApp(tester, app(card()));
    for (final key in const ['quantity-plus', 'quantity-minus']) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.width, greaterThanOrEqualTo(44), reason: key);
      expect(size.height, greaterThanOrEqualTo(44), reason: key);
    }
  });

  testWidgets('plus and minus report the new quantity', (tester) async {
    final calls = <int>[];
    await pumpApp(tester, app(card(onChanged: calls.add)));
    await tester.tap(find.byKey(const Key('quantity-plus')));
    await tester.tap(find.byKey(const Key('quantity-minus')));
    expect(calls, [3, 1]);
  });

  testWidgets('minus is disabled at zero', (tester) async {
    final calls = <int>[];
    await pumpApp(tester, app(card(quantity: 0, onChanged: calls.add)));
    await tester.tap(find.byKey(const Key('quantity-minus')));
    expect(calls, isEmpty);
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360x640, scale 1.3, keyboard (dark=$dark)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        app(
          card(),
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          textScale: 1.3,
          keyboard: 300,
        ),
      );
      await tester.tap(find.byKey(const Key('quantity-field')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
