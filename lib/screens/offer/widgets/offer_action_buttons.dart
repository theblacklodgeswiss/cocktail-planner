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
    final saveBtn = OutlinedButton.icon(
      onPressed: isGenerating ? null : onSaveOnly,
      icon: const Icon(Icons.save_outlined, size: 18),
      label: Text('offer.save_only'.tr()),
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
          : const Icon(Icons.picture_as_pdf, size: 18),
      label: Text('offer.generate_pdf'.tr()),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    );

    final shareBtn = OutlinedButton.icon(
      onPressed: isGenerating ? null : onShare,
      icon: const Icon(Icons.link, size: 18),
      label: Text('offer.generate_link'.tr()),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return Row(
            children: [
              saveBtn,
              const Spacer(),
              pdfBtn,
              const SizedBox(width: 8),
              shareBtn,
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              saveBtn,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: pdfBtn),
                  const SizedBox(width: 8),
                  Expanded(child: shareBtn),
                ],
              ),
            ],
          );
        }
      },
    );
  }
}
