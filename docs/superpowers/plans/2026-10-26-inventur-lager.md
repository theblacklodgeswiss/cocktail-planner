# Auftrag abschließen, Inventur und Lagerbestand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aufträge abschließen, den Rest per Sprache oder Text als Lagerbestand erfassen, eine Inventurliste führen und die Einkaufsliste Laden/Lager unterscheiden lassen.

**Architecture:** Neue Firestore-Collections `storageLocations`, `stock` und `stockMovements`. Bestand = Menge je Artikel × Lagerort × Herkunft, geändert nur über Bewegungen (Transaktion) mit Verlauf. Reine Logik (Parser, Matcher, Kosten, Abzug) liegt in testbaren Dart-Dateien ohne Flutter-Abhängigkeit. UI folgt den vorhandenen Mustern (Bottom-Sheet, `AlertDialog`, `.tr()`, Singleton-Repositories).

**Tech Stack:** Flutter Web, go_router, easy_localization, Cloud Firestore, Browser-Spracherkennung (Web Speech API).

**Spec:** `docs/superpowers/specs/2026-10-26-inventur-lager-design.md`

## Global Constraints

- App ist nur Web; Spracheingabe nur über Browser-API, es gibt keine iOS/Android-Ordner.
- Nur `employee` und höher (`authService.isEmployeeOrHigher`) sehen und ändern Inventur; Kunden nie.
- Alle sichtbaren Texte über `.tr()` mit Schlüsseln in `assets/translations/de.json` und `en.json` (`test/translations_test.dart` muss grün bleiben).
- Mengen sind `double` (2,8 erlaubt), Anzeige mit deutschem Komma.
- Herkunft: `StockOrigin { order, investment }`. Kosten: Lager/order = 0 €, Lager/investment = Katalogpreis `MaterialItem.price`.
- Kundenpreis, Angebots- und Rechnungs-PDF bleiben unverändert. Die Kostenlogik wirkt nur intern.
- Rest nach dem Event wird standardmäßig als `order` erfasst.
- Abschließen blockiert nie wegen Inventur oder zu wenig Bestand.
- Freigabelink-Regel (`isShareLinkResponse`) bleibt unverändert; Kunden sehen `completed` als "Angenommen".
- Kein Commit ohne grüne Tests (`flutter test`, `flutter analyze`).

## Review Focus

- Sprachtext mit Komma-Mengen ("zwei Komma acht Bacardi", "2,8 Bacardi"): erwartet 2.8, keine Ablehnung.
- Gesprochener Name passt auf mehrere Katalogartikel ("Vodka"): Bestätigungsansicht zeigt Auswahl, nichts wird geraten.
- Abschließen zweimal ausgelöst (Doppelklick, Reload): Lagerabzug darf nur einmal passieren.
- Abzug mit mehr Menge als Bestand: auf 0, Rest als "aus Laden", Status wird trotzdem gesetzt.
- Katalogartikel umbenannt oder gelöscht: alter Bestand bleibt sichtbar und wird nicht verwaist.
- Mikrofon verweigert oder Browser ohne Spracherkennung: Textfeld funktioniert weiter, klare Meldung.

---

## File Structure

- `lib/models/order.dart` (ändern): `OrderStatus.completed`, `SavedOrder.stockApplied`, `restRecorded`.
- `lib/screens/orders/order_status_helpers.dart` (ändern): Label, Farbe, Icon für `completed`.
- `lib/models/stock.dart` (neu): `StockOrigin`, `StorageLocation`, `StockEntry`, `StockMovement`.
- `lib/data/stock_repository.dart` (neu): Lagerorte, Bestand, Bewegungen, Transaktionen.
- `lib/screens/shopping_list/stock_logic.dart` (neu): reine Funktionen für Abzug und Kosten.
- `lib/services/voice_inventory_parser.dart` (neu): Text → Zeilen, Matching auf Katalog.
- `lib/services/speech_input.dart` plus `speech_input_web.dart` und `speech_input_stub.dart` (neu): Browser-Spracherkennung hinter einer Schnittstelle.
- `lib/screens/inventory/` (neu): `inventory_screen.dart`, `rest_entry_sheet.dart`, `location_prompt_dialog.dart`, `excel_import_dialog.dart`.
- `lib/screens/orders/order_detail_sheet.dart`, `order_shopping_list_page.dart`, `lib/router/app_router.dart`, `lib/screens/dashboard/user_menu_sheet.dart` (ändern).
- `firestore.rules`, `firestore.indexes.json`, `assets/translations/*.json`, `test/` (ändern/neu).

---

