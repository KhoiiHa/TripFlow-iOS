# TestFlight-Checkliste

Stand: 22. Juli 2026

## Im Repository vorbereitet

- Version `0.2.1`, Build `4`
- Eindeutige Bundle-ID `de.KhoiiHa.TripFlow`
- Opaques App-Store-Icon mit 1024 x 1024 Pixeln
- Kamerahinweis fuer den Dokumentenscanner
- Gueltiges `PrivacyInfo.xcprivacy` ohne Tracking, Datenerhebung oder Required-Reason-APIs
- Oeffentliche [Datenschutzrichtlinie](PRIVACY.md) und Link aus der App
- Erfolgreicher Release-Build und erfolgreiches unsigned iOS-Archive
- Erfolgreiche Unit- und Screenshot-UI-Tests fuer den dokumentierten 0.2-Stand

## In Xcode und App Store Connect erforderlich

1. Apple-Developer-Account in Xcode anmelden und dem App-Target ein Developer-Team zuweisen.
2. App-Record in App Store Connect mit der Bundle-ID `de.KhoiiHa.TripFlow` anlegen.
3. Unter App Privacy "Keine Daten werden erhoben" auswaehlen und diese URL hinterlegen:
   `https://github.com/KhoiiHa/TripFlow-iOS/blob/main/PRIVACY.md`
4. Ein signiertes Release-Archive fuer `Any iOS Device` erzeugen.
5. Im Organizer `Distribute App` und anschliessend `TestFlight & App Store` waehlen.
6. Build zuerst nur fuer eine interne Testgruppe freigeben.

## Manueller Geraetetest vor dem Upload

- Trip erstellen, bearbeiten und loeschen
- Stop manuell erstellen und in Timeline sowie Karte pruefen
- Bild und PDF importieren und OCR-Text vor dem Speichern pruefen
- Mehrseitiges Dokument mit VisionKit auf einem echten iPhone scannen
- Mehrdeutiges Datum im Stop-Review bewusst korrigieren
- Vorgeschlagenen Stop erst nach Review speichern
- Originalunterlage in Quick Look oeffnen, teilen und ersetzen
- Flugmodus pruefen: bestehende Trips, Stops und Dokumente bleiben lokal nutzbar

## Aktueller externer Blocker

Auf dem Entwicklungs-Mac ist derzeit kein Apple-Development- oder Apple-Distribution-Zertifikat und kein Xcode-Developer-Team eingerichtet. Deshalb koennen signierter Geraetetest und TestFlight-Upload erst nach der Account-Anmeldung ausgefuehrt werden.
