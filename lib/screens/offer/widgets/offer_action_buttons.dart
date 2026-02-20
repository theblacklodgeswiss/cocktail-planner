import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Action buttons for the offer form (preview, generate PDF, print).
class OfferActionButtons extends StatelessWidget {
  const OfferActionButtons({
    super.key,
    required this.isGenerating,
    required this.onPreview,
    required this.onGeneratePdf,
    required this.onPrint,
  });

  final bool isGenerating;
  final VoidCallback? onPreview;
  final VoidCallback? onGeneratePdf;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        // Vorschau / Preview
        OutlinedButton.icon(
          onPressed: isGenerating ? null : onPreview,
          icon: const Icon(Icons.visibility),
          label: Text('offer.preview'.tr()),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        // PDF Speichern / Download
        FilledButton.icon(
          onPressed: isGenerating ? null : onGeneratePdf,
          icon: isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.picture_as_pdf),
          label: Text('offer.generate_pdf'.tr()),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        // Drucken / Print
        OutlinedButton.icon(
          onPressed: isGenerating ? null : onPrint,
          icon: const Icon(Icons.print),
          label: Text('offer.print'.tr()),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }
}
