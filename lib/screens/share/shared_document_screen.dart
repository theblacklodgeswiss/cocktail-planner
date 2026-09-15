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
class SharedDocumentScreen extends StatefulWidget {
  const SharedDocumentScreen({super.key, required this.code});

  final String code;

  @override
  State<SharedDocumentScreen> createState() => _SharedDocumentScreenState();
}

class _SharedDocumentScreenState extends State<SharedDocumentScreen> {
  late final Future<Uint8List?> _pdfBytesFuture;

  @override
  void initState() {
    super.initState();
    _pdfBytesFuture = _resolveAndRender();
  }

  Future<Uint8List?> _resolveAndRender() async {
    final result = await shareLinkRepository.fetchShareLink(widget.code);
    if (!result.found) return null;

    switch (result.type) {
      case 'offer':
        final offer = OfferData.fromJson(result.snapshot!);
        return OfferPdfGenerator.generatePdfBytes(offer);
      case 'invoice':
        final order = SavedOrder.fromFirestore('shared', result.snapshot!);
        return InvoicePdfGenerator.generateBytes(order, language: order.offerLanguage);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Uint8List?>(
        future: _pdfBytesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
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

          final bytes = snapshot.data;
          if (bytes == null) {
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
                    Text(
                      'share.expired_body'.tr(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return PdfPreview(
            build: (format) async => bytes,
            allowSharing: true,
            allowPrinting: true,
            canDebug: false,
          );
        },
      ),
    );
  }
}
