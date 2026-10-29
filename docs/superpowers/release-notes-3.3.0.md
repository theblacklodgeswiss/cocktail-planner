# Version 3.3.0 (Build 16)

## Neu für alle

- Neues Design für alle Screens: ruhige Glas-Optik, kompakte Karten, Hell- und Dunkelmodus.
- Feste Tab-Leiste für Mitarbeiter (Start, Aufträge, Inventur, Mehr) mit "+" für neue Anfragen.
- Anfrage-Formular in 5 Schritten mit klarer Fortschrittsanzeige.
- Bessere Bedienung mit großer Schrift, hohem Kontrast und reduzierten Animationen.

## Neu für Mitarbeiter und Admins

- Inventur: Rest-Abfrage per Sprache oder Text und Lagerbestand pro Lagerort.
- Einkaufsliste: Unterscheidung Laden und Lager.
- Angebot und Rechnung als geführte Abläufe in Schritten.
- Admin: Kennzahlen jetzt im Dashboard.
- Admin-Listen: Fehlgeschlagenes Löschen bleibt im Bestätigungs-Dialog mit Fehlermeldung und "Erneut versuchen"; Tabs behalten Scrollposition und Suche; Benutzerliste per Ziehen aktualisierbar.

## Hinweise zum Release

- Nach dem Update die Seite hart neu laden (Cache leeren oder Strg/Cmd+Shift+R), sonst liefert der PWA-Cache noch die alte Version.
- Firestore-Regeln und Indizes VOR dem Release deployen, jeweils separat und mit Prüfung der Bestätigungszeile:
  1. `firebase deploy --only firestore:rules --project <id>`
  2. `firebase deploy --only firestore:indexes --project <id>`
- Alte Clients kennen den Status "completed" nicht (und das neue Theme nicht): Nutzer müssen neu laden.
