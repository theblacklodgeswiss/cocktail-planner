import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Screen displaying legal information (Impressum, AGB, Privacy).
class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key, required this.type});

  final LegalInfoType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_getTitle()),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.primaryContainer.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _getIcon(),
                    size: 48,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getTitle(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stand: Februar 2026',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildContent(context),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case LegalInfoType.imprint:
        return Icons.business_rounded;
      case LegalInfoType.terms:
        return Icons.description_rounded;
      case LegalInfoType.privacy:
        return Icons.privacy_tip_rounded;
    }
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

  Widget _buildContent(BuildContext context) {
    switch (type) {
      case LegalInfoType.imprint:
        return _buildImprintContent(context);
      case LegalInfoType.terms:
        return _buildTermsContent(context);
      case LegalInfoType.privacy:
        return _buildPrivacyContent(context);
    }
  }

  Widget _buildImprintContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalSection(
          title: 'Betreiber und Verantwortlicher',
          icon: Icons.person_rounded,
          child: const _ContactCard(
            name: 'Black Lodge',
            subtitle: 'Mario Kantharoobarajah',
            address: 'Birkenstrasse 3\nCH-4123 Allschwil',
            phone: '+41 79 778 48 61',
            email: 'the.blacklodge@outlook.com',
          ),
        ),
        _LegalSection(
          title: 'Unternehmensform',
          icon: Icons.store_rounded,
          child: _InfoCard(
            content: 'Einzelunternehmen',
            icon: Icons.business_center_rounded,
          ),
        ),
        _LegalSection(
          title: 'Haftungsausschluss',
          icon: Icons.warning_rounded,
          child: const _TextCard(
            text: 'Der Autor übernimmt keine Gewähr für die Richtigkeit, Genauigkeit, '
                'Aktualität, Zuverlässigkeit und Vollständigkeit der Informationen.\n\n'
                'Haftungsansprüche gegen den Autor wegen Schäden materieller oder '
                'immaterieller Art, die aus dem Zugriff oder der Nutzung bzw. '
                'Nichtnutzung der veröffentlichten Informationen entstanden sind, '
                'werden ausgeschlossen.',
          ),
        ),
        _LegalSection(
          title: 'Urheberrechte',
          icon: Icons.copyright_rounded,
          child: const _TextCard(
            text: 'Die Urheber- und alle anderen Rechte an Inhalten, Bildern, Fotos '
                'oder anderen Dateien gehören ausschliesslich Black Lodge oder den '
                'speziell genannten Rechteinhabern.',
          ),
        ),
      ],
    );
  }

  Widget _buildTermsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalSection(
          title: '1. Geltungsbereich',
          icon: Icons.gavel_rounded,
          child: const _TextCard(
            text: '• Diese AGB gelten für sämtliche Verträge zwischen Black Lodge '
                '(Mario Kantharoobarajah, Birkenstrasse 3, CH-4123 Allschwil) und dem Kunden.\n\n'
                '• Die AGB gelten für alle Dienstleistungen im Bereich Mobile Cocktail Bar, '
                'einschliesslich Getränke, Bar-Equipment und Personal.\n\n'
                '• Abweichende Bedingungen des Kunden werden nur anerkannt, wenn der '
                'Anbieter diesen ausdrücklich schriftlich zugestimmt hat.',
          ),
        ),
        _LegalSection(
          title: '2. Vertragsschluss',
          icon: Icons.handshake_rounded,
          child: const _TextCard(
            text: '• Angebote des Anbieters sind freibleibend und unverbindlich.\n\n'
                '• Der Vertrag kommt durch schriftliche Auftragsbestätigung oder '
                'Unterzeichnung des Angebots zustande.\n\n'
                '• Mündliche Nebenabreden bedürfen der schriftlichen Bestätigung.',
          ),
        ),
        _LegalSection(
          title: '3. Leistungsumfang',
          icon: Icons.local_bar_rounded,
          child: const _TextCard(
            text: '• Der Leistungsumfang ergibt sich aus dem jeweiligen Angebot.\n\n'
                '• Der Anbieter ist für Einkauf und Zubereitung der Cocktails verantwortlich '
                '(inkl. Becher, Süssigkeiten, Strohhalme, Früchte, Alkohol).\n\n'
                '• Eine Bartheke kann gegen Aufpreis bereitgestellt werden.\n\n'
                '• Der Auftraggeber stellt Strom, Wasser und ausreichend Platz sicher.',
          ),
        ),
        _LegalSection(
          title: '4. Preise und Zahlung',
          icon: Icons.payments_rounded,
          child: const _TextCard(
            text: '• Alle Preise in Schweizer Franken (CHF).\n\n'
                '• Zahlung per Banküberweisung oder TWINT.\n\n'
                '• Bei Zahlungsverzug: 5% p.a. Verzugszinsen.',
          ),
        ),
        _LegalSection(
          title: '5. Stornierung',
          icon: Icons.event_busy_rounded,
          child: _CancellationTable(),
        ),
        _LegalSection(
          title: '6. Haftung',
          icon: Icons.shield_rounded,
          child: const _TextCard(
            text: '• Der Anbieter haftet nur bei Vorsatz oder grober Fahrlässigkeit.\n\n'
                '• Keine Haftung für leichte Fahrlässigkeit.\n\n'
                '• Haftung für Folgeschäden und entgangenen Gewinn ausgeschlossen.\n\n'
                '• Der Auftraggeber haftet für Schäden am Equipment.',
          ),
        ),
        _LegalSection(
          title: '7. Jugendschutz',
          icon: Icons.no_drinks_rounded,
          child: _AgeRestrictionCard(),
        ),
        _LegalSection(
          title: '8. Datenschutz',
          icon: Icons.privacy_tip_rounded,
          child: const _TextCard(
            text: 'Der Anbieter verarbeitet personenbezogene Daten gemäss dem '
                'Schweizer Datenschutzgesetz (DSG). Details in der separaten Datenschutzerklärung.',
          ),
        ),
        _LegalSection(
          title: '9. Schlussbestimmungen',
          icon: Icons.balance_rounded,
          child: const _TextCard(
            text: '• Es gilt ausschliesslich Schweizer Recht.\n\n'
                '• Gerichtsstand: Allschwil (BL), Schweiz.\n\n'
                '• Salvatorische Klausel: Bei Unwirksamkeit einzelner Bestimmungen '
                'bleiben die übrigen Bestimmungen wirksam.',
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalSection(
          title: '1. Verantwortlicher',
          icon: Icons.admin_panel_settings_rounded,
          child: const _ContactCard(
            name: 'Black Lodge',
            subtitle: 'Mario Kantharoobarajah',
            address: 'Birkenstrasse 3\nCH-4123 Allschwil\nSchweiz',
            phone: '+41 79 778 48 61',
            email: 'the.blacklodge@outlook.com',
          ),
        ),
        _LegalSection(
          title: '2. Erhobene Daten',
          icon: Icons.data_usage_rounded,
          child: _DataCollectionCard(),
        ),
        _LegalSection(
          title: '3. Zweck der Verarbeitung',
          icon: Icons.track_changes_rounded,
          child: const _TextCard(
            text: '• Bereitstellung und Verwaltung Ihres Benutzerkontos\n\n'
                '• Erstellung und Verwaltung von Angeboten und Bestellungen\n\n'
                '• Generierung von PDF-Dokumenten (Angebote, Rechnungen, Einkaufslisten)\n\n'
                '• Kommunikation bezüglich Ihrer Aufträge\n\n'
                '• Verbesserung unserer Dienstleistungen',
          ),
        ),
        _LegalSection(
          title: '4. Rechtsgrundlage',
          icon: Icons.gavel_rounded,
          child: const _TextCard(
            text: 'Verarbeitung gemäss Schweizer Datenschutzgesetz (DSG):\n\n'
                '• Vertragserfüllung (Angebote, Auftragsabwicklung)\n\n'
                '• Berechtigte Interessen (App-Verbesserung)\n\n'
                '• Einwilligung (wo erforderlich)',
          ),
        ),
        _LegalSection(
          title: '5. Datenspeicherung',
          icon: Icons.cloud_rounded,
          child: _FirebaseStorageCard(),
        ),
        _LegalSection(
          title: '6. Ihre Rechte',
          icon: Icons.verified_user_rounded,
          child: _UserRightsCard(),
        ),
        _LegalSection(
          title: '7. Datensicherheit',
          icon: Icons.security_rounded,
          child: const _TextCard(
            text: '• Verschlüsselte Datenübertragung (TLS/SSL)\n\n'
                '• Zugriffsbeschränkungen und Authentifizierung\n\n'
                '• Regelmässige Sicherheitsupdates\n\n'
                '• Firebase Security Rules zum Schutz der Daten',
          ),
        ),
        _LegalSection(
          title: '8. Cookies und Tracking',
          icon: Icons.cookie_rounded,
          child: const _TextCard(
            text: 'Die App selbst verwendet keine Cookies. Firebase kann technisch '
                'notwendige Cookies für die Authentifizierung setzen.\n\n'
                'Wir verwenden kein Werbe-Tracking.',
          ),
        ),
        _LegalSection(
          title: '9. Änderungen',
          icon: Icons.update_rounded,
          child: const _TextCard(
            text: 'Wir behalten uns vor, diese Datenschutzerklärung bei Bedarf anzupassen. '
                'Die aktuelle Version ist in der App unter Einstellungen > Datenschutz einsehbar.',
          ),
        ),
        _LegalSection(
          title: '10. Kontakt & Beschwerderecht',
          icon: Icons.contact_support_rounded,
          child: Column(
            children: [
              const _TextCard(
                text: 'Bei Fragen zum Datenschutz:\nE-Mail: the.blacklodge@outlook.com',
              ),
              const SizedBox(height: 12),
              _InfoCard(
                content: 'Beschwerden können Sie an den EDÖB richten:\nedoeb.admin.ch',
                icon: Icons.account_balance_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum LegalInfoType { imprint, terms, privacy }

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _LegalSection extends StatelessWidget {
  const _LegalSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.name,
    required this.subtitle,
    required this.address,
    required this.phone,
    required this.email,
  });

  final String name;
  final String subtitle;
  final String address;
  final String phone;
  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            _buildRow(Icons.location_on_rounded, address),
            const SizedBox(height: 8),
            _buildRow(Icons.phone_rounded, phone),
            const SizedBox(height: 8),
            _buildRow(Icons.email_rounded, email),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.content, required this.icon});

  final String content;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                content,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancellationTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Column(
        children: [
          _buildRow('14+ Tage vorher', 'Kostenlos', Colors.green, true),
          const Divider(height: 1),
          _buildRow('7-13 Tage vorher', '50% fällig', Colors.orange, false),
          const Divider(height: 1),
          _buildRow('< 7 Tage / No-Show', '100% fällig', Colors.red, false),
        ],
      ),
    );
  }

  Widget _buildRow(String time, String cost, Color color, bool isFirst) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(time)),
          Text(
            cost,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _AgeRestrictionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '18+',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Spirituosen')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '16+',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Bier, Wein')),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Der Auftraggeber ist verpflichtet, den Anbieter bei der '
              'Einhaltung des Jugendschutzes zu unterstützen.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataCollectionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Column(
        children: [
          _buildItem(Icons.email_rounded, 'E-Mail-Adresse', 'Authentifizierung'),
          const Divider(height: 1),
          _buildItem(Icons.shopping_cart_rounded, 'Bestelldaten', 'Cocktails, Mengen, Preise'),
          const Divider(height: 1),
          _buildItem(Icons.person_rounded, 'Kundendaten', 'Name, Adresse, Event'),
          const Divider(height: 1),
          _buildItem(Icons.fingerprint_rounded, 'Technische Daten', 'Firebase ID, Token'),
        ],
      ),
    );
  }

  Widget _buildItem(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      dense: true,
    );
  }
}

