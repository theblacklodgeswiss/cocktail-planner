import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/gemini_service.dart';
import 'firestore_service.dart';

/// Repository for app settings, backed by Firestore.
class SettingsRepository {
  static const _settingsDocId = 'appSettings';

  AppSettings _cachedSettings = const AppSettings();

  /// Current cached settings.
  AppSettings get current => _cachedSettings;

  /// Loads settings from Firestore. Creates default if not exists.
  Future<AppSettings> load() async {
    if (!firestoreService.isAvailable) {
      return _cachedSettings;
    }

    try {
      final doc = await firestoreService.settingsCollection.doc(_settingsDocId).get();
      if (doc.exists && doc.data() != null) {
        _cachedSettings = AppSettings.fromJson(doc.data()!);
      } else {
        // Create default settings
        await save(_cachedSettings);
      }
      
      // Initialize Gemini if API key is configured
      if (_cachedSettings.geminiApiKey != null && _cachedSettings.geminiApiKey!.isNotEmpty) {
        geminiService.setApiKey(_cachedSettings.geminiApiKey!);
      }
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
    return _cachedSettings;
  }

  /// Saves settings to Firestore.
  Future<void> save(AppSettings settings) async {
    _cachedSettings = settings;

    if (!firestoreService.isAvailable) {
      return;
    }

    try {
      await firestoreService.settingsCollection
          .doc(_settingsDocId)
          .set(settings.toJson());
    } catch (e) {
      debugPrint('Failed to save settings: $e');
      rethrow;
    }
  }
}

final settingsRepository = SettingsRepository();
