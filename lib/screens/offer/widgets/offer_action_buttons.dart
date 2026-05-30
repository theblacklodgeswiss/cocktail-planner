import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Action buttons for the offer form (save, generate PDF, print, share).
class OfferActionButtons extends StatelessWidget {
  const OfferActionButtons({
    super.key,
    required this.isGenerating,
    required this.onSaveOnly,
    required this.onPreview,
    required this.onGeneratePdf,
    required this.onPrint,
    this.onShare,
  });

  final bool isGenerating;
  final VoidCallback? onSaveOnly;
  final VoidCallback? onPreview; // kept for API compatibility, unused
  final VoidCallback? onGeneratePdf;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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

    final printBtn = IconButton.outlined(
      onPressed: isGenerating ? null : onPrint,
      icon: const Icon(Icons.print, size: 20),
      tooltip: 'offer.print'.tr(),
      style: IconButton.styleFrom(side: BorderSide(color: colorScheme.outline)),
    );

    final shareBtn = IconButton.outlined(
      onPressed: isGenerating ? null : onShare,
      icon: const Icon(Icons.share, size: 20),
      tooltip: 'offer.share'.tr(),
      style: IconButton.styleFrom(side: BorderSide(color: colorScheme.outline)),
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
              printBtn,
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
                  printBtn,
                  const SizedBox(width: 8),
                  shareBtn,
                ],
              ),
            ],
          );
        }
      },
    );
  }
}
