import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cocktail_planer/screens/share/shared_document_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // easy_localization persists the resolved locale via shared_preferences;
    // the plain flutter_test environment has no platform channel for it, so
    // seed the mock in-memory implementation before initializing.
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  // The first test only asserts on widget *type* (CircularProgressIndicator),
  // so it doesn't need tr() to actually resolve and can use a plain
  // MaterialApp. The second test asserts on translated *text*, so it wires
  // up MaterialApp's localizationsDelegates/supportedLocales exactly like
  // lib/app.dart does — otherwise tr() returns the raw key instead of the
  // translation. (Wiring the real delegates into both tests' MaterialApps
  // makes the *second* Localizations load hang indefinitely inside this
  // plain flutter_test binary — an easy_localization/flutter_test
  // interaction, not a production concern — so only the test that needs
  // resolved text pays for the real delegates.)
  Widget wrapPlain(Widget child) {
    return EasyLocalization(
      supportedLocales: const [Locale('de'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('de'),
      startLocale: const Locale('de'),
      child: Builder(builder: (context) => MaterialApp(home: child, locale: context.locale)),
    );
  }

  Widget wrapLocalized(Widget child) {
    return EasyLocalization(
      supportedLocales: const [Locale('de'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('de'),
      startLocale: const Locale('de'),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: child,
        ),
      ),
    );
  }

  testWidgets('shows a loading indicator before the fetch resolves', (tester) async {
    await tester.pumpWidget(wrapPlain(const SharedDocumentScreen(code: 'doesNotMatter')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the expired message for an unknown code', (tester) async {
    await tester.pumpWidget(wrapLocalized(const SharedDocumentScreen(code: 'unknown1')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('abgelaufen'), findsOneWidget);
  });
}
