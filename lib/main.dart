import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'data/settings_repository.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;
import 'services/microsoft_graph_service.dart';
import 'services/user_preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs (removes # from URLs)
  usePathUrlStrategy();

  // Initialize user preferences
  await userPreferencesService.initialize();

  // Initialize Firebase
  try {
    const String flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    final firebaseOptions = flavor == 'prod'
        ? prod.DefaultFirebaseOptions.currentPlatform
        : dev.DefaultFirebaseOptions.currentPlatform;

    await Firebase.initializeApp(options: firebaseOptions);
    // Wait for initial auth state to be determined (important for page reload)
    await FirebaseAuth.instance.authStateChanges().first;

    // Load settings and sync Microsoft Client ID to localStorage
    await _syncMicrosoftSettings();
  } catch (e) {
    // Firebase initialization failed - app will use local JSON fallback
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize localization
  try {
    await EasyLocalization.ensureInitialized();
  } catch (e) {
    debugPrint('EasyLocalization initialization failed: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('de'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('de'),
      child: const CocktailPlanerApp(),
    ),
  );
}

/// Syncs Microsoft Client ID from Firestore to localStorage.
/// This ensures MSAL can read the config synchronously on page reload.
Future<void> _syncMicrosoftSettings() async {
  try {
    final settings = await settingsRepository.load();
    if (settings.microsoftClientId != null &&
        settings.microsoftClientId!.isNotEmpty) {
      // Sync to localStorage (MSAL reads this synchronously)
      final currentClientId = microsoftGraphService.getClientId();
      if (currentClientId != settings.microsoftClientId) {
        microsoftGraphService.setClientId(
          settings.microsoftClientId!,
          tenantId: settings.microsoftTenantId,
        );
        // Page will need reload for MSAL to pick up new config
        debugPrint('Microsoft Client ID synced from Firestore');
      }
    }
  } catch (e) {
    debugPrint('Failed to sync Microsoft settings: $e');
  }
}
