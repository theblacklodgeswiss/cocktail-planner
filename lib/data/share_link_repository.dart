import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/offer.dart';
import '../models/order.dart';
import '../utils/short_code.dart';
import 'firestore_service.dart';

/// Result of looking up a share link. `found: false` covers both "the code
/// never existed" and "it existed but expired" — the public viewer must not
/// be able to distinguish the two.
class ShareLinkResult {
  const ShareLinkResult.notFound() : found = false, type = null, snapshot = null;

  const ShareLinkResult.found({required this.type, required this.snapshot})
      : found = true;

  final bool found;
  final String? type; // 'offer' | 'invoice'
  final Map<String, dynamic>? snapshot;
}

/// Creates and resolves short-lived, publicly-readable share links for
/// offers and invoices. See docs/superpowers/specs/2026-09-16-share-links-design.md.
class ShareLinkRepository {
  static const _linkLifetime = Duration(days: 14);

  /// Fields that must never appear in a public share-link snapshot.
  static const _invoicePiiKeys = {'userId', 'userEmail', 'createdBy', 'phone'};

  /// Strips PII-bearing keys from a [SavedOrder.toJson] map before it is
  /// written to the public `shareLinks` collection.
  static Map<String, dynamic> stripInvoicePii(Map<String, dynamic> json) {
    return {
      for (final entry in json.entries)
        if (!_invoicePiiKeys.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<String> _writeWithRetry(Map<String, dynamic> data) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final code = generateShortCode();
      final ref = firestoreService.shareLinksCollection.doc(code);
      final existing = await ref.get();
      if (existing.exists) continue; // negligible odds, but retry is cheap
      await ref.set(data);
      return code;
    }
    throw StateError('Could not allocate a unique share link code after 3 attempts');
  }

  /// Creates a share link for an offer. [orderId] is stored for staff
  /// traceability only — the public viewer never reads it.
  Future<String> createOfferShareLink(OfferData offer, {required String orderId}) async {
    final now = DateTime.now();
    return _writeWithRetry({
      'type': 'offer',
      'orderId': orderId,
      'snapshot': offer.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(_linkLifetime)),
    });
  }

  /// Creates a share link for an invoice (Auftragsbestätigung).
  Future<String> createInvoiceShareLink(SavedOrder order) async {
    final now = DateTime.now();
    return _writeWithRetry({
      'type': 'invoice',
      'orderId': order.id,
      'snapshot': stripInvoicePii(order.toJson()),
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(_linkLifetime)),
    });
  }

  /// Resolves a share link. Returns [ShareLinkResult.notFound] for a
  /// missing OR expired code (Firestore denies the read once expired, which
  /// surfaces here as a permission-denied exception — treated the same as
  /// "not found").
  Future<ShareLinkResult> fetchShareLink(String code) async {
    try {
      final doc = await firestoreService.shareLinksCollection.doc(code).get();
      if (!doc.exists) return const ShareLinkResult.notFound();
      final data = doc.data()!;
      final type = data['type'] as String?;
      final snapshot = data['snapshot'] as Map<String, dynamic>?;
      if (type == null || snapshot == null) return const ShareLinkResult.notFound();
      return ShareLinkResult.found(type: type, snapshot: snapshot);
    } on FirebaseException catch (e) {
      debugPrint('Share link $code unavailable: ${e.code}');
      return const ShareLinkResult.notFound();
    }
  }
}

final shareLinkRepository = ShareLinkRepository();
