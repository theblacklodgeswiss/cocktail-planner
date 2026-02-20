import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Screen displaying legal information (Impressum, AGB, Privacy).
class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key, required this.type});

  final LegalInfoType type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_getTitle()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _getContent(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  String _getTitle() {
    switch (type) {
      case LegalInfoType.imprint:
        return 'legal.imprint_title'.tr();
      case LegalInfoType.terms:
        return 'legal.terms_title'.tr();
      case LegalInfoType.privacy:
        return 'legal.privacy_title'.tr();
    }
  }

  String _getContent() {
    switch (type) {
      case LegalInfoType.imprint:
        return 'legal.imprint_content'.tr();
      case LegalInfoType.terms:
        return 'legal.terms_content'.tr();
      case LegalInfoType.privacy:
        return 'legal.privacy_content'.tr();
    }
  }
}

enum LegalInfoType { imprint, terms, privacy }
