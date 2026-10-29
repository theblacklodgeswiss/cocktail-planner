import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/claude_service.dart';
import 'firestore_service.dart';

/// Repository for app settings, backed by Firestore.
class SettingsRepository {
  static const _settingsDocId = 'appSettings';

  AppSettings _cachedSettings = const AppSettings();

  Future<void> _ready = Future<void>.value();

  /// Registers the app-start settings load so consumers that read [current]
  /// synchronously (settings screen, PDF builders) can wait for it via
  /// [awaitReady]. Defaults to already-ready when nothing is registered.
  void trackReady(Future<void> loading) => _ready = loading;

  /// Waits until the tracked startup load finished, at most [timeout]; errors
  /// and timeouts fall back to the cached/default settings (old behaviour).
  Future<void> awaitReady({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      await _ready.timeout(timeout);
    } catch (e) {
      debugPrint('Settings not ready, continuing with cached settings: $e');
    }
  }

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
      
      // Initialize Claude if API key is configured in Firestore (overrides dart-define)
      if (_cachedSettings.anthropicApiKey != null && _cachedSettings.anthropicApiKey!.isNotEmpty) {
        claudeService.setApiKey(_cachedSettings.anthropicApiKey!);
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
