import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/dashboard/customer_start.dart';
import 'package:cocktail_planer/screens/dashboard/link_google.dart';
import 'package:cocktail_planer/ui/tokens.dart';
import 'package:cocktail_planer/ui/widgets/glass_icon_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cocktail_planer/screens/dashboard/widgets/my_requests_list.dart';
import 'package:cocktail_planer/screens/forms/order_success_screen.dart';
import 'package:cocktail_planer/screens/login_screen.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real German translations behind a GoRouter, wired like lib/app.dart.
Widget app(Widget home, {ThemeData? theme, double textScale = 1}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      for (final path in ['/order-form', '/my-requests', '/settings'])
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text('page $path')),
        ),
    ],
  );
  return EasyLocalization(
    supportedLocales: const [Locale('de'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('de'),
    startLocale: const Locale('de'),
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

  group('CustomerStart', () {
    testWidgets('fits 360x640 and the CTA opens the order form', (
      tester,
    ) async {
      phone(tester);
      await pumpApp(
        tester,
        app(CustomerStart(signedIn: false, onOpenRequest: (_) {})),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Deine Bar. Dein Abend.'), findsOneWidget);
      final cta = find.text('Anfrage starten');
      expect(cta, findsOneWidget);
      final rect = tester.getRect(cta);
      expect(rect.bottom, lessThanOrEqualTo(640));
      expect(rect.top, greaterThanOrEqualTo(0));

      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(find.text('page /order-form'), findsOneWidget);
    });

    testWidgets('guest sees the sign-in hint and no list', (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        app(CustomerStart(signedIn: false, onOpenRequest: (_) {})),
      );

      expect(
        find.text('Melde dich an, um deine Anfragen zu sehen'),
        findsOneWidget,
      );
      expect(find.text('Mit Google verknüpfen'), findsOneWidget);
      expect(find.byType(MyRequestsList), findsNothing);
    });

    testWidgets('signed-in user sees the list and no hint', (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        app(
          CustomerStart(
            signedIn: true,
            onOpenRequest: (_) {},
            orders: Stream<List<SavedOrder>>.value(const []),
          ),
        ),
      );

      expect(find.byType(MyRequestsList), findsOneWidget);
      expect(find.text('Meine Anfragen'), findsOneWidget);
      expect(
        find.text('Melde dich an, um deine Anfragen zu sehen'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    for (final dark in [false, true]) {
      for (final signedIn in [false, true]) {
        testWidgets(
          'fits at text scale 1.3 with CTA visible (dark: $dark, signed in: $signedIn)',
          (tester) async {
            phone(tester);
            await pumpApp(
              tester,
              app(
                CustomerStart(
                  signedIn: signedIn,
                  onOpenRequest: (_) {},
                  orders: signedIn
                      ? Stream<List<SavedOrder>>.value(const [])
                      : null,
                ),
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                textScale: 1.3,
              ),
            );

            expect(tester.takeException(), isNull);
            final rect = tester.getRect(find.text('Anfrage starten'));
            expect(rect.bottom, lessThanOrEqualTo(640));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(360));
          },
        );
      }
    }

    testWidgets('settings action opens /settings', (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        app(CustomerStart(signedIn: false, onOpenRequest: (_) {})),
      );
      await tester.tap(find.bySemanticsLabel('Einstellungen'));
      await tester.pumpAndSettle();
      expect(find.text('page /settings'), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    for (final dark in [false, true]) {
      testWidgets('shows both buttons without overflow (dark: $dark)', (
        tester,
      ) async {
        phone(tester);
        await pumpApp(
          tester,
          app(
            const LoginScreen(),
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            textScale: 1.3,
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Mit Google anmelden'), findsOneWidget);
        expect(find.text('Als Gast fortfahren'), findsOneWidget);
      });
    }
  });

  group('OrderSuccessScreen', () {
    testWidgets('guest sees the thanks and a way back', (tester) async {
      phone(tester);
      await pumpApp(tester, app(const OrderSuccessScreen(signedIn: false)));

      expect(tester.takeException(), isNull);
      expect(find.text('Vielen Dank!'), findsOneWidget);
      expect(find.text('Zurück zur Startseite'), findsOneWidget);
    });

    testWidgets('signed-in user is pointed to My Requests', (tester) async {
      phone(tester);
      await pumpApp(tester, app(const OrderSuccessScreen(signedIn: true)));

      await tester.tap(find.text('Meine Anfragen'));
      await tester.pumpAndSettle();
      expect(find.text('page /my-requests'), findsOneWidget);
    });
  });

  group('linkGoogleAccount', () {
    Future<void> run(
      WidgetTester tester,
      Future<UserCredential?> Function() link,
    ) async {
      phone(tester);
      late BuildContext ctx;
      await pumpApp(
        tester,
        app(
          Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold();
            },
          ),
        ),
      );
      await linkGoogleAccount(ScaffoldMessenger.of(ctx), link: link);
      await tester.pump();
    }

    testWidgets('shows the error text when linking throws', (tester) async {
      await run(tester, () async => throw Exception('boom'));
      expect(find.textContaining('Fehler: '), findsOneWidget);
    });

    testWidgets('shows nothing when the dialog is cancelled', (tester) async {
      await run(tester, () async => null);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('ui helpers', () {
    testWidgets('GlassIconButton has a 44 px target and calls onPressed', (
      tester,
    ) async {
      phone(tester);
      var taps = 0;
      await pumpApp(
        tester,
        app(
          Scaffold(
            body: Center(
              child: GlassIconButton(
                icon: Icons.settings,
                semanticLabel: 'x',
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(GlassIconButton));
      expect(size.width, greaterThanOrEqualTo(AppSize.minTap));
      expect(size.height, greaterThanOrEqualTo(AppSize.minTap));
      await tester.tap(find.byType(GlassIconButton));
      expect(taps, 1);
    });

    testWidgets('AppPalette.goldText follows brightness', (tester) async {
      late AppPalette light;
      late AppPalette dark;
      for (final isDark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? AppTheme.dark() : AppTheme.light(),
            home: Builder(
              builder: (c) {
                if (isDark) {
                  dark = AppPalette.of(c);
                } else {
                  light = AppPalette.of(c);
                }
                return const SizedBox();
              },
            ),
          ),
        );
        // Theme changes animate; let the dark theme settle.
        await tester.pumpAndSettle();
      }
      expect(light.goldText, AppColors.goldOnWhite);
      expect(dark.goldText, AppColors.goldOnBlack);
    });
  });
}
