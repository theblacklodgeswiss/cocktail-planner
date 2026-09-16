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
  const ShareLinkResult.notFound()
      : found = false,
        type = null,
        snapshot = null,
        orderId = null,
        message = null,
        response = null;

  const ShareLinkResult.found({
    required this.type,
    required this.snapshot,
    required this.orderId,
    this.message,
    this.response,
  }) : found = true;

  final bool found;
  final String? type; // 'offer' | 'invoice'
  final Map<String, dynamic>? snapshot;

  /// The order this link points at — needed so the public offer viewer can
  /// submit an accept/decline write against `orders/{orderId}`.
  final String? orderId;

  /// The WhatsApp greeting message, shown above the PDF on the public
  /// offer viewer. Null for invoice links, which never carry one.
  final String? message;

  /// 'accepted' | 'declined' | null. Set once the customer has already
  /// responded via this exact link — lets the viewer show the outcome on
  /// reload without needing to read the auth-gated orders collection.
  final String? response;
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

  /// Creates a share link for an offer. [orderId] lets the public viewer
  /// submit an accept/decline response against that exact order. [message]
  /// is the WhatsApp greeting text, shown above the PDF on the link page.
  Future<String> createOfferShareLink(
    OfferData offer, {
    required String orderId,
    required String message,
  }) async {
    final now = DateTime.now();
    return _writeWithRetry({
      'type': 'offer',
      'orderId': orderId,
      'message': message,
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
      return ShareLinkResult.found(
        type: type,
        snapshot: snapshot,
        orderId: data['orderId'] as String?,
        message: data['message'] as String?,
        response: data['response'] as String?,
      );
    } on FirebaseException catch (e) {
      debugPrint('Share link $code unavailable: ${e.code}');
      return const ShareLinkResult.notFound();
    }
  }

  /// Best-effort marks the share link itself as responded, so a reload of
  /// the same link shows the outcome without reading the auth-gated
  /// orders collection. The Firestore rule only allows this once the
  /// order genuinely already carries that status, so calling this
  /// speculatively (e.g. as recovery after a denied write) is safe — it
  /// either matches reality and succeeds, or doesn't and is denied.
  Future<bool> _tryRecordLinkResponse(String code, String status) async {
    try {
      await firestoreService.shareLinksCollection.doc(code).update({
        'response': status,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      debugPrint('Failed to record response on share link $code: ${e.code}');
      return false;
    }
  }

  /// Records the customer's accept/decline click from the public offer
  /// viewer. Writes the real order status first (the consequential
  /// change, gated by the `isShareLinkResponse` Firestore rule), then
  /// best-effort records the outcome on the share link itself.
  ///
  /// Throws if the order write is denied — meaning this offer was already
  /// resolved (by a prior click on this same link that got this far but
  /// whose link-marking step below never completed, by the staff app, or
  /// by someone else with the same link). The rule only allows the
  /// transition away from status 'quote', so this is the correct signal
  /// either way. Callers should retry [_tryRecordLinkResponse]-style
  /// recovery via [recoverLinkResponse] rather than surface a hard error.
  Future<void> respondToOffer({
    required String orderId,
    required String code,
    required bool accepted,
  }) async {
    final status = accepted ? 'accepted' : 'declined';
    await firestoreService.ordersCollection.doc(orderId).update({
      'status': status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'customerResponseCode': code,
    });
    await _tryRecordLinkResponse(code, status);
  }

  /// Recovery for when [respondToOffer] is denied because the order was
  /// already resolved: re-attempts marking the share link with the
  /// customer's originally-clicked outcome. If that outcome happens to
  /// match the order's real (already-set) status, the rule allows it and
  /// the link — and any later reload of it — now shows the true result
  /// instead of the buttons reappearing. If it doesn't match, this is
  /// denied too and the caller falls back to a generic message.
  Future<bool> recoverLinkResponse({
    required String code,
    required bool accepted,
  }) {
    return _tryRecordLinkResponse(code, accepted ? 'accepted' : 'declined');
  }
}

final shareLinkRepository = ShareLinkRepository();
