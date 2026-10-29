# Komplettes Redesign (Gast, Kunde, Mitarbeiter) – Design

Status: Entwurf, wartet auf Freigabe. Plattform: Flutter Web (Material 3). Sprache der App: Deutsch (`easy_localization`, `.tr()`), Englisch bleibt.

## Warum

Alle Screens wirken gleich ("monoton"): Standard-Grün, überall dieselbe Card/ListTile-Optik, keine Hierarchie, kaum Bewegung. Die App ist nicht fürs Handy gebaut (breite Tabellen, Formulare mit vielen Feldern in einer Spalte, Buttons, die vom Bildschirm scrollen). Der Nutzer will ein echtes Redesign für **nicht eingeloggt/Kunde** und **eingeloggt (Mitarbeiter/Admin)**, handyfirst.

## Entschiedene Richtung (vom Nutzer an Mockups bestätigt)

**Maßgebliches Mockup:** `.superpowers/brainstorm/96517-1793052487/content/visual-glass.html` (Aufträge Mitarbeiter, Start Gast). Vom Nutzer bestätigt ("j passt"). Frühere Varianten (`visual-apple-v3` bis `v10`) sind verworfen: graue Zeilenlisten mit Pfeilen und Segment-Schalter wirken wie älteres iOS. Wo weiter unten "gruppierte Liste/Zeile" steht, ist eine Folge **einzelner schwebender Karten** gemeint.

- **Stil:** Aktueller Apple-Look ("Glas"): ruhig, schwebend, große Rundungen. Heller Hintergrund (leichter Verlauf `#F6F6F8`→`#ECECF0`), weiße Karten mit weichem Schatten, Schwarz für Text, Hauptbutton und die Blickfang-Karte. **Gold aus dem Blacklodge-Logo nur als kleiner Akzent** (Beschriftung auf der schwarzen Karte, große Zahl, Schritt-Ziffern, Status-Punkt "angenommen"). Kein Blau, keine weiteren Farben. Gold nie als Fläche, nie für Buttons oder Überschriften.
- **Kompakt, überall (Nutzer: "alles viel kompakter"):** mehr Inhalt pro Bildschirm, weniger Scrollen. Kleinere Titel, niedrige Buttons, enge Listenzeilen, flache Fotos, kleine Zahlen, kleine Abstände. Die Maße aus Mockup v3 sind der **Startpunkt, es darf nur noch dichter werden**, nie lockerer. Dichte gilt auch für Formulare (weniger Felder pro Schritt sichtbar nötig, Felder einzeilig, Beschriftung klein darüber) und Dialoge/Sheets (keine großen Innenabstände).
- **Dichte-Regeln:** Karte mit zwei Textzeilen 46–52 px hoch, Abstand zwischen Karten 8 px, Button 36–40 px, Pillen 26–30 px, Seitenrand 14 px, Abstand zwischen Abschnitten 12 px. Das Glas-Mockup ist die Referenz; Nutzer fand die Variante "zu eng aufeinander" (v5, Zeilen 27 px) **zu dicht**: nicht unter diese Werte gehen. Einzeilige Zeilen mit Datum als Text sind verboten (wirkten wie eine Tabelle). Die sichtbare Fläche ist klein, die **Tippfläche** bleibt trotzdem mindestens 44 px (unsichtbares Padding, `MaterialTapTargetSize.padded`). Nichts darf dadurch bei 360 px überlaufen.
- **Struktur:** Jeder Eintrag ist eine eigene schwebende weiße Karte (Radius 20, weicher Schatten, keine Trennlinien, keine Pfeile). Pro Screen **ein** Blickfang: eine schwarze Karte (Radius 24–30, z. B. "Nächster Termin" mit Countdown, auf dem Start das Hero). Große Überschrift allein in ihrer Zeile (nie neben Kennzahlen). Filter als Pillen mit Zähler. Schwebende **Glas-Leiste** unten für Mitarbeiter (Pille, Blur, aktiver Eintrag schwarz) plus runder schwebender "+"-Button; auf Start/Formular ein Glas-Pille-Button, der über dem Inhalt schwebt. Ein Thema pro Formularschritt, dünner Fortschrittsbalken, Zähler im Weiter-Button.
- **Leitlinien aus den installierten Skills** (`apple-design`, `emil-design-eng`, Prinzipien, kein Web-Code): Rückmeldung sofort beim Antippen (leichtes Verkleinern auf 0,97), Animationen kurz (unter 300 ms, Ease-out, nie Ease-in), nichts animieren, was oft benutzt wird; Ein- und Ausblenden auf demselben Weg; nur `transform`/`opacity` animieren; Reduced-Motion respektieren; Schrift mit negativer Laufweite bei großen Titeln.

