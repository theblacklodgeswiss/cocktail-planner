import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/cocktail_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Sign in anonymously (with error handling)
    await _signInAnonymously();
    
    // Initialize data in Firestore (seeds if not exists)
    await cocktailRepository.initialize();
  } catch (e) {
    // Firebase initialization failed - app will use local JSON fallback
    debugPrint('Firebase initialization failed: $e');
  }
  
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('de'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('de'),
      child: const CocktailPlannerApp(),
    ),
  );
}

Future<void> _signInAnonymously() async {
  try {
    final auth = FirebaseAuth.instance;
    
    // Check if already signed in
    if (auth.currentUser != null) {
      return;
    }
    
    // Sign in anonymously
    await auth.signInAnonymously();
  } catch (e) {
    debugPrint('Anonymous sign-in failed: $e');
    rethrow;
  }
}