### Task 1: Status "Abgeschlossen"

**Files:**
- Modify: `lib/models/order.dart:4-19`, `lib/screens/orders/order_status_helpers.dart:20-55`, `lib/screens/orders/order_detail_sheet.dart` (Aktionsbereich ~1455-1510), `lib/data/order_repository.dart:115`, `assets/translations/de.json`, `en.json`
- Test: `test/order_model_test.dart`

**Interfaces:**
- Produces: `OrderStatus.completed` (Label 'Abgeschlossen'), `SavedOrder.stockApplied: bool`, `SavedOrder.restRecorded: bool` (beide Default `false`, serialisiert), `OrderStatus.canComplete(OrderStatus from) -> bool` (nur `accepted`).

- [ ] **Step 1: Failing test** in `order_model_test.dart`: `completed` round-trips über `fromString('completed')`; `canComplete` ist true nur für `accepted`; `stockApplied`/`restRecorded` überleben `toMap`/`fromMap`; unbekannter String bleibt `quote`.
- [ ] **Step 2:** `flutter test test/order_model_test.dart` → FAIL (kein `completed`).
- [ ] **Step 3:** Enum-Wert, Felder und Serialisierung ergänzen; `statusLabel/Color/Icon` je ein Case; im Aktionsbereich Button "Abschließen" nur bei `accepted` (mit Bestätigungsdialog), Button "Zurück auf Angenommen" bei `completed` (bucht Bestand nicht zurück). Alle Filter, Zähler und Kalender, die `accepted` zählen, zählen `completed` mit (Builder greppt `OrderStatus.accepted`).
- [ ] **Step 4:** `flutter test` und `flutter analyze` → PASS.
- [ ] **Step 5:** Commit `feat: add completed order status`.

### Task 2: Bestandsmodell und Repository

**Files:**
- Create: `lib/models/stock.dart`, `lib/data/stock_repository.dart`
- Modify: `firestore.rules`, `firestore.indexes.json`
- Test: `test/stock_model_test.dart`

**Interfaces:**
- Produces:
  - `enum StockOrigin { order, investment }` mit `fromString`.
  - `StorageLocation { String id; String name; String? ownerEmail; }`
  - `StockEntry { String id; String materialId; String materialName; String locationId; StockOrigin origin; double quantity; String? note; }` (Dokument-ID `"$materialId|$locationId|${origin.name}"`).
  - `StockMovement { String id; String materialId; String locationId; StockOrigin origin; double delta; String reason; String? orderId; String byEmail; DateTime at; }` (`reason`: `rest`, `take`, `correction`, `import`, `order_deduction`).
  - `StockRepository`: `Stream<List<StorageLocation>> watchLocations()`, `Future<StorageLocation> createLocation(String name, {String? ownerEmail})`, `Future<void> renameLocation(String id, String name)`, `Stream<List<StockEntry>> watchStock()`, `Future<void> applyMovement({required String materialId, required String materialName, required String locationId, required StockOrigin origin, required double delta, required String reason, String? orderId})` (Transaktion, Menge klemmt bei 0, schreibt Bewegung), `Future<void> setQuantity({...,required double quantity})` (schreibt Korrektur-Bewegung mit Differenz), `Stream<List<StockMovement>> watchMovements({String? materialId})`. Singleton `stockRepository`.
- Regeln: Lesen/Schreiben auf die drei Collections nur für `hasFullOrderAccess()`-Rollen (employee+); `stockMovements` nicht änderbar und nicht löschbar; Umbenennen/Löschen von `storageLocations` nur Besitzer (`ownerEmail`) oder Admin.

- [ ] **Step 1: Failing tests:** `StockEntry` ID-Bildung, `fromMap/toMap` mit Dezimalzahl 2.8, `StockOrigin.fromString('investment')`, unbekannt → `order`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Modelle und Repository implementieren; `applyMovement` per `runTransaction`, Menge `max(0, alt + delta)`, Bewegung speichert die tatsächlich angewendete Differenz. Regeln und ggf. Index `stockMovements(materialId asc, at desc)` ergänzen.
- [ ] **Step 4:** Tests PASS, `flutter analyze` sauber. Regeln gegen Emulator prüfen, falls vorhanden, sonst manuell nach Deploy (siehe Memory "Deploy mechanics": Regeln vor App-Release deployen).
- [ ] **Step 5:** Commit `feat: stock model, repository and rules`.

### Task 3: Lagerorte pro Nutzer, einmalige Abfrage

**Files:**
- Create: `lib/screens/inventory/location_prompt_dialog.dart`
- Modify: `lib/data/stock_repository.dart`
- Test: `test/stock_location_test.dart`

