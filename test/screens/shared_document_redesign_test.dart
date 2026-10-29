import 'dart:async';
import 'dart:typed_data';

import 'package:cocktail_planer/data/share_link_repository.dart';
import 'package:cocktail_planer/models/offer.dart';
import 'package:cocktail_planer/screens/share/shared_document_screen.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/ui/widgets/glass_cta_bar.dart';
import 'package:cocktail_planer/ui/widgets/states.dart';
import 'package:cocktail_planer/ui/widgets/status_dot.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRepo implements ShareLinkRepository {
  FakeRepo(this.result);
  final ShareLinkResult result;
  final calls = <String>[];
  bool failRespond = false;
  Completer<void>? gate;

  @override
  Future<ShareLinkResult> fetchShareLink(String code) async => result;

  @override
  Future<void> respondToOffer({
    required String orderId,
    required String code,
    required bool accepted,
  }) async {
    calls.add('respond:$orderId:${accepted ? 'accepted' : 'declined'}');
    await gate?.future;
    if (failRespond) throw Exception('denied');
  }

  @override
  Future<bool> recoverLinkResponse({
    required String code,
    required bool accepted,
  }) async {
    calls.add('recover');
    return false;
  }

  @override
  Future<String> createOfferShareLink(
    OfferData offer, {
    required String orderId,
    required List<String> bullets,
  }) => throw UnimplementedError();

  @override
  Future<String> createInvoiceShareLink(order) => throw UnimplementedError();
}

OfferData offer() => OfferData(
  orderName: 'Sommerfest',
  eventDate: DateTime(2026, 8, 15),
  eventTime: '18:00',
  currency: 'EUR',
  guestCount: 40,
  editorName: 'Mario',
  clientName: 'Kunde',
  clientContact: '',
  eventTypes: {EventType.wedding},
  cocktails: const ['Mojito'],
  shots: const [],
  barDescription: '',
  orderTotal: 0,
  distanceKm: 0,
  travelCostPerKm: 0.7,
  barCost: 0,
  discount: 30,
  additionalInfo: '',
  language: 'de',
  eventLocation: 'Basel',
  offerPositions: const [
    ExtraPosition(name: 'Cocktailservice', price: 150, quantity: 2),
    ExtraPosition(name: 'Anfahrt', price: 80),
  ],
);

ShareLinkResult offerResult({String? response}) => ShareLinkResult.found(
  type: 'offer',
  snapshot: offer().toJson(),
  orderId: 'o1',
  bullets: const ['Hallo!'],
  response: response,
);

Widget app(
  FakeRepo repo, {
  ThemeData? theme,
  double textScale = 1,
  Future<Uint8List> Function(ShareLinkResult)? pdfBuilder,
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
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: SharedDocumentScreen(
          code: 'abc12345',
          repository: repo,
          pdfBuilder: pdfBuilder ?? (_) async => Uint8List(0),
        ),
      ),
    ),
  );
}

