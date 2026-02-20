import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use path-based URLs (removes # from URLs)
  usePathUrlStrategy();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Wait for initial auth state to be determined (important for page reload)
    await FirebaseAuth.instance.authStateChanges().first;
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
      child: const CocktailPlannerApp(),
    ),
  );
}

