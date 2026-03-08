import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Translation Files', () {
    late Map<String, dynamic> deTranslations;
    late Map<String, dynamic> enTranslations;

    setUpAll(() {
      final deFile = File('assets/translations/de.json');
      final enFile = File('assets/translations/en.json');

      deTranslations = jsonDecode(deFile.readAsStringSync()) as Map<String, dynamic>;
      enTranslations = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('both translation files exist', () {
      expect(File('assets/translations/de.json').existsSync(), true);
      expect(File('assets/translations/en.json').existsSync(), true);
    });

    test('de.json and en.json have same top-level keys', () {
      final deKeys = deTranslations.keys.toSet();
      final enKeys = enTranslations.keys.toSet();

      final missingInEn = deKeys.difference(enKeys);
      final missingInDe = enKeys.difference(deKeys);

      expect(missingInEn, isEmpty,
          reason: 'Keys missing in en.json: $missingInEn');
      expect(missingInDe, isEmpty,
          reason: 'Keys missing in de.json: $missingInDe');
    });

    test('dashboard section has all required keys', () {
      final requiredKeys = [
        'title',
        'year',
        'pending_confirmations',
        'open_offers',
        'accepted_orders',
        'pending_count',
        'offers_count',
        'orders_count',
        'section_orders',
        'section_actions',
        'nav_pending',
        'nav_offers',
        'nav_accepted',
        'action_all_orders',
        'action_all_orders_subtitle',
        'action_admin',
        'action_admin_subtitle',
        'new_order',
      ];

      final deDashboard = deTranslations['dashboard'] as Map<String, dynamic>?;
      final enDashboard = enTranslations['dashboard'] as Map<String, dynamic>?;

      expect(deDashboard, isNotNull, reason: 'dashboard section missing in de.json');
      expect(enDashboard, isNotNull, reason: 'dashboard section missing in en.json');

      for (final key in requiredKeys) {
        expect(deDashboard!.containsKey(key), true,
            reason: 'dashboard.$key missing in de.json');
        expect(enDashboard!.containsKey(key), true,
            reason: 'dashboard.$key missing in en.json');
      }
    });

    test('common section has essential keys', () {
      final requiredKeys = [
        'cancel',
        'ok',
        'save',
        'delete',
        'edit',
        'back',
        'next',
        'finish',
        'error',
        'close',
      ];

      final deCommon = deTranslations['common'] as Map<String, dynamic>?;
      final enCommon = enTranslations['common'] as Map<String, dynamic>?;

      expect(deCommon, isNotNull);
      expect(enCommon, isNotNull);

      for (final key in requiredKeys) {
        expect(deCommon!.containsKey(key), true,
            reason: 'common.$key missing in de.json');
        expect(enCommon!.containsKey(key), true,
            reason: 'common.$key missing in en.json');
      }
    });

    test('orders section has essential keys', () {
      final requiredKeys = [
        'title',
        'status_quote',
        'status_accepted',
        'status_declined',
        'no_orders',
      ];

      final deOrders = deTranslations['orders'] as Map<String, dynamic>?;
      final enOrders = enTranslations['orders'] as Map<String, dynamic>?;

      expect(deOrders, isNotNull);
      expect(enOrders, isNotNull);

      for (final key in requiredKeys) {
        expect(deOrders!.containsKey(key), true,
            reason: 'orders.$key missing in de.json');
        expect(enOrders!.containsKey(key), true,
            reason: 'orders.$key missing in en.json');
      }
    });

    test('no empty translation values', () {
      void checkEmptyValues(Map<String, dynamic> map, String prefix) {
        for (final entry in map.entries) {
          final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
          final value = entry.value;

          if (value is String) {
            expect(value.trim(), isNotEmpty,
                reason: 'Empty translation value at $key');
          } else if (value is Map<String, dynamic>) {
            checkEmptyValues(value, key);
          }
        }
      }

      checkEmptyValues(deTranslations, '');
      checkEmptyValues(enTranslations, '');
    });

    test('placeholder syntax is consistent between languages', () {
      void checkPlaceholders(
          Map<String, dynamic> deMap,
          Map<String, dynamic> enMap,
          String prefix) {
        for (final key in deMap.keys) {
          final dePath = prefix.isEmpty ? key : '$prefix.$key';
          final deValue = deMap[key];
          final enValue = enMap[key];

          if (deValue is String && enValue is String) {
            // Check for {} placeholders
            final dePlaceholders = RegExp(r'\{[^}]*\}')
                .allMatches(deValue)
                .map((m) => m.group(0))
                .toSet();
            final enPlaceholders = RegExp(r'\{[^}]*\}')
                .allMatches(enValue)
                .map((m) => m.group(0))
                .toSet();

            expect(dePlaceholders, equals(enPlaceholders),
                reason:
                    'Placeholder mismatch at $dePath: DE has $dePlaceholders, EN has $enPlaceholders');
          } else if (deValue is Map<String, dynamic> &&
              enValue is Map<String, dynamic>) {
            checkPlaceholders(deValue, enValue, dePath);
          }
        }
      }

      checkPlaceholders(deTranslations, enTranslations, '');
    });

    test('German translations use correct umlauts', () {
      // Check that common words use proper German spelling
      final dashboardSection = deTranslations['dashboard'] as Map<String, dynamic>;
      
      // "Aufträge" should have umlaut, not "Auftrage"
      expect(dashboardSection['accepted_orders'], contains('Aufträge'));
      expect(dashboardSection['orders_count'], contains('Aufträge'));
      
      // "Übersicht" should have umlaut
      expect(dashboardSection['action_all_orders_subtitle'], contains('Übersicht'));
    });
  });
}