**Interfaces:**
- Consumes: `StockRepository.watchLocations/createLocation`, `authService` (E-Mail, `isEmployeeOrHigher`).
- Produces: `Future<StorageLocation?> StockRepository.ownLocation()` (Ort mit `ownerEmail == aktuelle E-Mail`), `Future<StorageLocation> ensureOwnLocation(BuildContext)` (fragt per Dialog genau einmal nach dem Namen, wenn keiner existiert; Vorschlag = Anzeigename).

- [ ] **Step 1: Failing test** für die reine Funktion `StorageLocation? pickOwn(List<StorageLocation>, String email)` (Treffer, kein Treffer, Groß-/Kleinschreibung der E-Mail egal).
- [ ] **Step 2:** FAIL. **Step 3:** `pickOwn`, `ownLocation`, `ensureOwnLocation` und Dialog implementieren. **Step 4:** PASS. 
- [ ] **Step 5:** Commit `feat: per-user storage location`.

### Task 4: Reine Logik für Rest-Eingabe (Parser und Matcher)

**Files:**
- Create: `lib/services/voice_inventory_parser.dart`
- Test: `test/voice_inventory_parser_test.dart`

**Interfaces:**
- Produces:
  - `class ParsedLine { double quantity; String spokenName; String? locationHint; StockOrigin? originHint; }`
  - `List<ParsedLine> parseRestText(String text)`: trennt an Komma, Semikolon, "und", Zeilenumbruch; versteht "2 Bacardi", "2,8 Bacardi", "zwei Komma acht Bacardi", deutsche Zahlwörter bis 20 und "halbe"; `locationHint` aus "bei Mario ..." ; `originHint` aus "Investition".
  - `class CatalogMatch { String materialId; String name; double score; }`
  - `List<CatalogMatch> matchCatalog(String spokenName, List<(String id, MaterialItem item)> catalog, {int max = 3})`: normalisiert (klein, ohne Klammerzusatz), Teilstring und Präfix; Rückgabe nach Score absteigend, leer bei keinem Treffer.
  - `bool isConfident(List<CatalogMatch>)`: true nur, wenn genau ein Treffer ≥ 0.8 oder der beste mindestens 0.2 vor dem zweiten liegt.
- [ ] **Step 1: Failing tests** mit den Beispielen oben, plus "Vodka" → mehrere Treffer, `isConfident == false`; "Bacardi" → `Weisser Rum (Bacardi)` confident; "2 Bacardi, 6 Orangensaft" → zwei Zeilen; "bei Mario 3 Sprite" → `locationHint == 'Mario'`.
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren, keine Flutter-Imports. **Step 4:** PASS. **Step 5:** Commit `feat: rest entry parser and catalog matcher`.

### Task 5: Spracheingabe-Schnittstelle (Web)

**Files:**
- Create: `lib/services/speech_input.dart`, `speech_input_web.dart`, `speech_input_stub.dart`
- Test: `test/speech_input_test.dart`

**Interfaces:**
- Produces: `abstract class SpeechInput { bool get supported; Stream<String> listen({String locale = 'de-DE'}); Future<void> stop(); }`, Factory `SpeechInput createSpeechInput()` per konditionalem Import. Fehler (Mikrofon verweigert, nicht unterstützt) kommen als `SpeechInputException(code)` im Stream.
- [ ] **Step 1: Failing test** gegen den Stub: `supported == false`, `listen` wirft `SpeechInputException('unsupported')`.
- [ ] **Step 2:** FAIL. **Step 3:** Web-Variante über `dart:js_interop` auf `SpeechRecognition`/`webkitSpeechRecognition` (`interimResults`, `lang`), Stub für Nicht-Web. **Step 4:** Test PASS; manuell in Chrome und Safari prüfen. **Step 5:** Commit `feat: browser speech input`.

### Task 6: Rest-Abfrage nach dem Abschließen

**Files:**
- Create: `lib/screens/inventory/rest_entry_sheet.dart`
- Modify: `lib/screens/orders/order_detail_sheet.dart`, `assets/translations/*.json`
- Test: `test/rest_entry_flow_test.dart`

