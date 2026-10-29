import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../config/env_config.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../services/microsoft_graph_service.dart';
import '../../services/offer_pdf_generator.dart';
import '../../services/pdf_generator.dart';
import '../shared/document_sections/document_services.dart';
import 'offer_flow.dart';

/// Screen to create and export an Offer (Angebot) from a [SavedOrder].
///
/// A thin wrapper: the four-step flow is [OfferFlow]; this file only adds
/// the browser-only parts (print preview, OneDrive upload), which cannot be
/// imported by VM tests.
class CreateOfferScreen extends StatelessWidget {
  const CreateOfferScreen({
    super.key,
    required this.order,
    this.services = const DocumentServices(),
  });

  final SavedOrder order;
  final DocumentServices services;

  Future<void> _previewPdf(BuildContext context, OfferData offer) async {
    final pdfBytes = await OfferPdfGenerator.generatePdfBytes(offer);
    if (context.mounted) {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    }
  }

  /// Generates the offer PDF and, when OneDrive is enabled, uploads it and
  /// the shopping list next to it (never creates a calendar entry; that
  /// happens when staff accept the order).
  Future<void> _exportPdf(BuildContext context, OfferData offer) async {
    final pdfBytes = await OfferPdfGenerator.generatePdfBytes(offer);
    final safeName = offer.orderName.replaceAll(' ', '_');
    final dateTag =
        '${offer.eventDate.year}${offer.eventDate.month.toString().padLeft(2, '0')}${offer.eventDate.day.toString().padLeft(2, '0')}';
    if (microsoftGraphService.isSupported && EnvConfig.isOneDriveEnabled) {
      await microsoftGraphService.uploadToOneDrive(
        oneDrivePath: MicrosoftGraphService.buildOneDrivePath(
          rootFolder: 'Angebote',
          date: offer.eventDate,
          fileName: 'Angebot_${safeName}_$dateTag.pdf',
        ),
        bytes: pdfBytes,
      );
      final shoppingListBytes = await PdfGenerator.generateBytesFromSavedOrder(
        order,
      );
      await microsoftGraphService.uploadToOneDrive(
        oneDrivePath: MicrosoftGraphService.buildOneDrivePath(
          rootFolder: 'Angebote',
          date: offer.eventDate,
          fileName: 'Einkaufsliste_${safeName}_$dateTag.pdf',
        ),
        bytes: shoppingListBytes,
      );
    }
  }

  @override
  Widget build(BuildContext context) => OfferFlow(
    order: order,
    services: services,
    previewPdf: _previewPdf,
    exportPdf: _exportPdf,
  );
}