class _FirebaseStorageCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.network(
                  'https://www.gstatic.com/devrel-devsite/prod/v1241c04ebcb2127897d6c18571a5a16a0d5e5a6e69b8bcd26c75a7b2dcf70027/firebase/images/touchicon-180.png',
                  width: 32,
                  height: 32,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.cloud_rounded,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Firebase (Google Cloud)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Server in EU/EWR',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildService('Authentication', 'Benutzeranmeldung'),
            _buildService('Cloud Firestore', 'Datenspeicherung'),
            _buildService('Firebase Hosting', 'App-Bereitstellung'),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_rounded, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Löschung 30 Tage nach Kontokündigung',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildService(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Text(' – '),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _UserRightsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final rights = [
      ('Auskunft', 'Informationen über gespeicherte Daten'),
      ('Berichtigung', 'Korrektur unrichtiger Daten'),
      ('Löschung', 'Entfernung Ihrer Daten'),
      ('Einschränkung', 'Verarbeitung begrenzen'),
      ('Portabilität', 'Daten in gängigem Format'),
      ('Widerspruch', 'Verarbeitung widersprechen'),
      ('Widerruf', 'Einwilligung zurückziehen'),
    ];

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rights.map((r) => Chip(
            avatar: Icon(Icons.check_rounded, size: 16, color: colorScheme.primary),
            label: Text(r.$1),
            backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
          )).toList(),
        ),
      ),
    );
  }
}
