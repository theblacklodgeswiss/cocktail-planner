import 'dart:math';

const _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// Generates an 8-character random base62 code, used as both the Firestore
/// document ID and the URL path segment for a share link (`/s/<code>`).
/// Collision probability across the alphabet's ~2×10^14 combinations is
/// negligible for this document volume; [ShareLinkRepository] still retries
/// on a rare collision as cheap insurance (see Task 5).
String generateShortCode() {
  final random = Random.secure();
  return List.generate(
    8,
    (_) => _alphabet[random.nextInt(_alphabet.length)],
  ).join();
}