## Ziele

- Neues **Design-System** als Code: Farben, Schrift, Abstände, Radien, Bewegung als Tokens plus wenige geteilte Bausteine (siehe unten). Alle Screens benutzen sie, keine verstreuten `Colors.*`, `fontSize`, `SizedBox`-Werte mehr in neuen oder umgebauten Screens.
- **Handy zuerst**: jeder Screen funktioniert bei 360 px Breite ohne horizontales Scrollen, Tippflächen mindestens 44 px, Tastatur verdeckt keinen Button, Hauptaktion mit dem Daumen erreichbar.
- **Weniger Formular**: lange Formulare werden Schritt-für-Schritt-Abläufe oder Inline-Bearbeitung (Details unten).
- **Gast und Kunde**: Start, Login, Bestellformular, Erfolg, Meine Anfragen, öffentliche Angebotsseite, Einstellungen.
- **Mitarbeiter und Admin**: Dashboard, Aufträge, Auftragsdetail, Inventur, Admin, Angebot/Rechnung, Einkaufsliste, Einstellungen.
- Hell und Dunkel bleiben auswählbar. Dunkel = invertierte Neutraltöne (kein farbiger Dunkelmodus).
- Leichte, sinnvolle Bewegung: Seitenübergänge, Sheets, Auswahl-Haken, Fortschritt. Keine Dekoration.

## Nicht-Ziele

- Keine Änderung an Daten, Rollen, Firestore, Routen, PDFs, Preisen, Berechnungen (siehe "Verträge").
- Kein neues Logo, keine Marken-Neuentwicklung, keine eigene Schrift (Systemschrift).
- Keine neuen Features. Ausnahmen sind unten ausdrücklich genannt.
- Kein Redesign der PDF-Layouts (Angebot, Rechnung).
- Keine iOS/Android-Apps; Flutter Web bleibt.

## Anti-Ziele (wäre ein Fehlschlag)

- Wieder alles gleich aussehend, nur in Grau.
- Ein Screen, der bei 360 px überläuft oder eine Hauptaktion verdeckt.
- Logik, Routen oder Datenfelder aus Versehen verändert.
- Funktionen, die vorher gingen, sind nicht mehr erreichbar (z. B. Admin-Funktionen im neuen Menü "Mehr" versteckt).
- Animationen, die Eingaben blockieren oder bei Reduced-Motion weiterlaufen.

## Design-System (Soll)

**Farben (hell):** Hintergrund Verlauf `#F6F6F8`→`#ECECF0`, Karte `#FFFFFF`, Kachel/Fläche `#F2F2F5`, Text `#1D1D1F`, Text zweitrangig `#6E6E73` bzw. `#86868B`, deaktiviert `#C7C7CC`, Hauptbutton und Blickfang-Karte Schwarz `#1D1D1F` mit weißer Schrift. **Gold (geschätzt aus dem Logo, offizielle Werte stehen aus):** auf Schwarz `#F0C35A` (Zahl) und `#E0B04A` (Beschriftung), auf Weiß dunkler `#B8861F` (Ziffern) bzw. `#C9962B` (Status-Punkt). Das helle Gold nie auf Weiß (zu schwach). Status: "angenommen" goldener Punkt, "Angebot" grauer Punkt `#C7C7CC`, "abgeschlossen" hellgrauer Punkt `#E5E5EA`. **Glas:** weiß mit 62 % Deckkraft, Blur 22, Sättigung 180 %, 1 px heller Rand, weicher Schatten; bei Reduced-Transparency/Contrast fast deckend. Fehler/Warnung: dezentes Rot nur für echte Fehler und destruktive Aktionen (Löschen). **Dunkel:** `#000000`/`#1C1C1E` Flächen, `#F5F5F7` Text, gleiche Struktur. Das genaue Dunkel-Paar legt der Builder fest und listet es.

