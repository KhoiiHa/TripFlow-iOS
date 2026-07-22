# Changelog

## v0.2.1 - 2026-07-22

TripFlow schliesst den Dokumentflow von Version 0.2 mit lokaler Originaldatei und robusterem Reisezeit-Parsing ab.

### Verbessert

- Importierte Originalunterlagen lokal speichern, in Quick Look oeffnen, teilen und kontrolliert ersetzen
- Dateigroesse, Scan-Seitenzahl und doppelte Originalunterlagen vor der Speicherung pruefen
- Abfahrt und Ankunft mit eigenen Datums- und Uhrzeitwerten erkennen
- AM-/PM-Zeiten, Ankuenfte nach Mitternacht, ISO-Daten und ungueltige Kalenderdaten behandeln
- Mehrdeutige Datumswerte im Review markieren und Tag sowie Monat erst nach Nutzerentscheidung tauschen
- Reproduzierbaren Portfolio-Flow von erkannten Dokumentdaten bis zum bestaetigten Timeline-Stop zeigen

### Weiterhin bewusst nicht enthalten

- Automatische Stop-Speicherung ohne Nutzerbestaetigung
- Cloud-OCR oder Upload externer Reisedokumente
- Account-, Sync- oder Booking-Funktionen

## v0.2.0 - 2026-07-21

TripFlow verarbeitet Reiseunterlagen jetzt als durchgaengigen, lokal-first Workflow.

### Hinzugefuegt

- Bildimport mit lokaler Vision-Texterkennung
- PDF-Import mit eingebettetem Text und OCR-Fallback
- Dokumentenscan ueber VisionKit
- Review erkannter Reisedaten bereits im Dokumententwurf
- Flug- und Zugnummern als Kontext fuer Stop-Vorschlaege
- Zweistufige Bestaetigung: erst Unterlage speichern, dann Stop pruefen und erstellen
- Tests fuer Import, OCR, Parsing und die ausbleibende stille Stop-Speicherung
- Reproduzierbarer Portfolio-Screenshot der finalen Stop-Review

### Weiterhin bewusst nicht enthalten

- Automatische Stop-Speicherung ohne Nutzerbestaetigung
- Cloud-OCR oder Upload externer Reisedokumente
- Account-, Sync- oder Booking-Funktionen

## v0.1.0-mvp - 2026-07-10

TripFlow ist als kompakter Portfolio-MVP abgeschlossen.

### Enthalten

- Trip-Erstellung und Trip-Uebersicht mit Planungsstatus
- Stop-Erstellung mit Datum, Uhrzeit, Ort und optionalen Koordinaten
- Tages-Timeline fuer geplante Stops
- MapKit-Ansicht fuer Stops mit Koordinaten
- Reiseunterlagen mit Dokumenttyp, Dateiname und OCR-Text
- Parser fuer Datum, Uhrzeit, Ort, Flugnummer, Zugnummer und Referenznummer
- Document-to-Stop-Flow mit Review und Validierung vor dem Speichern
- Deutsche Datums- und Zeitdarstellung in sichtbaren MVP-Screens
- Unit Tests fuer zentrale Trip-, Stop-, Timeline-, Map-, Dokument- und Parser-Logik
- README mit Demo-GIF, Screenshots, Portfolio-Flow und MVP-Grenzen

### Bewusst nicht enthalten

- Account-System
- Cloud-Sync
- Firebase
- Booking-System
- Social Features
- Wetter-, Budget- oder Routenoptimierung

### Naechste moegliche Iterationen

- Echter Dokumentimport
- VisionKit-Scanner-Ausbau
- App Intents
- Widgets
- Smart Parsing
