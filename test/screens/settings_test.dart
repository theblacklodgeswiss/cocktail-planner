import 'package:cocktail_planer/models/app_settings.dart';
import 'package:cocktail_planer/screens/settings/admin_settings_view.dart';
import 'package:cocktail_planer/screens/settings/legal_info_screen.dart';
import 'package:cocktail_planer/screens/settings/settings_view.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(
  Widget home, {
  ThemeData? theme,
  double textScale = 1,
  String lang = 'de',
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/settings/admin',
        builder: (_, _) => const Scaffold(body: Text('page /settings/admin')),
      ),
      GoRoute(
        path: '/settings/users',
        builder: (_, _) => const Scaffold(body: Text('page /settings/users')),
      ),
    ],
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

Future<void> pumpApp(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
}

SettingsView view({
  bool isAdmin = false,
  bool canManageUsers = false,
  ThemeMode themeMode = ThemeMode.system,
  ValueChanged<ThemeMode>? onThemeMode,
  Widget? microsoft,
  AppSettings? company,
}) => SettingsView(
  appVersion: '1.2.3',
  buildNumber: '45',
  userId: 'uid-123',
  isAdmin: isAdmin,
  canManageUsers: canManageUsers,
  themeMode: themeMode,
  onThemeMode: onThemeMode ?? (_) {},
  microsoft: microsoft,
  company: company,
  onEditCompany: () {},
  onRefreshApp: null,
);