**Schrift:** Systemschrift (keine Schrift-Dateien). Skala klein, eng und kompakt: Großer Titel 22–24 px (Gewicht 700, Laufweite −0,9), Abschnittstitel 14–15 px (600), Fließtext 12 px, Zweittext 10–11 px, Zahlen 16–17 px. Das sind Startwerte; eine Stufe kleiner ist erlaubt, solange Lesbarkeit (mindestens 10 px) und Systemschriftgröße-Skalierung bleiben.

**Abstände/Radien:** 4-px-Raster mit Schwerpunkt auf kleinen Werten (4, 8, 12, 16, 24). Radius 10–12 für Gruppenflächen und Buttons, 14 für große Flächen, 999 für Pillen. Seitenrand 14–16 px auf dem Handy, Inhaltsbreite maximal 720 px auf großen Bildschirmen (zentriert), auf dem Desktop ebenfalls kompakt (kein künstliches Aufblähen).

**Bewegung:** Dauer 100–160 ms Druck-Rückmeldung, 200–300 ms Seiten, Sheets, Schritte. Ease-out `cubic-bezier(0.23, 1, 0.32, 1)`. Seitenübergang im Cupertino-Stil (von rechts, zurück nach rechts). Reduced-Motion: Überblenden statt Verschieben.

**Geteilte Bausteine (neu, in `lib/ui/`):** `AppTheme` (hell/dunkel, ersetzt `ColorScheme.fromSeed(Colors.green)` in `lib/app.dart`), `AppTokens`, `LargeTitleScaffold` (große Überschrift, die beim Scrollen klein wird, mit durchsichtiger Leiste), `FloatingCard` (weiße Karte, Radius 20), `HeroCard` (schwarze Blickfang-Karte), `DateTile` (Datum-Kachel), `PillFilter` (Pillen mit Zähler), `GlassSurface` (Blur-Fläche), `GlassCtaBar` (schwebende Button-Pille), `FloatingFab`, `PrimaryButton`/`SecondaryButton`/`TextAction` (mit Druck-Rückmeldung und Ladezustand), `StepScaffold` (Fortschrittslinie, Schritt n von m, Zurück, fester Weiter-Button mit Tastatur-Abstand), `StatusDot`, `EmptyState`, `LoadingState`, `ErrorState`, `AppSheet` (Bottom-Sheet statt Dialog auf dem Handy), `ConfirmSheet`, `StaffTabBar` (schwebende Glas-Pille: Aufträge, Inventur, Mehr; "Neu" ist der runde schwebende "+"-Button darüber). Die vorhandenen Bausteine `SummaryCard`, Status-Pillen und Inline-Spinner werden durch diese ersetzt.

## Screens (Soll)

