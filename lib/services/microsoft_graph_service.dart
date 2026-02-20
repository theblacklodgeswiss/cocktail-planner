import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// JavaScript interop declarations for MSAL.js.
@JS('msalInstance')
external JSObject? get _msalInstance;

@JS('msalAcquireToken')
external JSPromise<JSString> _acquireToken(String scope);

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
  Future<bool> uploadToOneDrive({
    required String oneDrivePath,
    required Uint8List bytes,
    String contentType = 'application/pdf',
  }) async {
    if (!kIsWeb) return false;
    final token = await _getToken(_oneDriveScope);
    if (token == null) return false;

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
        return true;
      }
      debugPrint('OneDrive upload failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('OneDrive upload error: $e');
      return false;
    }
  }

  /// Create an Outlook calendar event.
  Future<bool> createCalendarEvent({
    required String subject,
    required DateTime start,
    required DateTime end,
    required String bodyContent,
  }) async {
    if (!kIsWeb) return false;
    final token = await _getToken(_calendarScope);
    if (token == null) return false;

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
        return true;
      }
      debugPrint('Calendar event failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Calendar event error: $e');
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
