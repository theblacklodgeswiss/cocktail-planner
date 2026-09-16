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

  /// The only SavedOrder.toJson() keys InvoicePdfGenerator actually reads —
  /// an allowlist, not a denylist, so nothing internal-only (userId,
  /// userEmail, createdBy, phone, formSubmissionId, cocktailPopularity,
  /// etc.) can leak into the public shareLinks document even if a future
  /// SavedOrder field is added without anyone remembering to re-audit this.
  static const _invoiceSnapshotKeys = {
    'additionalServices', 'alcoholPurchase', 'assignedEmployees', 'bar',
    'barDrinks', 'cocktails', 'currency', 'date', 'distanceKm', 'eventTime',
    'items', 'location', 'name', 'offerClientContact', 'offerClientName',
    'offerDiscount', 'offerDiscountRemark', 'offerEventTime',
    'offerEventTypes', 'offerExtraHourRate', 'offerExtraHours',
    'offerExtraPositions', 'offerLanguage', 'offerPositions',
    'offerShotsCount', 'offerShotsPricePerPiece', 'offerShotsRemark',
    'personCount', 'remarks', 'serviceType', 'shots', 'thekeCost', 'total',
  };

  /// Reduces a [SavedOrder.toJson] map to only the fields the invoice PDF
  /// generator reads, before it is written to the public `shareLinks`
  /// collection. `SavedOrder.fromFirestore` defaults every field it doesn't
  /// find, so a partial map like this reconstructs safely.
  static Map<String, dynamic> invoiceSnapshotFields(Map<String, dynamic> json) {
    return {
      for (final entry in json.entries)
        if (_invoiceSnapshotKeys.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<String> _writeWithRetry(Map<String, dynamic> data) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final code = generateShortCode();
      final ref = firestoreService.shareLinksCollection.doc(code);
      try {
        await ref.set(data);
        return code;
      } on FirebaseException catch (e) {
        // A collision (code already exists) is classified by Firestore as an
        // "update" of an existing doc, which our rules deny — that denial IS
        // the collision signal, at negligible odds with an 8-char code. Any
        // other denial reason would also deny a fresh code, so don't retry
        // past the attempt budget for those either; the loop's final
        // attempt always rethrows.
        if (e.code == 'permission-denied' && attempt < 2) continue;
        rethrow;
      }
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
      'snapshot': invoiceSnapshotFields(order.toJson()),
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