### Nicht eingeloggt und Kunde
- **Login:** klare Wahl "Mit Google anmelden" (schwarz) und "Als Gast fortfahren" (Text). Ein Satz, was die App kann, und ein Hinweis, was Gast bedeutet. Alle Texte über `.tr()` (heute teils fest in Deutsch).
- **Start (Kunde/Gast):** großer Titel, ein Satz, ein flaches Foto (Platzhalter bis echte Bilder da sind), drei Schritte als Liste, fester Button "Anfrage starten" immer sichtbar. Eigene Anfragen als gruppierte Liste. Gäste bekommen einen "Anmelden"-Hinweis in der Liste.
- **Bestellformular (9 Schritte, heute 3.685 Zeilen):** Schritte neu zuschneiden auf etwa 5: (1) Anlass und Art, (2) Datum, Uhrzeit, Ort, Gäste, (3) Kontakt, (4) Getränke (Cocktails, Shots, Bar-Getränke; Zeilenliste mit Haken und Zähler im Button; Beliebtheit als optionaler Unterpunkt, standardmäßig ausgeblendet), (5) Zusatzleistungen und Übersicht. Pflichtfelder werden **am Feld** erklärt, nie nur durch einen gesperrten Button. Tastatur: Weiter-Taste springt zum nächsten Feld, Autofill-Hinweise für Name/Telefon/Adresse. Fortschritt "Schritt n von 5". Fehler- und Ladezustände mit `LoadingState`/`ErrorState`.
- **Erfolg:** kurze ruhige Bestätigung, Link zu "Meine Anfragen", für Gäste Hinweis zum Anmelden.
- **Meine Anfragen / Detail:** gruppierte Liste mit Status als Punkt plus Text, Detail als Sheet mit gruppierten Zeilen (Datum, Ort, Gäste, Getränke als Liste), klare nächste Aktion ("Bestätigung als PDF").
- **Öffentliche Angebotsseite (`/s/:code`):** oben Firmenname, eine **Zusammenfassung** (Anlass, Datum, Gesamtpreis, Positionen) als Liste, das PDF als "Angebot ansehen" darunter statt als Hauptansicht, Annehmen/Ablehnen mit Bestätigungssheet.
- **Einstellungen:** gruppierte Liste, maximale Breite, rechtliche Seiten typografisch ruhig.

### Mitarbeiter und Admin
- **Navigation:** untere durchsichtige Leiste **Aufträge, Inventur, Neu, Mehr**. "Mehr" enthält Dashboard-Kennzahlen, Admin, Einstellungen, Benutzer, Mitarbeiter, Services (jeweils nur mit passender Rolle). Das Nutzermenü wird in "Mehr" aufgenommen. Alle bisherigen Einstiege bleiben erreichbar.
- **Dashboard:** ersetzt die drei doppelten Status-Karten durch eine Zahlenzeile (Offen, Angenommen, Diese Woche) plus die nächsten Termine als Liste. Totes `dashboard/dashboard_screen.dart` wird gelöscht.
- **Aufträge:** große Überschrift, Segment-Filter, Zahlenzeile ohne Kästen, gruppierte Liste (Datum links, Name, Gäste/Ort, Status als Punkt). Die Tabelle weicht der Liste auf dem Handy; auf breiten Bildschirmen bleibt eine Tabelle möglich.
- **Auftragsdetail (heute 2.111 Zeilen):** aufteilen in Kopf (Name, Status, nächste Hauptaktion), Abschnitte als gruppierte Listen (Termin, Kunde, Getränke, Einkaufsliste, Mitarbeiter, Angebot/Rechnung). **Eine** Hauptaktion je Status, weitere Aktionen in einem Menü. Dialoge werden Sheets.
- **Einkaufsliste:** Schritte pro Cocktail bleiben, Mengen-Stepper mit mindestens 44 px, Laden/Lager-Umschalter als Zeile.
- **Inventur (neu):** Karten- oder Zeilenliste pro Artikel statt breiter Tabelle, Lagerorte als Segment oder Ausklapper, Menge antippen für Korrektur, Verlauf als Sheet. Excel-Import und Rest-Abfrage als Vollbild-Sheets mit passender Breite.
- **Admin:** Artikel, Rezepte, feste Werte als Listen mit Bearbeiten im Sheet (keine Dreier-Feldreihen mehr), Hinzufügen per "+" statt dauerhaft offenem Formular (Mitarbeiter, Services). Dialogbreiten flexibel, Tastatur berücksichtigt.
- **Angebot/Rechnung erstellen (je über 2.000 Zeilen):** ein Schrittablauf: Kunde und Termin, Leistungen und Mitarbeiter, Positionen, Preis und Rabatt, Senden. Die Aktionsleiste wird eine feste untere Leiste mit einer Hauptaktion und einem Menü.
- **Einstellungen und Benutzerverwaltung:** gruppierte Listen.

