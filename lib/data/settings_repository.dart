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

  /// Waits until the tracked startup load finished, at most [timeout].
  /// Returns true if it completed without error, false on timeout/error. Note
  /// a completed load can still have failed internally: gate writes on
  /// [currentIsAuthoritative], never on this result alone.
  Future<bool> awaitReady({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      await _ready.timeout(timeout);
      return true;
    } catch (e) {
      debugPrint('Settings not ready, continuing with cached settings: $e');
      return false;
    }
  }

  bool _authoritative = false;

  /// True only after settings were successfully read from (or created in)
  /// Firestore. While false, [current] may be plain defaults and must never be
  /// used as the base of a [save].
  bool get currentIsAuthoritative => _authoritative;

  /// Test seam: replaces the Firestore document read (null = doc missing).
  @visibleForTesting
  Future<Map<String, dynamic>?> Function()? fetchOverride;

  /// Returns true if [current] is authoritative, performing a direct [load]
  /// (no timeout of its own) when the startup load did not deliver that.
  Future<bool> ensureLoaded() async {
    if (_authoritative) return true;
    await load();
    return _authoritative;
  }

  /// Current cached settings.
  AppSettings get current => _cachedSettings;

  /// Loads settings from Firestore. Creates default if not exists.
  Future<AppSettings> load() async {
    if (fetchOverride == null && !firestoreService.isAvailable) {
      return _cachedSettings;
    }

    try {
      final Map<String, dynamic>? data;
      if (fetchOverride != null) {
        data = await fetchOverride!();
      } else {
        final doc = await firestoreService.settingsCollection
            .doc(_settingsDocId)
            .get();
        data = doc.exists ? doc.data() : null;
      }
      if (data != null) {
        _cachedSettings = AppSettings.fromJson(data);
      } else {
        // Create default settings
        await save(_cachedSettings);
      }
      _authoritative = true;
      
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
