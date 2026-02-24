import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Action buttons for the offer form (save, preview, generate PDF, print).
class OfferActionButtons extends StatelessWidget {
  const OfferActionButtons({
    super.key,
    required this.isGenerating,
    required this.onSaveOnly,
    required this.onPreview,
    required this.onGeneratePdf,
    required this.onPrint,
  });

  final bool isGenerating;
  final VoidCallback? onSaveOnly;
  final VoidCallback? onPreview;
  final VoidCallback? onGeneratePdf;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;
        if (isMobile) {
          // Mobile: first row (save, preview), second row (PDF), third row (print)
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isGenerating ? null : onSaveOnly,
                      icon: const Icon(Icons.save_outlined),
                      label: Text('offer.save_only'.tr()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isGenerating ? null : onPreview,
                      icon: const Icon(Icons.visibility),
                      label: Text('offer.preview'.tr()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
        } else {
          // Desktop/tablet: all in a row
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: isGenerating ? null : onSaveOnly,
                icon: const Icon(Icons.save_outlined),
                label: Text('offer.save_only'.tr()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
              OutlinedButton.icon(
                onPressed: isGenerating ? null : onPreview,
                icon: const Icon(Icons.visibility),
                label: Text('offer.preview'.tr()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
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
      },
    );
  }
}
