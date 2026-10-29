import 'package:cocktail_planer/services/user_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stockAiEnabled defaults to true', () async {
    SharedPreferences.setMockInitialValues({});
    final s = UserPreferencesService();
    await s.initialize();
    expect(s.stockAiEnabled, isTrue);
  });

  test('stockAiEnabled is persisted and read back', () async {
    SharedPreferences.setMockInitialValues({});
    final s = UserPreferencesService();
    await s.initialize();
    await s.setStockAiEnabled(false);
    expect(s.stockAiEnabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('stockAiEnabled'), isFalse);

    final again = UserPreferencesService();
    await again.initialize();
    expect(again.stockAiEnabled, isFalse);
  });

  test('a stored value of another type falls back to true', () async {
    SharedPreferences.setMockInitialValues({'stockAiEnabled': 'nope'});
    final s = UserPreferencesService();
    await s.initialize();
    expect(s.stockAiEnabled, isTrue);
  });
}
