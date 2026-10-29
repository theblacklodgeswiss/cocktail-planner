import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, Settings;
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

/// Startup stopwatch; timing logs are plain debugPrint calls (cheap, and read
/// from the browser console).
final Stopwatch _startup = Stopwatch();

void _logTiming(String label) =>
    debugPrint('⏱ startup +${_startup.elapsedMilliseconds}ms $label');

/// Completes when the Microsoft settings have been synced to localStorage
/// (runs in the background after runApp; see [_syncMicrosoftSettings]).
Future<void> microsoftSettingsSynced = Future<void>.value();

Future<void> main() async {
  _startup.start();
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs (removes # from URLs)
  usePathUrlStrategy();

  // Local work, independent of Firebase: start right away, await with the rest.
  final prefsFuture = userPreferencesService.initialize();
  final localeFuture = () async {
    try {
      await EasyLocalization.ensureInitialized();
    } catch (e) {
      debugPrint('EasyLocalization initialization failed: $e');
    }
  }();

  String? defaultMicrosoftClientId;
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
    defaultMicrosoftClientId = googleClientId.contains('-')
        ? dev.DefaultFirebaseOptions.microsoftClientId
        : prod.DefaultFirebaseOptions.microsoftClientId;

    debugPrint('🔧 Firebase Project: ${firebaseOptions.projectId}');
    await Firebase.initializeApp(options: firebaseOptions);
    debugPrint('✅ Firebase initialized successfully');
    _logTiming('firebase initialized');

    // Firestore on the web: detect when WebChannel streaming is blocked or
    // buffered (some iOS Safari, proxy or VPN setups) and fall back to long
    // polling instead of hanging until the request times out ('keine
    // Antwort vom Server'). Must be set before the first Firestore use.
    FirebaseFirestore.instance.settings = const Settings(
      webExperimentalAutoDetectLongPolling: true,
    );

    // Initialize Auth Service with environment specific client ID
    authService.initialize(googleClientId: googleClientId);

    // The Firestore connection test runs in the background: isAvailable is
    // optimistic until it completes, then reflects the real result (local
    // fallback semantics unchanged).
    unawaited(
      firestoreService.startBackgroundCheck().then(
        (ok) => _logTiming('firestore connection test done (available=$ok)'),
      ),
    );

    // Wait for initial auth state to be determined (important for page reload)
    final user = await FirebaseAuth.instance.authStateChanges().first;
    debugPrint('👤 Initial auth state: ${user?.email ?? "Not signed in"}');
    _logTiming('auth state resolved');

    // Settings load + MS sync: off the critical path, but awaitable via
    // settingsRepository.awaitReady() (settings screen, PDF builders).
    microsoftSettingsSynced = _syncMicrosoftSettings(
      defaultClientId: defaultMicrosoftClientId,
    );
    settingsRepository.trackReady(microsoftSettingsSynced);
  } catch (e) {
    // Firebase initialization failed - app will use local JSON fallback
    debugPrint('❌ Firebase initialization failed: $e');
  }

  await Future.wait([prefsFuture, localeFuture]);
  _logTiming('prefs + locale ready, calling runApp');

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('de'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('de'),
      child: const CocktailPlanerApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _logTiming('first frame');
  });
}

/// Syncs Microsoft Client ID from Firestore to localStorage.
/// MSAL (web/msal_config.js) reads the stored client id once at script load,
/// and Dart only ever writes it for the NEXT page load (no Dart code
/// initializes MSAL), so running this after runApp cannot change ordering.
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
