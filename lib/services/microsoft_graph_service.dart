import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// JavaScript interop declarations for MSAL.js.
@JS('msalAcquireToken')
external JSPromise<JSString> _acquireToken(String scope);

@JS('msalLogin')
external JSPromise<JSString> _msalLogin();

@JS('msalLogout')
external JSPromise<JSAny?> _msalLogout();

@JS('msalGetAccount')
external JSString? _msalGetAccount();

@JS('msalIsConfigured')
external JSBoolean _msalIsConfigured();

@JS('msalSetClientId')
external JSBoolean _msalSetClientId(String clientId, String? tenantId);

@JS('msalGetClientId')
external JSString? _msalGetClientId();

@JS('msalClearClientId')
external JSBoolean _msalClearClientId();

/// Account info returned from MSAL.
class MicrosoftAccount {
  final String name;
  final String email;

  MicrosoftAccount({required this.name, required this.email});

  factory MicrosoftAccount.fromJson(Map<String, dynamic> json) {
    return MicrosoftAccount(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

/// Service for Microsoft Graph API: OneDrive file upload and Outlook calendar.
/// Requires MSAL.js to be loaded and configured in web/index.html.
class MicrosoftGraphService {
  static const _graphBaseUrl = 'https://graph.microsoft.com/v1.0';
  static const _oneDriveScope = 'Files.ReadWrite';
  static const _calendarScope = 'Calendars.ReadWrite';

  static final MicrosoftGraphService _instance =
      MicrosoftGraphService._internal();
  factory MicrosoftGraphService() => _instance;
  MicrosoftGraphService._internal();

  bool get isSupported => kIsWeb;

  /// Check if MSAL is configured (client ID set).
  bool get isConfigured {
    if (!kIsWeb) return false;
    try {
      return _msalIsConfigured().toDart;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is logged in to Microsoft.
  bool get isLoggedIn {
    if (!kIsWeb) return false;
    try {
      return _msalGetAccount() != null;
    } catch (e) {
      return false;
    }
  }

  /// Get the current Client ID (null if not configured).
  String? getClientId() {
    if (!kIsWeb) return null;
    try {
      return _msalGetClientId()?.toDart;
    } catch (e) {
      return null;
    }
  }

  /// Set the Client ID. Requires page reload to take effect.
  bool setClientId(String clientId, {String? tenantId}) {
    if (!kIsWeb) return false;
    try {
      return _msalSetClientId(clientId, tenantId).toDart;
    } catch (e) {
      debugPrint('Failed to set Client ID: $e');
      return false;
    }
  }

  /// Clear the Client ID from localStorage. Requires page reload.
  bool clearClientId() {
    if (!kIsWeb) return false;
    try {
      return _msalClearClientId().toDart;
    } catch (e) {
      debugPrint('Failed to clear Client ID: $e');
      return false;
    }
  }

  /// Get the current logged-in Microsoft account info.
  MicrosoftAccount? getAccount() {
    if (!kIsWeb) return null;
    try {
      final accountJson = _msalGetAccount();
      if (accountJson == null) return null;
      final data = jsonDecode(accountJson.toDart) as Map<String, dynamic>;
      return MicrosoftAccount.fromJson(data);
    } catch (e) {
      debugPrint('Failed to get Microsoft account: $e');
      return null;
    }
  }

  /// Login to Microsoft account via popup.
  Future<MicrosoftAccount?> login() async {
    if (!kIsWeb) return null;
    try {
      final result = await _msalLogin().toDart;
      final data = jsonDecode(result.toDart) as Map<String, dynamic>;
      return MicrosoftAccount.fromJson(data);
    } catch (e) {
      debugPrint('Microsoft login failed: $e');
      return null;
    }
  }

  /// Logout from Microsoft account.
  Future<void> logout() async {
    if (!kIsWeb) return;
    try {
      await _msalLogout().toDart;
    } catch (e) {
      debugPrint('Microsoft logout failed: $e');
    }
  }

  /// Acquire an access token for the given scope.
  Future<String?> _getToken(String scope) async {
    if (!kIsWeb) return null;
    try {
      final result = await _acquireToken(scope).toDart;
      return result.toDart;
    } catch (e) {
      debugPrint('MSAL token acquisition failed: $e');
      return null;
    }
  }

  /// Upload [bytes] to OneDrive at [oneDrivePath] (e.g. "Aufträge/2026/05 Mai/Auftrag_Foo.pdf").
  /// Creates folders automatically if they don't exist.
  /// Returns the web URL of the uploaded file, or null on failure.
  Future<String?> uploadToOneDrive({
    required String oneDrivePath,
    required Uint8List bytes,
    String contentType = 'application/pdf',
  }) async {
    if (!kIsWeb) return null;
    final token = await _getToken(_oneDriveScope);
    if (token == null) return null;

    try {
      // Use the simple upload endpoint (≤4 MB) with createUploadSession fallback path
      final encodedPath = Uri.encodeFull(oneDrivePath);
      final url = Uri.parse(
          '$_graphBaseUrl/me/drive/root:/$encodedPath:/content');
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': contentType,
        },
        body: bytes,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('OneDrive upload success: $oneDrivePath');
        // Parse response to get web URL
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data['webUrl'] as String?;
        } catch (_) {
          return 'https://onedrive.live.com'; // Fallback URL
        }
      }
      debugPrint('OneDrive upload failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('OneDrive upload error: $e');
      return null;
    }
  }

  /// Create an Outlook calendar event.
  /// Returns the event ID on success, null on failure.
  Future<String?> createCalendarEvent({
    required String subject,
    required DateTime start,
    required DateTime end,
    required String bodyContent,
  }) async {
    if (!kIsWeb) return null;
    final token = await _getToken(_calendarScope);
    if (token == null) return null;

    try {
      final url = Uri.parse('$_graphBaseUrl/me/events');
      final payload = jsonEncode({
        'subject': subject,
        'body': {'contentType': 'Text', 'content': bodyContent},
        'start': {
          'dateTime': start.toIso8601String(),
          'timeZone': 'Europe/Zurich',
        },
        'end': {
          'dateTime': end.toIso8601String(),
          'timeZone': 'Europe/Zurich',
        },
      });
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: payload,
      );
      if (response.statusCode == 201) {
        debugPrint('Calendar event created: $subject');
        // Parse event ID from response
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data['id'] as String?;
        } catch (_) {
          return 'unknown';
        }
      }
      debugPrint('Calendar event failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Calendar event error: $e');
      return null;
    }
  }

  /// Add a file attachment to a calendar event.
  Future<bool> addCalendarAttachment({
    required String eventId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/pdf',
  }) async {
    if (!kIsWeb) return false;
    final token = await _getToken(_calendarScope);
    if (token == null) return false;

    try {
      final url = Uri.parse('$_graphBaseUrl/me/events/$eventId/attachments');
      final base64Content = base64Encode(bytes);
      final payload = jsonEncode({
        '@odata.type': '#microsoft.graph.fileAttachment',
        'name': fileName,
        'contentType': contentType,
        'contentBytes': base64Content,
      });
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: payload,
      );
      if (response.statusCode == 201) {
        debugPrint('Attachment added: $fileName');
        return true;
      }
      debugPrint('Attachment failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Attachment error: $e');
      return false;
    }
  }

  /// Build the OneDrive folder path for a given document type and date.
  /// E.g. type="Aufträge", date=2026-05-12 → "Aufträge/2026/05 Mai/Auftrag_Foo.pdf"
  static String buildOneDrivePath({
    required String rootFolder,
    required DateTime date,
    required String fileName,
  }) {
    final year = date.year.toString();
    final month = _monthFolder(date.month);
    return '$rootFolder/$year/$month/$fileName';
  }

  static String _monthFolder(int month) {
    const months = [
      '01 Januar', '02 Februar', '03 März', '04 April',
      '05 Mai', '06 Juni', '07 Juli', '08 August',
      '09 September', '10 Oktober', '11 November', '12 Dezember',
    ];
    return months[month - 1];
  }
}

final microsoftGraphService = MicrosoftGraphService();
