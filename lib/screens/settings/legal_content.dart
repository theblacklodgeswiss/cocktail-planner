// Legal texts of the app. German is the legally binding language, so the
// content is kept as authored here and is not part of the translation files.

enum LegalInfoType { imprint, terms, privacy }

sealed class LegalBlock {
  const LegalBlock();
}

/// A paragraph (may contain bullet lines separated by blank lines).
class LegalText extends LegalBlock {
  const LegalText(this.text);

  final String text;
}

class LegalContact extends LegalBlock {
  const LegalContact({
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
}

/// Label/value rows (tables, lists of services, rights, ...).
class LegalPairs extends LegalBlock {
  const LegalPairs(this.rows);

  final List<(String, String)> rows;
}

class LegalSection {
  const LegalSection(this.title, this.blocks);

  final String title;
  final List<LegalBlock> blocks;
}

const _contact = LegalContact(
  name: 'Black Lodge',
  subtitle: 'Mario Kantharoobarajah',
  address: 'Birkenstrasse 3\nCH-4123 Allschwil',
  phone: '+41 79 778 48 61',
  email: 'the.blacklodge@outlook.com',
);

List<LegalSection> legalSections(LegalInfoType type) => switch (type) {
  LegalInfoType.imprint => _imprint,
  LegalInfoType.terms => _terms,
  LegalInfoType.privacy => _privacy,
};

const _imprint = [
  LegalSection('Betreiber und Verantwortlicher', [_contact]),
  LegalSection('Unternehmensform', [LegalText('Einzelunternehmen')]),
  LegalSection('Haftungsausschluss', [
    LegalText(
      'Der Autor übernimmt keine Gewähr für die Richtigkeit, Genauigkeit, '
      'Aktualität, Zuverlässigkeit und Vollständigkeit der Informationen.\n\n'
      'Haftungsansprüche gegen den Autor wegen Schäden materieller oder '
      'immaterieller Art, die aus dem Zugriff oder der Nutzung bzw. '
      'Nichtnutzung der veröffentlichten Informationen entstanden sind, '
      'werden ausgeschlossen.',
    ),
  ]),
  LegalSection('Urheberrechte', [
    LegalText(
      'Die Urheber- und alle anderen Rechte an Inhalten, Bildern, Fotos '
      'oder anderen Dateien gehören ausschliesslich Black Lodge oder den '
      'speziell genannten Rechteinhabern.',
    ),
  ]),
];

const _terms = [
  LegalSection('1. Geltungsbereich', [
    LegalText(
      '• Diese AGB gelten für sämtliche Verträge zwischen Black Lodge '
      '(Mario Kantharoobarajah, Birkenstrasse 3, CH-4123 Allschwil) und dem Kunden.\n\n'
      '• Die AGB gelten für alle Dienstleistungen im Bereich Mobile Cocktail Bar, '
      'einschliesslich Getränke, Bar-Equipment und Personal.\n\n'
      '• Abweichende Bedingungen des Kunden werden nur anerkannt, wenn der '
      'Anbieter diesen ausdrücklich schriftlich zugestimmt hat.',
    ),
  ]),
  LegalSection('2. Vertragsschluss', [
    LegalText(
      '• Angebote des Anbieters sind freibleibend und unverbindlich.\n\n'
      '• Der Vertrag kommt durch schriftliche Auftragsbestätigung oder '
      'Unterzeichnung des Angebots zustande.\n\n'
      '• Mündliche Nebenabreden bedürfen der schriftlichen Bestätigung.',
    ),
  ]),
  LegalSection('3. Leistungsumfang', [
    LegalText(
      '• Der Leistungsumfang ergibt sich aus dem jeweiligen Angebot.\n\n'
      '• Der Anbieter ist für Einkauf und Zubereitung der Cocktails verantwortlich '
      '(inkl. Becher, Süssigkeiten, Strohhalme, Früchte, Alkohol).\n\n'
      '• Eine Bartheke kann gegen Aufpreis bereitgestellt werden.\n\n'
      '• Der Auftraggeber stellt Strom, Wasser und ausreichend Platz sicher.',
    ),
  ]),
  LegalSection('4. Preise und Zahlung', [
    LegalText(
      '• Alle Preise in der im Angebot bzw. Auftrag angegebenen Währung.\n\n'
      '• Zahlung per Banküberweisung oder TWINT.\n\n'
      '• Bei Zahlungsverzug: 5% p.a. Verzugszinsen.',
    ),
  ]),
  LegalSection('5. Stornierung', [
    LegalPairs([
      ('14+ Tage vorher', 'Kostenlos'),
      ('7-13 Tage vorher', '50% fällig'),
      ('< 7 Tage / No-Show', '100% fällig'),
    ]),
  ]),
  LegalSection('6. Haftung', [
    LegalText(
      '• Der Anbieter haftet nur bei Vorsatz oder grober Fahrlässigkeit.\n\n'
      '• Keine Haftung für leichte Fahrlässigkeit.\n\n'
      '• Haftung für Folgeschäden und entgangenen Gewinn ausgeschlossen.\n\n'
      '• Der Auftraggeber haftet für Schäden am Equipment.',
    ),
  ]),
  LegalSection('7. Jugendschutz', [
    LegalPairs([('18+', 'Spirituosen'), ('16+', 'Bier, Wein')]),
    LegalText(
      'Der Auftraggeber ist verpflichtet, den Anbieter bei der '
      'Einhaltung des Jugendschutzes zu unterstützen.',
    ),
  ]),
  LegalSection('8. Datenschutz', [
    LegalText(
      'Der Anbieter verarbeitet personenbezogene Daten gemäss dem '
      'Schweizer Datenschutzgesetz (DSG). Details in der separaten Datenschutzerklärung.',
    ),
  ]),
  LegalSection('9. Schlussbestimmungen', [
    LegalText(
      '• Es gilt ausschliesslich Schweizer Recht.\n\n'
      '• Gerichtsstand: Allschwil (BL), Schweiz.\n\n'
      '• Salvatorische Klausel: Bei Unwirksamkeit einzelner Bestimmungen '
      'bleiben die übrigen Bestimmungen wirksam.',
    ),
  ]),
];

const _privacy = [
  LegalSection('1. Verantwortlicher', [
    LegalContact(
      name: 'Black Lodge',
      subtitle: 'Mario Kantharoobarajah',
      address: 'Birkenstrasse 3\nCH-4123 Allschwil\nSchweiz',
      phone: '+41 79 778 48 61',
      email: 'the.blacklodge@outlook.com',
    ),
  ]),
  LegalSection('2. Erhobene Daten', [
    LegalPairs([
      ('E-Mail-Adresse', 'Authentifizierung'),
      ('Bestelldaten', 'Cocktails, Mengen, Preise'),
      ('Kundendaten', 'Name, Adresse, Event'),
      ('Technische Daten', 'Firebase ID, Token'),
    ]),
  ]),
  LegalSection('3. Zweck der Verarbeitung', [
    LegalText(
      '• Bereitstellung und Verwaltung Ihres Benutzerkontos\n\n'
      '• Erstellung und Verwaltung von Angeboten und Bestellungen\n\n'
      '• Generierung von PDF-Dokumenten (Angebote, Rechnungen, Einkaufslisten)\n\n'
      '• Kommunikation bezüglich Ihrer Aufträge\n\n'
      '• Verbesserung unserer Dienstleistungen',
    ),
  ]),
  LegalSection('4. Rechtsgrundlage', [
    LegalText(
      'Verarbeitung gemäss Schweizer Datenschutzgesetz (DSG):\n\n'
      '• Vertragserfüllung (Angebote, Auftragsabwicklung)\n\n'
      '• Berechtigte Interessen (App-Verbesserung)\n\n'
      '• Einwilligung (wo erforderlich)',
    ),
  ]),
  LegalSection('5. Datenspeicherung', [
    LegalText('Firebase (Google Cloud)\nServer in EU/EWR'),
    LegalPairs([
      ('Authentication', 'Benutzeranmeldung'),
      ('Cloud Firestore', 'Datenspeicherung'),
      ('Firebase Hosting', 'App-Bereitstellung'),
    ]),
    LegalText('Löschung 30 Tage nach Kontokündigung'),
  ]),
  LegalSection('6. Ihre Rechte', [
    LegalPairs([
      ('Auskunft', 'Informationen über gespeicherte Daten'),
      ('Berichtigung', 'Korrektur unrichtiger Daten'),
      ('Löschung', 'Entfernung Ihrer Daten'),
      ('Einschränkung', 'Verarbeitung begrenzen'),
      ('Portabilität', 'Daten in gängigem Format'),
      ('Widerspruch', 'Verarbeitung widersprechen'),
      ('Widerruf', 'Einwilligung zurückziehen'),
    ]),
  ]),
  LegalSection('7. Datensicherheit', [
    LegalText(
      '• Verschlüsselte Datenübertragung (TLS/SSL)\n\n'
      '• Zugriffsbeschränkungen und Authentifizierung\n\n'
      '• Regelmässige Sicherheitsupdates\n\n'
      '• Firebase Security Rules zum Schutz der Daten',
    ),
  ]),
  LegalSection('8. Cookies und Tracking', [
    LegalText(
      'Die App selbst verwendet keine Cookies. Firebase kann technisch '
      'notwendige Cookies für die Authentifizierung setzen.\n\n'
      'Wir verwenden kein Werbe-Tracking.',
    ),
  ]),
  LegalSection('9. Änderungen', [
    LegalText(
      'Wir behalten uns vor, diese Datenschutzerklärung bei Bedarf anzupassen. '
      'Die aktuelle Version ist in der App unter Einstellungen > Datenschutz einsehbar.',
    ),
  ]),
  LegalSection('10. Kontakt & Beschwerderecht', [
    LegalText('Bei Fragen zum Datenschutz:\nE-Mail: the.blacklodge@outlook.com'),
    LegalText('Beschwerden können Sie an den EDÖB richten:\nedoeb.admin.ch'),
  ]),
];
