# TripFlow iOS Case Study

## Kurzprofil

TripFlow ist ein lokaler iOS-MVP fuer Reiseplanung. Die App buendelt Trips, Stops, Tagesplanung, Kartenpunkte und Reiseunterlagen in einem einfachen Workflow.

Der zentrale Portfolio-Use-Case: Aus OCR-Text einer Reiseunterlage werden Reisedaten erkannt und als pruefbarer Stop-Vorschlag in einen Trip uebernommen.

## Problem

Reiseplanung verteilt sich oft auf mehrere Quellen: Kalender, Karten, Tickets, Hotelbuchungen und Reservierungsdokumente. Dadurch entstehen Medienbrueche, besonders wenn wichtige Daten aus Dokumenten manuell in eine Tagesplanung uebertragen werden muessen.

TripFlow fokussiert diesen Kernschmerz im MVP bewusst klein:

- Unterlagen erfassen
- relevante Reisedaten extrahieren
- Vorschlag sichtbar pruefen
- Stop erst nach Bestaetigung speichern

## Produktentscheidung

Der MVP ist local-first und offline-freundlich. Es gibt kein Account-System, keinen Cloud-Sync, kein Firebase, kein Booking-System und keine Social Features.

Diese Grenzen waren bewusst:

- Der Produktwert soll aus dem Reiseplanungs-Workflow kommen, nicht aus Infrastruktur.
- Der Scope bleibt klein genug, um Architektur, Tests und UI nachvollziehbar zu halten.
- Portfolio-Reviewer sehen einen kompletten, aber nicht ueberladenen iOS-MVP.

## Kernflow

1. Nutzer erstellt einen Trip.
2. Nutzer plant Stops mit Datum, Uhrzeit, Ort und optionalen Koordinaten.
3. TripFlow zeigt eine Tages-Timeline und Kartenpunkte.
4. Nutzer erfasst eine Reiseunterlage mit OCR-Text.
5. Parser erkennt Datum, Uhrzeit, Ort, Flugnummer, Zugnummer oder Referenz.
6. TripFlow zeigt einen Stop-Vorschlag in einer Review-Ansicht.
7. Nutzer kann Name, Datum und Uhrzeit korrigieren.
8. Speichern passiert erst nach Bestaetigung.

## Umsetzung

TripFlow ist als SwiftUI-App mit MVVM aufgebaut.

- `Models`: einfache SwiftData-Modelle fuer Trips, Stops und Reiseunterlagen
- `Views`: SwiftUI-Screens fuer Liste, Details, Timeline, Dokumente und Review
- `ViewModels`: UI-State, Validierung und Screen-Aktionen
- `Services`: Business-Logik fuer Trip-, Stop-, Timeline-, Map-, Dokument- und Parser-Funktionen
- `Components`: wiederverwendbare UI-Bausteine wie Status-Badges
- `Helpers`: kleine Hilfen wie konsistente Datums- und Zeitformatierung

Die Architektur bleibt bewusst pragmatisch: keine abstrakten Manager, keine grosse Schichtentrennung ohne Nutzen und keine Datenmigration fuer MVP-Polish.

## Sichtbarer MVP-Wert

Der Portfolio-Wert liegt nicht nur in CRUD, sondern im zusammenhaengenden Produktfluss:

- Trip-Uebersicht zeigt Planungsstatus, Zeitraum, Stops und Unterlagen.
- Trip-Detail kombiniert Timeline und MapKit-Ansicht.
- Dokument-Review macht erkannte Reisedaten sichtbar und editierbar.
- Validierung verhindert leere Stop-Namen und fehlende Daten beim Dokument-zu-Stop-Flow.

## Tests

Die Tests decken die zentrale MVP-Logik ab:

- Trip-Validierung und Planungsstatus
- Stop-Erstellung, Koordinaten und Timeline-Sortierung
- Map-Daten und Kartenregionen
- Dokument-Erstellung und Dokument-Detail-Logik
- OCR-/Dokumentparser fuer Datum, Uhrzeit, Ort und Referenzen
- Document-to-Stop-Review und Validierung
- konsistente deutsche Datums- und Zeitdarstellung

Der dokumentierte Testlauf:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TripFlow.xcodeproj -scheme TripFlow -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TripFlowTests
```

## Ergebnis

TripFlow ist als kompakter Portfolio-MVP abgeschlossen und als Git-Tag `v0.1.0-mvp` markiert.

Zum Abschlussstand gehoeren:

- lauffaehiger lokaler MVP
- README mit Demo-GIF und Screenshots
- Changelog
- fokussierter Produktflow
- getestete Kernlogik
- klare MVP-Grenzen

## Learnings

- Ein klarer MVP-Scope ist wichtiger als viele Randfeatures.
- OCR- und Parser-Flows brauchen eine Review-Ansicht, weil erkannte Daten nie blind gespeichert werden sollten.
- Kleine Services und testbare ViewModels reichen fuer diesen Produktumfang aus.
- Portfolio-Wirkung entsteht durch sichtbare Produktentscheidungen, Tests und gute Dokumentation, nicht durch Overengineering.

## Bewusst spaeter

Diese Ideen gehoeren nicht mehr in den abgeschlossenen MVP, waeren aber sinnvolle Folgeiterationen:

- echter Dokumentimport
- VisionKit-Scanner-Ausbau
- bessere OCR-Pipeline fuer Bilder oder PDFs
- App Intents
- Widgets
- Smart Parsing
