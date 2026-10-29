import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real German translations behind a GoRouter (same wiring as
/// settings_test.dart); [home] is the page under test.
Widget adminApp(
  Widget home, {
  ThemeData? theme,
  double textScale = 1,
  String lang = 'de',
}) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => home)],
  );
  return EasyLocalization(
    supportedLocales: const [Locale('de'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('de'),
    startLocale: Locale(lang),
    child: Builder(
      builder: (context) => MaterialApp.router(
        theme: theme ?? AppTheme.light(),
        routerConfig: router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
}

Future<void> initAdminTest() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

Future<void> pumpAdmin(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Advances time so sheets and animations finish.
Future<void> settleAdmin(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void phone(WidgetTester tester, {double w = 360, double h = 640}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
