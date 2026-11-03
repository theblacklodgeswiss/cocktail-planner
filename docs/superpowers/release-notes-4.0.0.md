# Version 4.0.0 (Build 17)

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

## 4.0.1

- Angebots-Link: Unter "Cocktail- & Barservice" stehen jetzt die Cocktails und die gebuchten Zusatz-Services.

## 4.0.2

- Neue Besucher landen direkt im Anfrage-Formular statt auf der Login-Seite.

## 4.0.3

- Der Login-Screen ist entfernt: Besucher werden automatisch als Gast angemeldet und landen im Anfrage-Formular, auch nach dem Ausloggen.
- Mitarbeiter melden sich über "Mitarbeiter-Login" im Benutzermenü direkt mit Google an.