## Verträge (dürfen sich nicht ändern)

- **Routen und Parameter:** `/orders?status=`, `/orders/years`, `/orders/pending`, `/pending-orders`, `/shopping-list` (extra: Bestellvorgabe), `/order-form` (extra: optionaler `SavedOrder`, `?step=n`), `/create-offer` und `/create-invoice` (extra: `SavedOrder`), `/settings/*`, `/s/:code` (öffentlich), `/inventory`, `/admin`, Weiterleitung nach Login und Logout, Auth-Redirect mit Ausnahme `/s/`.
- **Rollen:** `AppRole`-Reihenfolge, `authService.isEmployeeOrHigher/isAdmin/canManageUsers/isSuperAdmin`, `roleResolved`, alle bestehenden Rollen-Sperren (Löschen nur Super-Admin, Excel-Import nur Admin, Benutzer/Services nur `canManageUsers`).
- **Daten:** `orderRepository`-Signaturen, Zählregeln (offen = `total == 0 && !isPendingDismissed`, angenommen nutzt `isAccepted`), Statusregeln (Annehmen braucht `total > 0`, Abschließen und Zurücksetzen), Feldnamen beim Speichern von Anfragen, die Rückgaben von `showRestEntrySheet` und `showOrderDetails` samt Weiterleitung für Formular-Aufträge, `onItemsChanged`/`pop(true)` der Einkaufsliste, Share-Link-Funktionen und PDF-Generatoren.
- **Formularlogik:** Service-Typ-Werte (`'cocktail_barservice'` usw.), Alkoholfrei-Regeln, Adresse→Entfernung mit Verzögerung und Veraltet-Schutz, `_canProceed` und Sprung auf fehlerhaften Schritt, alte Zusatzleistungs-IDs.
- **Übersetzungen:** vorhandene `.tr()`-Schlüssel bleiben; neue Schlüssel in Deutsch und Englisch (Gleichstand wird getestet).
- Das rote DEV-Banner in Nicht-Produktions-Builds bleibt.

## Entscheidungen, die ich getroffen habe (bitte beim Lesen prüfen)

- Gold nur als kleiner Akzent, Hauptbutton Schwarz (Nutzer: kein großes Blau, weniger Farben, "nur die Akzente gold").
- Navigation für Mitarbeiter: schwebende Leiste Aufträge, Inventur, Mehr plus runder "+"-Button für Neu; Kunden und Gäste haben keine untere Leiste. Mein Vorschlag zu Landing und Navigation: Mitarbeiter landen nach dem Login auf der Auftragsliste (Routen bleiben gleich). **Vom Nutzer bestätigt ("ja genau").**
- Der Nutzer hat bisher nicht gesagt, ob Mitarbeiter die App auch am Desktop nutzen (Angebote, Rechnungen, Excel-Import). Annahme bis zur Antwort: Handy zuerst, auf breiten Bildschirmen dieselbe Optik zentriert (max. 720 px) und für Inventur/Angebot/Rechnung zusätzlich eine breite Darstellung.
- Bestellformular von 9 auf etwa 5 Schritte; Beliebtheit der Cocktails wird optionaler Unterpunkt statt eigener Schritt.
- Auf Bildern: bis echte Cocktailfotos vorliegen, graue Platzhalter-Flächen im festen Seitenverhältnis. Der Nutzer liefert Fotos später oder entscheidet, ohne Bilder zu leben.
- Dunkelmodus bleibt, in Neutraltönen.
- Zwei kleine Fehler, die beim Audit auffielen, werden im Redesign mit behoben, weil sie dieselben Screens betreffen: (1) Anonyme Gäste sehen ihre gesendeten Anfragen nicht (`authService.isSignedIn` ist für Gäste false); (2) `/create-offer` und `/create-invoice` stürzen bei fehlendem `extra` ab (z. B. nach Neuladen). Beides nur dort beheben, wo der betroffene Screen ohnehin umgebaut wird; wenn das Verhalten Routen oder Rollen ändern würde, stattdessen als eigenes Ticket melden.
- Das tote `dashboard/dashboard_screen.dart` wird gelöscht.
- Staff-Routen ohne Rollen-Sperre im Router (`/dashboard`, `/shopping-list`, `/create-offer`, `/create-invoice`) werden **nicht** im Redesign geändert; als Hinweis an den Nutzer melden.

