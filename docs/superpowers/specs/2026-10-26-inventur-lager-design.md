# Auftrag abschließen, Rest-Inventur und Lagerbestand – Design

Status: Entwurf, wartet auf Freigabe. Sprache der App: Deutsch (easy_localization, `de.json`/`en.json`).

## Warum

Nach einem Event bleibt Material übrig (Getränke, Spirituosen, Sirup, Becher). Heute pflegt das Team das in einer Excel-Liste ("Materialliste"), die App weiß nichts davon. Der Nutzer will:

1. einen angenommenen Auftrag **abschließen** können,
2. direkt danach per **Sprachnotiz oder Text** festhalten, was übrig ist,
3. dass daraus eine **Inventurliste** in der App wird (ersetzt die Excel),
4. dass die **Einkaufsliste** beim Berechnen weiß, ob etwas aus dem Laden oder aus einem Lager kommt.

## Begriffe

- **Lagerort**: Ein Standort, der bei einer Person liegt. Heute drei: Tuji, Biri, Mario (in der Excel steht "Inthusan", vermutlich = Tuji; der Nutzer bestätigt das noch). Frei hinzufügbar, umbenennbar.
- **Herkunft** eines Bestands:
  - **Auftrag**: Rest aus einem Event. Gehört Blacklodge, ist für den nächsten Auftrag kostenlos.
  - **Investition**: Vom Nutzer vorgekauft. Blacklodge kauft es ggf. ab, statt im Shop zu kaufen. Kostet beim Verbrauch den Einkaufspreis.
- **Bestand**: Menge je Artikel × Lagerort × Herkunft. Gesamt = Summe, wird berechnet.

## Ziele

- Neuer Auftragsstatus **Abgeschlossen**, nur von **Angenommen** aus erreichbar.
- Nach dem Abschließen öffnet sich die **Rest-Abfrage** (Sprache oder Text). Sie ist überspringbar und später nachholbar.
- **Inventurliste** als eigene Seite: Artikel, Menge je Lagerort und Herkunft, Gesamt, Bemerkung (z. B. Haltbar bis).
- Bestand ändert sich durch **Bewegungen** (zurückbringen = addieren, entnehmen = abziehen), mit **Verlauf** (Datum, Person, Auftrag, Menge). Zusätzlich lässt sich jeder Wert direkt auf eine Zahl **korrigieren**.
- **Einkaufsliste**: Jeder Artikel hat eine Herkunft "Laden" oder "Lager <Ort>" (mit Anzeige des vorhandenen Bestands). Beim Abschließen werden Artikel mit Herkunft Lager automatisch vom Bestand abgezogen.
- **Kostenlogik**: Aus Lager mit Herkunft Auftrag = 0 €, aus Lager mit Herkunft Investition = Einkaufspreis.

## Nicht-Ziele

- Keine Bestandswarnungen, Mindestmengen, Nachbestell-Automatik.
- Kein Barcode-Scan.
- Keine Mengen-Umrechnung zwischen Einheiten (ml ↔ Flasche) für die Inventur; Mengen sind in der Einheit des Katalogartikels (Flasche, Packung, Pack).
- Kunden (Rolle customer) sehen nichts davon.

## Anti-Ziele (wäre ein Fehlschlag)

- Spracherkennung schreibt falsche Mengen ungeprüft in den Bestand. Es gibt immer eine **Bestätigungsansicht** vor dem Speichern.
- Der Bestand lässt sich nicht nachvollziehen (fehlender Verlauf).
- Abschließen blockiert, wenn die Inventur nicht sofort gemacht werden kann.

## Entscheidungen des Nutzers

- Rest-Abfrage nach "Abgeschlossen": Variante 2 (überspringbar, nachholbar).
- Artikel der Inventurliste = Artikelkatalog (`materials`).
- Menge je Lagerort **und** Herkunft getrennt.
- Standard-Lagerort = Lager des eingeloggten Nutzers (jeder bestimmt sein eigenes). Hat ein Mitarbeiter noch keins, wird **einmalig** danach gefragt. Anderer Ort per Sprache/Text nennbar ("bei Mario 3 Sprite").
- Rest nach Event wird standardmäßig als "Auftrag" erfasst; Investition trägt man separat ein.
- Bestand ändert sich durch Zurückbringen/Entnehmen, nicht durch Ersetzen des Gesamtbestands (Korrektur auf Zahl bleibt möglich). Bestätigt, mit Verlauf.
- Einkaufsliste kennt die Herkunft Laden/Lager; Teil 2 kommt in denselben Plan wie Teil 1 (bestätigt).
- **Kosten nur intern:** Kundenpreis, Angebots- und Rechnungs-PDF bleiben unverändert. Material aus Lager/Auftrag zählt intern 0 €, aus Lager/Investition zum Katalogpreis (`price`).
- **Lagerorte hängen an Nutzerkonten.** Biri und Mario sind eigene Nutzer der App.

