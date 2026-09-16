import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Action buttons for the offer form (save, generate PDF, generate share link).
class OfferActionButtons extends StatelessWidget {
  const OfferActionButtons({
    super.key,
    required this.isGenerating,
    required this.onSaveOnly,
    required this.onPreview,
    required this.onGeneratePdf,
    this.onShare,
  });

  final bool isGenerating;
  final VoidCallback? onSaveOnly;
  final VoidCallback? onPreview; // kept for API compatibility, unused
  final VoidCallback? onGeneratePdf;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    const compactPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    final saveBtn = OutlinedButton.icon(
      onPressed: isGenerating ? null : onSaveOnly,
      icon: const Icon(Icons.save_outlined, size: 16),
      label: Text('offer.save_only'.tr(), overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(padding: compactPadding),
    );

    final pdfBtn = FilledButton.icon(
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
          : const Icon(Icons.picture_as_pdf, size: 16),
      label: Text('offer.generate_pdf'.tr(), overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(padding: compactPadding),
    );

    final shareBtn = OutlinedButton.icon(
      onPressed: isGenerating ? null : onShare,
      icon: const Icon(Icons.link, size: 16),
      label: Text('offer.generate_link'.tr()),
      style: OutlinedButton.styleFrom(padding: compactPadding),
    );

    // Save + generate PDF side by side on top (compact), the share-link
    // button spans the full width below it — the action the customer
    // ultimately needs is the most prominent one.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: saveBtn),
            const SizedBox(width: 8),
            Expanded(child: pdfBtn),
          ],
        ),
        const SizedBox(height: 8),
        shareBtn,
      ],
    );
  }
}