Future<void> pumpApp(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

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

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('summary shows the PDF total, date, position names', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(tester, app(FakeRepo(offerResult())));
    expect(tester.takeException(), isNull);
    expect(find.text('BlackLodge'), findsOneWidget);
    // Same value and format as the PDF total row: curr.format(grandTotal).
    expect(find.text('350.00 EUR'), findsOneWidget);
    expect(find.textContaining('15.08.2026'), findsWidgets);
    expect(find.text('Cocktailservice'), findsOneWidget);
    expect(find.text('Anfahrt'), findsOneWidget);
    expect(find.text('Angebot ansehen'), findsOneWidget);
    expect(find.text('Hallo!'), findsOneWidget);
  });

  testWidgets('accept asks first and responds only after confirming', (
    tester,
  ) async {
    phone(tester);
    final repo = FakeRepo(offerResult());
    await pumpApp(tester, app(repo));
    expect(find.byType(GlassCtaBar), findsOneWidget);

    await tester.tap(find.text('Annehmen'));
    await settle(tester);
    expect(repo.calls, isEmpty);
    expect(find.text('Angebot annehmen?'), findsOneWidget);
    expect(
      tester
          .widgetList<PrimaryButton>(find.byType(PrimaryButton))
          .every((b) => !b.destructive),
      isTrue,
    );

    await tester.tap(find.text('Annehmen').last);
    await settle(tester);
    await settle(tester);
    expect(repo.calls, ['respond:o1:accepted']);
    expect(find.byType(GlassCtaBar), findsNothing);
    expect(find.textContaining('angenommen'), findsOneWidget);
  });

  testWidgets('cancel in the confirm sheet calls nothing', (tester) async {
    phone(tester);
    final repo = FakeRepo(offerResult());
    await pumpApp(tester, app(repo));
    await tester.tap(find.text('Annehmen'));
    await settle(tester);
    await tester.tap(find.text('Abbrechen'));
    await settle(tester);
    await settle(tester);
    expect(repo.calls, isEmpty);
    expect(find.byType(GlassCtaBar), findsOneWidget);
  });

  testWidgets('decline uses a destructive confirm and then responds', (
    tester,
  ) async {
    phone(tester);
    final repo = FakeRepo(offerResult());
    await pumpApp(tester, app(repo));
    await tester.tap(find.text('Ablehnen'));
    await settle(tester);
    expect(repo.calls, isEmpty);
    expect(find.text('Angebot ablehnen?'), findsOneWidget);
    expect(
      tester
          .widgetList<PrimaryButton>(find.byType(PrimaryButton))
          .any((b) => b.destructive),
      isTrue,
    );
    await tester.tap(find.text('Ablehnen').last);
    await settle(tester);
    await settle(tester);
    expect(repo.calls, ['respond:o1:declined']);
    expect(find.textContaining('abgelehnt'), findsOneWidget);
  });

  testWidgets('failed response falls back to recover and shows a snackbar', (
    tester,
  ) async {
    phone(tester);
    final repo = FakeRepo(offerResult())..failRespond = true;
    await pumpApp(tester, app(repo));
    await tester.tap(find.text('Annehmen'));
    await settle(tester);
    await tester.tap(find.text('Annehmen').last);
    await settle(tester);
    await settle(tester);
    expect(repo.calls, ['respond:o1:accepted', 'recover']);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('already responded link shows the result instead of the bar', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(tester, app(FakeRepo(offerResult(response: 'accepted'))));
    expect(find.byType(GlassCtaBar), findsNothing);
    expect(find.textContaining('angenommen'), findsOneWidget);
  });

  testWidgets('invoice has no response bar and says Rechnung', (tester) async {
    phone(tester);
    final snap = {
      'name': 'Fest',
      'date': DateTime(2026, 9, 1).toIso8601String(),
      'currency': 'CHF',
      'total': 500.0,
      'location': 'Bern',
      'offerPositions': [
        {'name': 'Barservice', 'price': 500.0, 'quantity': 1},
      ],
    };
    await pumpApp(
      tester,
      app(
        FakeRepo(
          ShareLinkResult.found(type: 'invoice', snapshot: snap, orderId: 'o1'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(GlassCtaBar), findsNothing);
    expect(find.text('Annehmen'), findsNothing);
    expect(find.text('Ablehnen'), findsNothing);
    expect(find.text('Rechnung'), findsWidgets);
    expect(find.text('Rechnung ansehen'), findsOneWidget);
    expect(find.text('500.00 CHF'), findsWidgets);
  });

  testWidgets('not found shows the expired empty state', (tester) async {
    phone(tester);
    await pumpApp(tester, app(FakeRepo(const ShareLinkResult.notFound())));
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Link nicht mehr gültig'), findsOneWidget);
  });

  testWidgets('pdf is generated lazily and a failure shows inside the sheet', (
    tester,
  ) async {
    phone(tester);
    var built = 0;
    await pumpApp(
      tester,
      app(
        FakeRepo(offerResult()),
        pdfBuilder: (_) async {
          built++;
          throw Exception('boom');
        },
      ),
    );
    expect(built, 0);
    await tester.tap(find.text('Angebot ansehen'));
    await settle(tester);
    await settle(tester);
    expect(built, 1);
    expect(find.byType(ErrorState), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360px and text scale 1.3 (dark: $dark)', (
      tester,
    ) async {
      phone(tester);
      await pumpApp(
        tester,
        app(
          FakeRepo(offerResult()),
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Annehmen'), findsOneWidget);
    });
  }

  // Overflow matrix: invoice view, result cards and confirm sheets.
  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.dark() : AppTheme.light();
    final tag = 'dark: $dark';

    testWidgets('invoice view fits 360px at 1.3x ($tag)', (tester) async {
      phone(tester);
      final snap = {
        'name': 'Ein sehr langer Anlassname fuer die Rechnung',
        'date': DateTime(2026, 9, 1).toIso8601String(),
        'currency': 'CHF',
        'total': 500.0,
        'location': 'Basel Birkenstrasse 3',
        'offerEventTypes': ['wedding', 'company'],
        'offerPositions': [
          {'name': 'Cocktail- und Barservice Premium', 'price': 500.0},
        ],
      };
      await pumpApp(
        tester,
        app(
          FakeRepo(
            ShareLinkResult.found(
              type: 'invoice',
              snapshot: snap,
              orderId: 'o1',
            ),
          ),
          theme: theme,
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Rechnung ansehen'), findsOneWidget);
    });

    for (final response in ['accepted', 'declined']) {
      testWidgets('result card $response fits 360px at 1.3x ($tag)', (
        tester,
      ) async {
        phone(tester);
        await pumpApp(
          tester,
          app(
            FakeRepo(offerResult(response: response)),
            theme: theme,
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(GlassCtaBar), findsNothing);
        expect(find.byType(StatusDot), findsOneWidget);
      });
    }

    for (final accept in [true, false]) {
      testWidgets(
        'confirm sheet (${accept ? 'accept' : 'decline'}) fits 360px at 1.3x ($tag)',
        (tester) async {
          phone(tester);
          await pumpApp(
            tester,
            app(FakeRepo(offerResult()), theme: theme, textScale: 1.3),
          );
          await tester.tap(find.text(accept ? 'Annehmen' : 'Ablehnen'));
          await settle(tester);
          expect(
            find.text(accept ? 'Angebot annehmen?' : 'Angebot ablehnen?'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('accept button shows progress and blocks taps while responding', (
    tester,
  ) async {
    phone(tester);
    final repo = FakeRepo(offerResult())..gate = Completer<void>();
    await pumpApp(tester, app(repo));
    await tester.tap(find.text('Annehmen'));
    await settle(tester);
    await tester.tap(find.text('Annehmen').last);
    await settle(tester);
    final bar = find.byType(GlassCtaBar);
    expect(
      find.descendant(
        of: bar,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    // Taps are ignored while loading, decline is disabled too.
    await tester.tap(find.text('Annehmen'), warnIfMissed: false);
    await tester.tap(find.text('Ablehnen'), warnIfMissed: false);
    await settle(tester);
    expect(repo.calls, ['respond:o1:accepted']);
    expect(find.text('Angebot ablehnen?'), findsNothing);
    repo.gate!.complete();
    await settle(tester);
    expect(find.byType(GlassCtaBar), findsNothing);
  });
}
