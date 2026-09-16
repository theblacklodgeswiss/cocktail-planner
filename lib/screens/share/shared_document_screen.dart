import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../data/share_link_repository.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../services/invoice_pdf_generator.dart';
import '../../services/offer_pdf_generator.dart';

/// Public, signed-out-accessible screen that resolves a `/s/:code` share
/// link created by [ShareLinkRepository], regenerates the PDF from the
/// stored snapshot, and displays it inline. No Firebase Auth session is
/// required or assumed — see app_router.dart's redirect exemption for '/s/'.
///
/// For an offer link, also shows the WhatsApp greeting message above the
/// PDF and lets the customer accept/decline directly — see
/// [ShareLinkRepository.respondToOffer] and the `isShareLinkResponse`
/// Firestore rule, which is the actual security boundary for that write.
class SharedDocumentScreen extends StatefulWidget {
  const SharedDocumentScreen({super.key, required this.code});

  final String code;

  @override
  State<SharedDocumentScreen> createState() => _SharedDocumentScreenState();
}

class _SharedDocumentScreenState extends State<SharedDocumentScreen> {
  bool _loading = true;
  ShareLinkResult? _result;
  Uint8List? _pdfBytes;

  /// Mirrors [ShareLinkResult.response] once known, whether that came from
  /// the initial fetch (a prior visit already responded) or from this
  /// visitor's own click just now.
  String? _localResponse;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await shareLinkRepository.fetchShareLink(widget.code);
    Uint8List? bytes;
    if (result.found) {
      switch (result.type) {
        case 'offer':
          bytes = await OfferPdfGenerator.generatePdfBytes(
            OfferData.fromJson(result.snapshot!),
          );
        case 'invoice':
          final order = SavedOrder.fromFirestore('shared', result.snapshot!);
          bytes = await InvoicePdfGenerator.generateBytes(
            order,
            language: order.offerLanguage,
          );
      }
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _pdfBytes = bytes;
      _localResponse = result.response;
      _loading = false;
    });
  }

  Future<void> _respond(bool accepted) async {
    final result = _result;
    if (result == null || result.orderId == null) return;
    setState(() => _responding = true);
    try {
      await shareLinkRepository.respondToOffer(
        orderId: result.orderId!,
        code: widget.code,
        accepted: accepted,
      );
      if (mounted) {
        setState(() => _localResponse = accepted ? 'accepted' : 'declined');
      }
    } catch (e) {
      // Denied because the offer was already resolved — either by this
      // visitor's own earlier click (whose link-marking step never
      // completed, e.g. the tab closed mid-request) or by someone/
      // something else. Try to self-heal: if the order's real status
      // already matches what was just clicked, this succeeds and the
      // page can show the true outcome instead of a hard error.
      final recovered = await shareLinkRepository.recoverLinkResponse(
        code: widget.code,
        accepted: accepted,
      );
      if (mounted) {
        if (recovered) {
          setState(() => _localResponse = accepted ? 'accepted' : 'declined');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('share.response_error'.tr())),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('share.loading'.tr()),
          ],
        ),
      );
    }

    final bytes = _pdfBytes;
    final result = _result;
    if (bytes == null || result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off, size: 48),
              const SizedBox(height: 16),
              Text(
                'share.expired_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('share.expired_body'.tr(), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final message = result.message;
    final isOffer = result.type == 'offer';

    return Column(
      children: [
        if (message != null && message.trim().isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(message, style: const TextStyle(height: 1.4)),
          ),
        Expanded(
          child: PdfPreview(
            build: (format) async => bytes,
            allowSharing: true,
            allowPrinting: true,
            canDebug: false,
          ),
        ),
        if (isOffer) _buildResponseBar(context),
      ],
    );
  }

  Widget _buildResponseBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_localResponse == 'accepted' || _localResponse == 'declined') {
      final accepted = _localResponse == 'accepted';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: accepted
            ? Colors.green.withValues(alpha: 0.1)
            : colorScheme.errorContainer.withValues(alpha: 0.4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              accepted ? Icons.check_circle : Icons.cancel,
              color: accepted ? Colors.green.shade700 : colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              accepted
                  ? 'share.responded_accepted'.tr()
                  : 'share.responded_declined'.tr(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _responding ? null : () => _respond(false),
              icon: const Icon(Icons.close),
              label: Text('share.decline'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _responding ? null : () => _respond(true),
              icon: _responding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text('share.accept'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