**Interfaces:**
- Consumes: Task 1 (`completed`, `restRecorded`), Task 2 (`applyMovement`), Task 3 (`ensureOwnLocation`), Task 4, Task 5.
- Produces: `Future<bool> showRestEntrySheet(BuildContext, {required SavedOrder order})` (true, wenn gespeichert). Reine Funktion `List<RestLine> buildRestLines(List<ParsedLine>, catalog, locations, StorageLocation defaultLocation)` für die Bestätigungsansicht; `RestLine { ParsedLine parsed; List<CatalogMatch> candidates; String? chosenMaterialId; StorageLocation location; StockOrigin origin; double quantity; }`.
- Verhalten: Beim Abschließen öffnet sich das Sheet mit Mikrofon-Button und Textfeld; "Überspringen" schließt ohne Buchung. Danach Bestätigungsansicht: jede Zeile zeigt Menge, Artikel (Auswahl bei unsicherem Treffer, oder "Neuen Artikel anlegen"), Lagerort, Herkunft (Default `order`). Speichern bucht je Zeile `applyMovement(delta: +quantity, reason: 'rest', orderId)` und setzt `restRecorded = true`. Im Auftrag mit `completed && !restRecorded` zeigt ein Button "Rest erfassen" dasselbe Sheet (Nachholen).
- [ ] **Step 1: Failing tests** für `buildRestLines`: Standardort wird gesetzt, `locationHint` überschreibt ihn, unsicherer Treffer lässt `chosenMaterialId == null`, Herkunft Default `order`.
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren; neuer Katalogartikel über `adminRepository`. **Step 4:** PASS, dann manuell: Auftrag annehmen, abschließen, Text "2 Bacardi, 6 Orangensaft" eingeben, bestätigen, Bestand prüfen. **Step 5:** Commit `feat: rest entry after completing an order`.

### Task 7: Inventurseite

**Files:**
- Create: `lib/screens/inventory/inventory_screen.dart`
- Modify: `lib/router/app_router.dart`, `lib/screens/dashboard/user_menu_sheet.dart:79-91`, `assets/translations/*.json`
- Test: `test/inventory_view_test.dart`

**Interfaces:**
- Produces: Route `/inventory` (Gate `isEmployeeOrHigher`), Menü-Tile "Inventur" neben "Aufträge". Reine Funktion `List<InventoryRow> buildInventoryRows(List<StockEntry>, List<StorageLocation>)` mit `InventoryRow { String materialName; Map<String, Map<StockOrigin, double>> perLocation; double total; String? note; }`.
- Inhalt: Tabelle je Artikel mit Spalten pro Lagerort (Auftrag/Investition), Gesamt, Bemerkung; Suchfeld; Tap auf eine Zahl → Korrektur (`setQuantity`) oder Entnehmen (`applyMovement` negativ, Reason `take`); Verlauf je Artikel; Lagerorte verwalten (Anlegen, Umbenennen nur Besitzer/Admin).
- [ ] **Step 1: Failing tests** für `buildInventoryRows` (Summe über Orte und Herkunft, 12,8-Beispiel aus der Excel: 2,8 + 10 = 12,8, Artikel ohne Bestand = 0).
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren. **Step 4:** PASS, manuell prüfen. **Step 5:** Commit `feat: inventory page`.

### Task 8: Excel-Startimport

**Files:**
- Create: `lib/screens/inventory/excel_import_dialog.dart`, `lib/services/inventory_import.dart`
- Modify: `lib/screens/inventory/inventory_screen.dart`
- Test: `test/inventory_import_test.dart`

**Interfaces:**
- Produces: `List<ImportRow> parseInventoryPaste(String tsv, {required List<String> columnLocations, required List<StockOrigin> columnOrigins})` – eingefügte Tabelle aus Excel (Tab-getrennt), Zahlen mit Komma, leere Zellen = 0; `ImportRow { String name; List<ImportCell> cells; String? note; List<CatalogMatch> candidates; }`.
- Verhalten: Einfügefeld → Vorschau mit Zuordnung der Spalten zu Lagerorten und Herkunft (Standard laut Excel: Biri, "Inthusan"→Tuji, Mario je unter Auftrag und Investition) → Zeilen ohne Treffer werden markiert und müssen gewählt, übersprungen oder angelegt werden → Speichern bucht `reason: 'import'`.
- [ ] **Step 1: Failing test:** Zeile `Weisser Rum (Bacardi)\t\t2,8\t\t\t\t10` ergibt 2.8 und 10.0 in den richtigen Zellen; leere Zelle ergibt keine Bewegung.
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren. **Step 4:** PASS, manuell mit der echten Liste. **Step 5:** Commit `feat: one-time inventory excel import`.

### Task 9: Herkunft in der Einkaufsliste und Kostenlogik (Teil 2)

**Files:**
- Create: `lib/screens/shopping_list/stock_logic.dart`
- Modify: `lib/screens/shopping_list/shopping_list_logic.dart`, `lib/screens/orders/order_shopping_list_page.dart`, `lib/models/order.dart` (Item-Map um `source`, `sourceLocationId` ergänzen)
- Test: `test/stock_logic_test.dart`

