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
- Datenquelle ist **ausschließlich** `assets/data/cocktail_data.json`.
- Keine hartcodierten Rezept-/Materiallisten in Widgets.

## Datenmodell
- `materialListe`: enthält kaufbare Artikel inkl. Einheit, Preis, Währung, Bemerkung.
- `rezepte`: enthält Cocktailname und Zutatenliste.
- Einkaufsliste zeigt nur Material-Artikel, deren `artikel` in den ausgewählten `rezepte[].zutaten` vorkommt.

## UI/UX Regeln
- Dashboard zeigt gewählte Cocktails als `Card`-Liste.
- `FloatingActionButton` öffnet Full-Screen Auswahl mit Suche und Multi-Select.
- Cocktails können aus der Übersicht entfernt werden.
- Button **Einkaufsliste generieren** navigiert zum Ergebnis-Screen.
- Einkaufsliste verwendet `GridView.extent` für responsive Darstellung.
- Jede Zutat enthält Eingabefeld mit numerischer Tastatur:
  - `ListTile(trailing: SizedBox(width: 60, child: TextField(...)))`

## Implementierungsprinzipien
- Minimal und robust halten, keine unnötigen Features.
- Bestehende Struktur respektieren.
- Kleine, fokussierte Änderungen bevorzugen.
- Bei Erweiterungen zuerst Modell/Repository anpassen, dann UI.

## Tests (Pflicht)
- Nach jeder relevanten Änderung mindestens `flutter analyze` ausführen.
- Vor Abschluss immer `flutter test` ausführen.
- Wenn Tests fehlschlagen: Ursache beheben oder im Ergebnis klar benennen, was noch offen ist.
