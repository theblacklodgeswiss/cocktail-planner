# Microsoft Forms Excel Sync

## Überblick

Die App synchronisiert Anfragen aus einem Microsoft Forms-Formular, dessen Antworten automatisch in einer Excel-Datei auf OneDrive gespeichert werden.

**Excel-Datei:** `Cocktail- & Barservice Anftragformular.xlsx`  
**Speicherort:** OneDrive Root-Verzeichnis

---

## Excel-Spalten Mapping

Die Excel-Datei enthält die Formular-Antworten mit folgender Struktur:

| Index | Spalte | Inhalt | Verwendung |
|-------|--------|--------|------------|
| 0 | A | ID | Ignoriert (Forms-interne ID) |
| 1 | B | Startzeit | Ignoriert |
| **2** | **C** | **Abschlusszeit** | → `formCreatedAt` / `createdAt` |
| 3 | D | E-Mail | Ignoriert |
| 4 | E | Name (Antwortender) | Ignoriert |
| **5** | **F** | **Name** | → `offerClientName` (Auftraggeber) |
| **6** | **G** | **Kontakt** | → `phone` (Telefonnummer) |
| **7** | **H** | **EventDatum** | → `eventDate` (Excel-Serienwert) |
| **8** | **I** | **Startzeit** | → `offerEventTime` (z.B. "18:00") |
| **9** | **J** | **Ort** | → `location` (Veranstaltungsort) |
| **10** | **K** | **Gäste** | → `guestCountRange` (z.B. "100-200") |
| **11** | **L** | **Theke** | → `mobileBar` (Ja/Nein) |
| **12** | **M** | **EventTyp** | → `eventType` (z.B. "Hochzeitsfeier") |
| 13 | N | ServiceTyp | Ignoriert |
| 14 | O | Weitere Felder | Ignoriert |

---

## Datumsformat

Das EventDatum wird von Microsoft Forms als **Excel-Serienwert** gespeichert (nicht als lesbares Datum).

### Konvertierung

```
Excel-Serienwert = Anzahl Tage seit 30.12.1899
```

**Beispiel:**
- Excel-Wert: `46144`
- Berechnung: `1899-12-30 + 46144 Tage`
- Ergebnis: **22. Mai 2026**

### Code-Implementierung

```dart
final serialNum = int.tryParse(dateStr);
if (serialNum != null && serialNum > 40000) {
  eventDate = DateTime(1899, 12, 30).add(Duration(days: serialNum));
}
```

---

## Eindeutige Identifikation

Jede Formular-Einreichung erhält eine `formSubmissionId` basierend auf:

```
formSubmissionId = hash(Name + Telefon)
```

Dies ermöglicht:
- **Updates** bei erneutem Sync (keine Duplikate)
- **Stabilität** über mehrere Syncs hinweg

---

## Sync-Ablauf

1. **Authentifizierung** mit Microsoft Account (MSAL)
2. **Datei suchen** im OneDrive Root-Verzeichnis
3. **Excel lesen** via Microsoft Graph API (Worksheet: Sheet1, ab Zeile 2)
4. **Mapping** der Spalten gemäß obiger Tabelle
5. **Upsert** in Firestore (`orders` Collection)

---

## UI-Bedienung

**Bestellungsübersicht → Sync-Button (oben rechts)**

| Option | Beschreibung |
|--------|--------------|
| **Sync** | Aktualisiert existierende + erstellt neue Einträge |
| **Neu importieren** | Löscht alle Form-Einträge und importiert komplett neu |

### Suche & Sortierung

Die Bestellungsübersicht bietet:

**Suchfeld:**
- Suche nach **Name** (Auftraggeber)
- Suche nach **Gästeanzahl** (exakt oder Bereich wie "100-200")

**Sortieroptionen:**
| Option | Beschreibung |
|--------|--------------|
| Eventdatum | Sortiert nach dem Veranstaltungsdatum |
| Erstellt am | Sortiert nach dem Formular-Einreichungszeitpunkt |
| Gäste | Sortiert nach der Gästeanzahl |
| Name | Sortiert alphabetisch nach Name |
| Status | Sortiert nach Status (Angenommen → Angebot → Abgelehnt) |

**Sortierrichtung:**
- Aufsteigend (↑)
- Absteigend (↓)

---

## Datenbank-Schema

Form-Einträge werden in der `orders` Collection gespeichert mit:

```javascript
{
  source: "form",           // Unterscheidung von manuellen Bestellungen
  formSubmissionId: "...",  // Eindeutige ID
  hasShoppingList: false,   // Wird true wenn Einkaufsliste erstellt
  
  // Aus Excel:
  offerClientName: "...",
  phone: "...",
  eventDate: Timestamp,
  offerEventTime: "18:00",
  location: "...",
  guestCountRange: "100-200",
  mobileBar: true/false,
  eventType: "Hochzeitsfeier",
  
  // Standard-Felder:
  status: "quote",
  createdAt: Timestamp,
  items: []
}
```

---

## Fehlerbehebung

### Keine Einträge gefunden
- Prüfen ob Excel-Datei im OneDrive **Root** liegt (nicht in Unterordner)
- Dateiname muss exakt `Cocktail- & Barservice Anftragformular.xlsx` sein

### Falsche Daten/Namen
- Spalten-Mapping prüfen (Indizes 5-12)
- Debug-Output in Browser Console zeigt alle Spalten

### Duplikate nach Sync
- "Neu importieren" verwenden um sauber zu starten
- `formSubmissionId` basiert auf Name+Telefon - ändern sich diese, entsteht ein neuer Eintrag