**Interfaces:**
- Produces:
  - Item-Map-Felder `source: 'shop' | 'stock'` (Default `shop`) und `sourceLocationId: String?`; fehlende Felder in alten Aufträgen = `shop`.
  - `class DeductionPlan { double fromOrder; double fromInvestment; double fromShop; }`
  - `DeductionPlan planDeduction({required double needed, required double stockOrder, required double stockInvestment})`: zuerst Auftrag, dann Investition, Rest `fromShop`.
  - `double internalCost({required DeductionPlan plan, required double catalogPrice, required double shopPrice})`: `fromOrder` 0, `fromInvestment * catalogPrice`, `fromShop * shopPrice`.
- UI: je Zeile ein Umschalter "Laden / Lager <Ort>" mit Anzeige des vorhandenen Bestands je Herkunft; interne Kosten in der Einkaufsliste nutzen `internalCost`. Kundenpreis und PDFs bleiben unberührt (Test, der die PDF-Summen vor und nach Quellenwahl gleich hält, falls die Berechnung dort getrennt testbar ist).
- [ ] **Step 1: Failing tests:** Bedarf 3, Auftrag 2, Investition 5 → 2/1/0; Bedarf 10, Auftrag 2, Investition 1 → 2/1/7; Kosten 0 € für reinen Auftragsanteil; Bedarf 0 → alles 0.
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren und UI anbinden. **Step 4:** PASS, manuell prüfen. **Step 5:** Commit `feat: stock source in shopping list`.

### Task 10: Automatischer Abzug beim Abschließen

**Files:**
- Modify: `lib/screens/orders/order_detail_sheet.dart`, `lib/data/order_repository.dart`
- Test: `test/completion_deduction_test.dart`

**Interfaces:**
- Consumes: Task 9 (`planDeduction`, Item-Felder), Task 2 (`applyMovement`), Task 1 (`stockApplied`).
- Produces: `Future<void> StockRepository.deductForOrder(SavedOrder order)`; reine Funktion `List<PlannedMovement> planOrderDeduction(SavedOrder order, Map<String, StockSnapshot> stock)` mit `PlannedMovement { materialId, locationId, origin, delta }`.
- Verhalten: Beim Abschließen wird für alle Items mit `source == 'stock'` abgezogen (Reason `order_deduction`, `orderId`), danach `stockApplied = true` in derselben Aktion. Ist `stockApplied` schon `true`, wird nichts erneut abgezogen. Zu wenig Bestand → Abzug bis 0, Status wird trotzdem `completed`; Rest in der Zusammenfassung als "aus Laden" gemeldet.
- [ ] **Step 1: Failing tests:** zwei Items aus Lager erzeugen Bewegungen in Reihenfolge Auftrag, Investition; `stockApplied == true` erzeugt keine Bewegungen; zu wenig Bestand klemmt auf 0 und liefert Shortfall; `shop`-Items erzeugen nichts.
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren, Abschließen-Handler ruft erst `deductForOrder`, dann Status, dann Rest-Abfrage. **Step 4:** PASS, manuell mit Doppelklick auf "Abschließen". **Step 5:** Commit `feat: deduct stock when completing an order`.

### Task 11: Abschluss und Deploy

- [ ] **Step 1:** `flutter test` und `flutter analyze` komplett, beide grün.
- [ ] **Step 2:** `firestore.rules` und `firestore.indexes.json` deployen **vor** dem App-Release (Ablauf siehe Memory "Deploy mechanics").
- [ ] **Step 3:** Manueller Durchlauf: Auftrag annehmen → Einkaufsliste mit einer Lager-Zeile → Abschließen → Rest per Text und per Sprache → Inventur prüfen → Verlauf prüfen.
- [ ] **Step 4:** Version in `pubspec.yaml` anheben und committen.

---

## Self-Review

- **Spec-Abdeckung:** Status (T1), Lagerorte und Nutzer (T2, T3), Rest-Abfrage überspringbar/nachholbar (T6), Inventurliste mit Korrektur und Verlauf (T7), Excel-Start (T8), Herkunft und Kosten (T9), Abzug (T10), Rollen und Regeln (T2), Kundenpreis unverändert (Global Constraints, T9).
- **Typen:** `StockOrigin`, `StockEntry`, `applyMovement`, `planDeduction` heißen überall gleich.
- **Proportion:** Kurz gehalten, Rümpfe bleiben beim Builder.