## Weitere Entscheidungen aus der Builder-Prüfung (meine Entscheidungen)

- Bei Widerspruch zwischen Zahlen im Dokument gilt die **dichtere/spezifischere**, mit der Untergrenze aus den Dichte-Regeln.
- Die zwei Audit-Fehler (Gäste sehen ihre Anfragen nicht; `/create-offer` und `/create-invoice` stürzen nach Neuladen ab) sind **eigene Tickets, nicht Teil des Redesigns**, weil sie Regeln oder Routen berühren können. Im Redesign wird nur ein Anmelden-Hinweis für Gäste gezeigt.
- Bestellformular: Logik und Verträge bleiben. `?step=n` wird über eine Tabelle von alten (9) auf neue (5) Schritte umgerechnet. Pflichtfeld-Hinweise am Feld kommen **zusätzlich** zu `_canProceed`. "Beliebtheit" wird optionaler Unterpunkt in Schritt 4 (der bestehende Dialog bleibt nutzbar).
- Stufe 0 darf mit dem neuen Theme sichtbar gemischte Zwischenzustände zeigen, aber alte Screens müssen **lesbar** bleiben: Farben der Alt-Rollen (`primary`, `primaryContainer` usw.) werden auf Schwarz/Grau/Weiß abgebildet, nicht auf Grün. Ausgeliefert wird erst nach Stufe 1 und 3, sonst nur auf dev.
- Neue deutsche und englische Texte (z. B. Startseite "Deine Bar. Dein Abend.") schreibe ich; Tests für ersetzte Bausteine (`SummaryCard`, Status-Pillen) werden neu geschrieben, nicht gelöscht.

## Lieferstufen (jede für sich auslieferbar)

0. **Fundament:** `lib/ui/` mit Tokens, `AppTheme`, Bausteinen, Seitenübergängen; `lib/app.dart` umstellen; Dunkelmodus-Paar; Tests für Tokens/Übersetzungen. Alte Screens laufen unverändert weiter in neuem Theme.
1. **Gast und Kunde:** Login, Start, Erfolg, Meine Anfragen (+ Detail), Einstellungen, öffentliche Angebotsseite.
2. **Bestellformular** neu zuschneiden (Schritte), eigenständig wegen Größe und Risiko.
3. **Mitarbeiter-Rahmen:** `StaffTabBar`, "Mehr", Dashboard, Aufträge, Auftragsdetail (zuerst aufteilen).
4. **Inventur und Einkaufsliste** (neue, kleine Screens, ohne Altlast).
5. **Admin, Angebot, Rechnung, Einstellungen/Benutzer** (große Dateien zuerst in Abschnitte aufteilen, dann stylen).

## Dem Builder überlassen

Genaue Pixelwerte (Startwerte aus Mockup v3), Dunkel-Farbpaar, Aufteilung der großen Dateien in Widgets, Auswahl der Flutter-Widgets für große Titel und Tab-Leiste, Umgang mit breiten Bildschirmen (Tabelle vs. Liste), Seitenübergangs-Implementierung, Test-Strategie (Widget-Tests für Bausteine, Golden-Tests nur wenn billig), Reihenfolge innerhalb der Lieferstufen.
