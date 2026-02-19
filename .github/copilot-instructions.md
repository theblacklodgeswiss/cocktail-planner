# Copilot Instructions – Responsive Cocktail Planner

## Projektziel
Diese App ist ein **Responsive Cocktail Planner (Shopping List Generator)** mit drei Ebenen:
1. Dashboard + Auswahl
2. Übersicht der gewählten Cocktails
3. Einkaufsliste aus gefilterter Materialliste

## Technische Leitplanken
- Verwende **go_router** für Navigation.
- Verwende **easy_localization** für Texte und Lokalisierung.
- Globaler State ist `List<Recipe> selectedRecipes` in `lib/state/app_state.dart`.
- Datenquelle: Firestore (mit lokalem JSON-Fallback in `assets/data/`).
- Keine hartcodierten Rezept-/Materiallisten in Widgets.

## Deployment (CI/CD)
- **NIEMALS manuell deployen** mit `firebase deploy`
- Deployment erfolgt **automatisch** bei `git push origin main`
- GitHub Actions Workflow: `.github/workflows/deploy.yml`
- Firebase-Konfiguration liegt in **GitHub Secrets** (nicht im Code!)
- `lib/firebase_options.dart` ist in `.gitignore` - wird bei CI/CD generiert

## Datenmodell
- `materialListe`: enthält kaufbare Artikel inkl. Einheit, Preis, Währung, Bemerkung.
- `rezepte`: enthält Cocktailname und Zutatenliste.
- `fixedValues`: Fixkosten wie Van, Barkeeper, etc.
- `orders`: Gespeicherte Bestellungen (in Firestore)
- Einkaufsliste zeigt nur Material-Artikel, deren `artikel` in den ausgewählten `rezepte[].zutaten` vorkommt.

## UI/UX Regeln
- Dashboard zeigt gewählte Cocktails als `Card`-Liste.
- `FloatingActionButton` öffnet Full-Screen Auswahl mit Suche und Multi-Select.
- Cocktails können aus der Übersicht entfernt werden.
- Button **Einkaufsliste generieren** navigiert zum Ergebnis-Screen.
- Einkaufsliste: Zwei Spalten (Zutaten + Fixkosten) auf Desktop, gestapelt auf Mobile.
- Preis-Button oben rechts: Klick öffnet Export-Dialog → speichert in DB + generiert PDF.

## Implementierungsprinzipien
- Minimal und robust halten, keine unnötigen Features.
- Bestehende Struktur respektieren.
- Kleine, fokussierte Änderungen bevorzugen.
- Bei Erweiterungen zuerst Modell/Repository anpassen, dann UI.

## Tests (Pflicht)
- Nach jeder relevanten Änderung mindestens `flutter analyze` ausführen.
- Vor Abschluss immer `flutter test` ausführen.
- Wenn Tests fehlschlagen: Ursache beheben oder im Ergebnis klar benennen, was noch offen ist.

## Workflow für Änderungen
1. Code ändern
2. `flutter analyze` ausführen
3. `flutter test` ausführen
4. `git add -A && git commit -m "Beschreibung" && git push origin main`
5. GitHub Actions deployed automatisch auf Firebase Hosting
