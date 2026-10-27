import 'package:cocktail_planer/screens/settings/admin_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_harness.dart';

AdminSettingsView settingsView({
  bool isGenerating = false,
  AdminStatus? generateStatus,
}) => AdminSettingsView(
  threshold: 400,
  claudeConfigured: true,
  microsoftLoggedIn: false,
  isImporting: false,
  onImport: () {},
  isEnriching: false,
  enrichStatus: null,
  onEnrich: () {},
  isGenerating: isGenerating,
  generateStatus: generateStatus,
  onGenerate: (_) {},
  onSave: (_) async {},
);

void main() {
  setUpAll(initAdminTest);

  group('AI recipe input', () {
    Future<ValueNotifier<AdminSettingsView>> pumpView(
      WidgetTester tester,
    ) async {
      phone(tester, h: 3000);
      final view = ValueNotifier(settingsView());
      addTearDown(view.dispose);
      await pumpAdmin(
        tester,
        adminApp(
          ValueListenableBuilder<AdminSettingsView>(
            valueListenable: view,
            builder: (_, v, _) => v,
          ),
        ),
      );
      return view;
    }

    testWidgets('is cleared after a successful generate and save', (
      tester,
    ) async {
      final view = await pumpView(tester);
      final field = find.byType(TextField).last;
      await tester.enterText(field, 'Aperol Spritz');
      view.value = settingsView(isGenerating: true);
      await tester.pump();
      view.value = settingsView(generateStatus: const AdminStatus('ok', false));
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    });

    testWidgets('is kept after an error so it can be retried', (tester) async {
      final view = await pumpView(tester);
      final field = find.byType(TextField).last;
      await tester.enterText(field, 'Aperol Spritz');
      view.value = settingsView(isGenerating: true);
      await tester.pump();
      view.value = settingsView(generateStatus: const AdminStatus('boom', true));
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'Aperol Spritz');
    });
  });
}
