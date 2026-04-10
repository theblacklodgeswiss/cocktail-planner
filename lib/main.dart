import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'data/firestore_service.dart';
import 'data/settings_repository.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;
import 'services/auth_service.dart';
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
    debugPrint('🚀 Initializing Firebase...');
    const String flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    debugPrint('📦 Flavor: $flavor');
    final googleClientId = flavor == 'prod'
        ? prod.DefaultFirebaseOptions.googleClientId
        : dev.DefaultFirebaseOptions.googleClientId;
    final firebaseOptions = flavor == 'prod'
        ? prod.DefaultFirebaseOptions.currentPlatform
        : dev.DefaultFirebaseOptions.currentPlatform;

    debugPrint('🔧 Firebase Project: ${firebaseOptions.projectId}');
    await Firebase.initializeApp(options: firebaseOptions);
    debugPrint('✅ Firebase initialized successfully');

    // Initialize Firestore connection
    await firestoreService.initialize();

    // Initialize Auth Service with environment specific client ID
    authService.initialize(googleClientId: googleClientId);
    // Wait for initial auth state to be determined (important for page reload)
    final user = await FirebaseAuth.instance.authStateChanges().first;
    debugPrint('👤 Initial auth state: ${user?.email ?? "Not signed in"}');

    // Load settings and sync Microsoft Client ID to localStorage
    await _syncMicrosoftSettings(
      defaultClientId: googleClientId.contains('-')
          ? dev.DefaultFirebaseOptions.microsoftClientId
          : prod.DefaultFirebaseOptions.microsoftClientId,
    );
  } catch (e) {
    // Firebase initialization failed - app will use local JSON fallback
    debugPrint('❌ Firebase initialization failed: $e');
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
Future<void> _syncMicrosoftSettings({String? defaultClientId}) async {
  try {
    final settings = await settingsRepository.load();
    final clientId =
        (settings.microsoftClientId != null &&
            settings.microsoftClientId!.isNotEmpty)
        ? settings.microsoftClientId
        : defaultClientId;

    if (clientId != null && clientId.isNotEmpty) {
      // Sync to localStorage (MSAL reads this synchronously)
      final currentClientId = microsoftGraphService.getClientId();
      if (currentClientId != clientId) {
        microsoftGraphService.setClientId(
          clientId,
          tenantId: settings.microsoftTenantId,
        );
        debugPrint('Microsoft Client ID synced to localStorage');
      }
    }
  } catch (e) {
    debugPrint('Failed to sync Microsoft settings: $e');
  }
}