AdminSettingsView adminView({
  Future<void> Function(int)? onSave,
  AdminStatus? enrichStatus,
}) => AdminSettingsView(
  threshold: 400,
  claudeConfigured: true,
  microsoftLoggedIn: false,
  isImporting: false,
  onImport: () {},
  isEnriching: false,
  enrichStatus: enrichStatus,
  onEnrich: () {},
  isGenerating: false,
  generateStatus: null,
  onGenerate: (_) {},
  onSave: onSave ?? (_) async {},
);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  void phone(WidgetTester tester, {double w = 360, double h = 640}) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('SettingsView visibility', () {
    testWidgets('customer sees appearance, legal and about only', (
      tester,
    ) async {
      phone(tester, h: 3000);
      await pumpApp(
        tester,
        app(view(microsoft: const Text('ms'), company: const AppSettings())),
      );
      expect(find.text('Erscheinungsbild'), findsOneWidget);
      expect(find.text('Sprache'), findsOneWidget);
      expect(find.text('Impressum'), findsOneWidget);
      expect(find.text('1.2.3 (45)'), findsOneWidget);
      expect(find.byKey(const Key('settings-admin-card')), findsNothing);
      expect(find.byKey(const Key('settings-users')), findsNothing);
      expect(find.byKey(const Key('settings-microsoft')), findsNothing);
      expect(find.byKey(const Key('settings-company')), findsNothing);
    });

    testWidgets('admin sees admin and company cards, no user entries', (
      tester,
    ) async {
      phone(tester, h: 3000);
      await pumpApp(
        tester,
        app(
          view(
            isAdmin: true,
            microsoft: const Text('ms', key: Key('settings-microsoft')),
            company: const AppSettings(),
          ),
        ),
      );
      expect(find.byKey(const Key('settings-admin-card')), findsOneWidget);
      expect(find.byKey(const Key('settings-microsoft')), findsOneWidget);
      expect(find.byKey(const Key('settings-company')), findsOneWidget);
      expect(find.byKey(const Key('settings-users')), findsNothing);
    });

    testWidgets('canManageUsers sees users, employees and services', (
      tester,
    ) async {
      phone(tester, h: 3000);
      await pumpApp(tester, app(view(isAdmin: true, canManageUsers: true)));
      expect(find.byKey(const Key('settings-users')), findsOneWidget);
      expect(find.byKey(const Key('settings-employees')), findsOneWidget);
      expect(find.byKey(const Key('settings-services')), findsOneWidget);
    });

    testWidgets('admin entry navigates to the admin route', (tester) async {
      phone(tester, h: 3000);
      await pumpApp(tester, app(view(isAdmin: true)));
      await tester.tap(find.byKey(const Key('settings-admin-settings')));
      await settle(tester);
      expect(find.text('page /settings/admin'), findsOneWidget);
    });
  });

  group('pickers', () {
    testWidgets('choosing a theme in the sheet calls the setter', (
      tester,
    ) async {
      phone(tester);
      ThemeMode? chosen;
      await pumpApp(
        tester,
        app(view(onThemeMode: (m) => chosen = m)),
      );
      await tester.tap(find.byKey(const Key('settings-theme')));
      await settle(tester);
      expect(find.text('Hell'), findsOneWidget);
      await tester.tap(find.text('Dunkel'));
      await settle(tester);
      expect(chosen, ThemeMode.dark);
      expect(find.text('Hell'), findsNothing);
    });

    testWidgets('choosing a language in the sheet changes the locale', (
      tester,
    ) async {
      phone(tester);
      await pumpApp(tester, app(view()));
      await tester.tap(find.byKey(const Key('settings-language')));
      await settle(tester);
      await tester.tap(find.text('English'));
      await settle(tester);
      final ctx = tester.element(find.byType(SettingsView));
      expect(ctx.locale.languageCode, 'en');
    });
  });

  group('LegalInfoScreen', () {
    testWidgets('imprint renders its text', (tester) async {
      phone(tester, h: 3000);
      await pumpApp(
        tester,
        app(const LegalInfoScreen(type: LegalInfoType.imprint)),
      );
      expect(find.text('Impressum'), findsWidgets);
      expect(find.text('Einzelunternehmen'), findsOneWidget);
    });

    testWidgets('terms renders numbered headings', (tester) async {
      phone(tester, h: 4000);
      await pumpApp(
        tester,
        app(const LegalInfoScreen(type: LegalInfoType.terms)),
      );
      expect(find.text('1. Geltungsbereich'), findsOneWidget);
      expect(find.text('5. Stornierung'), findsOneWidget);
    });
  });

  group('AdminSettingsView', () {
    testWidgets('edit and save passes the parsed threshold', (tester) async {
      phone(tester, h: 3000);
      int? saved;
      await pumpApp(
        tester,
        app(adminView(onSave: (v) async => saved = v)),
      );
      await tester.enterText(find.byKey(const Key('threshold-field')), '550');
      await tester.tap(find.text('Speichern'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(saved, 550);
    });

    testWidgets('invalid threshold is rejected without saving', (tester) async {
      phone(tester, h: 3000);
      int? saved;
      await pumpApp(
        tester,
        app(adminView(onSave: (v) async => saved = v)),
      );
      await tester.enterText(find.byKey(const Key('threshold-field')), '0');
      await tester.tap(find.text('Speichern'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(saved, isNull);
      expect(find.text('Bitte eine gültige Entfernung eingeben'), findsOneWidget);
    });
  });

  group('no overflow at 360 px / text scale 1.3', () {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      ThemeData theme() => dark ? AppTheme.dark() : AppTheme.light();

      testWidgets('settings ($mode)', (tester) async {
        phone(tester, h: 4000);
        await pumpApp(
          tester,
          app(
            view(
              isAdmin: true,
              canManageUsers: true,
              microsoft: const Text('ms'),
              company: const AppSettings(),
            ),
            theme: theme(),
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('legal privacy ($mode)', (tester) async {
        phone(tester, h: 6000);
        await pumpApp(
          tester,
          app(
            const LegalInfoScreen(type: LegalInfoType.privacy),
            theme: theme(),
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('legal terms ($mode)', (tester) async {
        phone(tester, h: 6000);
        await pumpApp(
          tester,
          app(
            const LegalInfoScreen(type: LegalInfoType.terms),
            theme: theme(),
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('admin settings ($mode)', (tester) async {
        phone(tester, h: 4000);
        await pumpApp(
          tester,
          app(
            adminView(
              enrichStatus: const AdminStatus('Alle Rezepte fertig', false),
            ),
            theme: theme(),
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
