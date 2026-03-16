import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Action buttons for the offer form (save, preview, generate PDF, print, share).
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
  final VoidCallback? onPreview;
  final VoidCallback? onGeneratePdf;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Secondary (left-side) buttons
    final saveBtn = OutlinedButton.icon(
      onPressed: isGenerating ? null : onSaveOnly,
      icon: const Icon(Icons.save_outlined, size: 18),
      label: Text('offer.save_only'.tr()),
    );

    final previewBtn = OutlinedButton.icon(
      onPressed: isGenerating ? null : onPreview,
      icon: const Icon(Icons.visibility, size: 18),
      label: Text('offer.preview'.tr()),
    );

    // Primary (right-side) button
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
          // ── Desktop / Tablet ──────────────────────────────────────────────
          // Secondary left | gap | Primary right
          return Row(
            children: [
              // Left: secondary actions
              saveBtn,
              const SizedBox(width: 8),
              previewBtn,
              // Push primary actions to the right
              const Spacer(),
              // Right: primary actions
              pdfBtn,
              const SizedBox(width: 8),
              printBtn,
              const SizedBox(width: 8),
              shareBtn,
            ],
          );
        } else {
          // ── Mobile: two rows ──────────────────────────────────────────────
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: saveBtn),
                  const SizedBox(width: 8),
                  Expanded(child: previewBtn),
                ],
              ),
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