## Meine Entscheidungen (bitte beim Lesen prüfen)

- Automatischer Abzug nimmt zuerst Herkunft Auftrag, dann Investition.
- Zu wenig Bestand: auf 0 abziehen, Rest als "aus Laden" markieren; Abschließen blockiert nie.
- Abgeschlossen zählt überall (Umsatz, Kalender, Filter) wie Angenommen. Zurücksetzen auf Angenommen ist erlaubt und bucht den Bestand nicht zurück. Kunde sieht auf dem Freigabelink weiter "Angenommen".
- Employees dürfen auf jeden Lagerort buchen ("bei Mario 3 Sprite"); Umbenennen/Löschen/Besitzer ändern nur der Besitzer des Lagerorts oder Admins.
- Sprach-/Texteintrag ohne Katalogtreffer: Bestätigungsansicht lässt Artikel wählen oder neuen Katalogartikel anlegen. Mengen sind Dezimalzahlen (2,8 erlaubt).
- Excel-Import: einmalig; Zeilen ohne Katalogtreffer werden vor dem Speichern zur Prüfung angezeigt, nichts wird automatisch im Katalog angelegt. Excel-Spalte "Inthusan" wird dem Lagerort Tuji zugeordnet, sofern der Nutzer das bestätigt.
- Investitionspreis = Katalogpreis, nicht Preis pro Einzelkauf.

## Rahmenbedingungen aus dem Code (Stand 2026-10-26)

- Flutter **nur Web**; keine iOS/Android-Ordner. Spracheingabe läuft über die Browser-Spracherkennung (HTTPS, Mikrofonfreigabe im Browser).
- Status: `OrderStatus { quote, accepted, declined }` in `lib/models/order.dart`; Helfer in `lib/screens/orders/order_status_helpers.dart` (je ein Switch für Label, Farbe, Icon). `OrderRepository.updateStatus(...)` in `lib/data/order_repository.dart`. Dialog-Vorlage: "Ablehnen mit Grund" (#21) in `order_detail_sheet.dart`.
- Kunden-Freigabelink-Regel in `firestore.rules` erlaubt nur quote→accepted/declined; neuer Status betrifft nur Mitarbeiter-Schreibzugriffe.
- Es gibt kein Bestandsmodell. Katalog: `materials` (`MaterialItem`: name, unit als Freitext, price, category, active) – ohne stabile ID im Modell, IDs nur über `AdminRepository.getMaterialsWithIds`.
- Rollen: customer, employee, admin, superAdmin. Inventur nur für employee und höher.
- Menü-Einstieg: `user_menu_sheet.dart` (neben "Aufträge", gleiche Freigabe). Routen in `lib/router/app_router.dart`.
- Einkaufsliste: `SavedOrder.items` (Liste von Maps), Berechnung in `lib/screens/shopping_list/shopping_list_logic.dart`, Anzeige in `order_shopping_list_page.dart`.
- Firestore-Regeln/Indizes im Repo-Root; Deploy siehe Memory "Deploy mechanics".

## Zwei Lieferstufen (ein Plan)

**Teil 1**: Status Abgeschlossen, Lagerorte, Inventurliste, Rest-Abfrage (Sprache/Text) mit Bestätigung, Verlauf, Korrektur, Excel-Startdaten.
**Teil 2**: Herkunft Laden/Lager in der Einkaufsliste, automatischer Abzug beim Abschließen, Kostenlogik.
Jede Stufe soll für sich auslieferbar sein.

## Dem Builder überlassen

Datenmodell und Collection-Namen, Matching von gesprochenen Namen auf Katalogartikel (Fuzzy, Rückfrage bei Unsicherheit), Wahl der Spracherkennung (Browser-API vs. Server), Art des Excel-Imports (einmalig, Einfügen oder Datei), UI-Layout, Regeln und Tests, Umgang mit Einheiten wie "2,8 Flaschen".
