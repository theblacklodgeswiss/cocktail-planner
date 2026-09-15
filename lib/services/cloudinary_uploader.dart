import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Uploads images to Cloudinary using an *unsigned* upload preset, so no
/// API secret ever needs to live in this client app. The cloud name and
/// upload preset name are not secrets - Cloudinary's unsigned-upload
/// design is built around exposing them client-side; only the API secret
/// (never used here) would need to stay server-side.
class CloudinaryUploader {
  static const _cloudName = 'jrniln5b';
  static const _uploadPreset = 'cocktailplaner';

  /// Uploads [bytes] (an image file's contents) to Cloudinary and returns
  /// the resulting `secure_url`, or null if the upload failed.
  Future<String?> uploadImage(Uint8List bytes, String filename) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['secure_url'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final cloudinaryUploader = CloudinaryUploader();
