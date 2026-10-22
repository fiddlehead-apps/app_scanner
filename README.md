# Sola Scanner (iOS)

Dokumente mit dem iPhone scannen und direkt als durchsuchbares PDF in einem vorher gewählten
Ordner ablegen, mit vorgegebenem Namen. Apple Intelligence liest auf Wunsch Titel, Absender,
Datum und Betrag aus dem Dokument. SwiftUI, keine Abhängigkeiten, iPhone und iPad, ab iOS 26,
Deutsch und Englisch.

* Kein Server, kein Konto. Kamera (VisionKit), Texterkennung (Vision) und Apple Intelligence
  (Foundation Models, das Sprachmodell auf dem Gerät) laufen auf dem iPhone.
* Gleicher Look wie die anderen Sola-Apps, Akzentfarbe Petrol.

## Was die App kann

**Scannen:** *Scannen* öffnet Apples Dokumentkamera. Sie erkennt die Seitenränder live, löst
selbst aus und begradigt die Seite; mehrere Seiten hintereinander werden ein Dokument. Mit
*Jede Seite ein eigenes Dokument* wird jede Seite eine eigene Datei (z. B. ein Stapel
Quittungen). *Fotos* nimmt stattdessen Bilder aus der Mediathek.

**Ordner vorgeben:** *Speichern in* wählt den Zielordner. Standard ist der App-Ordner
(Dateien-App → Auf meinem iPhone → Sola Scanner); *Anderen Ordner wählen …* nimmt jeden Ordner
aus der Dateien-App, auch iCloud Drive, USB-Stick oder Netzlaufwerk. Die App merkt sich die
Ordner (Security-Scoped Bookmarks) zum schnellen Umschalten. Ist ein Ordner nicht mehr
erreichbar, landet der Scan im App-Ordner, damit nichts verloren geht.

**Namen vorgeben:** Das Feld *Dateiname* ist eine Vorlage aus Text und Platzhaltern, z. B.
`Steuer 2026 {Nr.}` oder `{Datum} {Absender} {Titel}`. Die Chips fügen Platzhalter ein,
darunter steht ein Beispiel. Deutsche und englische Namen funktionieren beide.

| Platzhalter | Wert |
| --- | --- |
| `{Datum}` | Datum auf dem Dokument (Apple Intelligence), sonst heute, als `2026-10-22` |
| `{Uhrzeit}` | Uhrzeit des Scans, `14-05` |
| `{Titel}` ✨ | kurzer Titel, z. B. „Stromrechnung September 2026“, ohne AI „Scan“ |
| `{Absender}` ✨ | Firma, Behörde oder Person, die das Dokument geschickt hat |
| `{Art}` ✨ | Rechnung, Quittung, Brief, Vertrag, Auszug, Formular, Bescheinigung, Bescheid, Anleitung, Dokument |
| `{Nr.}` | fortlaufende Nummer, `001`, `002`, … |

Gibt es den Namen schon, wird „ 2“, „ 3“ … angehängt. Ungültige Zeichen (`/ : ?` …) werden
ersetzt. Nach dem Speichern lässt sich die Datei umbenennen.

**Apple Intelligence** (✨, schaltbar): Nach der Texterkennung liest das Sprachmodell auf dem
Gerät Titel, Art, Absender, Datum, Betrag, eine Zusammenfassung und bis zu 5 Stichwörter. Sie
stehen im Ergebnis, im Verlauf und als Metadaten im PDF (Titel, Autor = Absender, Betreff =
Zusammenfassung, Stichwörter). Braucht ein iPhone mit Apple Intelligence (ab iPhone 15 Pro)
und eingeschaltetes Apple Intelligence; sonst sagt der Schalter, warum er aus ist, und die
Scans werden nur mit Texterkennung gespeichert. Lange Dokumente werden für das Modell gekürzt
(erst 6000, dann 2500 Zeichen).

**PDF:** Seiten als JPEG (max. 2400 px, etwa 250 dpi bei A4), Seitenbreite A4, darüber der
erkannte Text als unsichtbare Ebene. Dadurch finden Dateien-App und Spotlight den Inhalt, und
Text lässt sich markieren. Eine Briefseite hat etwa 150 KB.

**Verlauf:** *Letzte Scans* auf dem Startbildschirm, durchsuchbar nach Name und Text. Antippen
zeigt PDF, Angaben und erkannten Text; teilen, umbenennen, aus der Liste entfernen oder die
Datei löschen.

## Daten

`scanner.json` in Application Support (Verlauf mit erkanntem Text, Ordner-Bookmarks,
Vorlage, Zähler, Schalter). Die PDFs liegen nur im gewählten Ordner. Kein iCloud-Sync in der
App; wer einen Ordner in iCloud Drive wählt, bekommt den Sync von iOS.

## Bauen

`./build.sh` baut fürs iPhone und installiert, `./build.sh --sim` nur für den Simulator
(schneller Check). `../build-sola-apps.sh scanner` geht auch.

Bundle-ID und Team kommen aus `Config/Config.xcconfig` (`eu.fiddlehead.sola.scanner`,
Projekt `SolaScanner.xcodeproj`). Das kostenlose Personal Team darf nur 10 neue App-IDs in 7
Tagen anlegen; schlägt der erste iPhone-Build deshalb fehl, warten oder mit dem bezahlten Team
signieren (`SOLA_TEAM` in `../sola-local.xcconfig`).

Im Simulator gibt es keine Kamera-Seiten zum Scannen. In Debug-Builds scannt
`-debugScreen sample` einen erzeugten Beispielbrief (ganzer Ablauf inkl. Apple Intelligence,
läuft auf einem Mac mit Apple Intelligence auch im Simulator), `-debugScreen settings` öffnet
die Einstellungen.

Icon neu erzeugen: `python3 tools/make_icon.py` (braucht Pillow).

## Dateien

| Datei | Inhalt |
| --- | --- |
| `HomeView.swift` | Startbildschirm: Ordner, Dateiname, Schalter, Scannen, Verlauf |
| `ProcessingView.swift` | Fortschritt und Ergebnis nach dem Scan, Angaben von Apple Intelligence, Umbenennen |
| `DocumentView.swift` | ein gespeicherter Scan: PDF-Vorschau, Angaben, Text, Teilen, Löschen |
| `SettingsView.swift` | Ordnerliste, Verlauf leeren |
| `Processor.swift` | Ablauf nach dem Scan: Texterkennung, Apple Intelligence, Name, Speichern |
| `PDFMaker.swift` | Bilder verkleinern, Texterkennung (Vision), PDF mit Textebene und Metadaten |
| `Assistant.swift` | Apple Intelligence (Foundation Models): Verfügbarkeit, Angaben lesen |
| `Files.swift` | Schreiben, Umbenennen, Löschen im gewählten Ordner (Security Scope, File Coordination) |
| `Store.swift` | Verlauf, Ordner, Vorlage, Speichern als JSON |
| `Models.swift` | Datentypen, Platzhalter, Dateinamen bilden |
| `DocumentCamera.swift` | VisionKit-Dokumentkamera |
