# blarksbackup.sh – universelles SSH-/Lokal-Backupskript

**Version:** 18.10.2025  
**Autor:** Jens ("blarks")  
**Lizenz:** Frei für private Nutzung

---

## Kurzbeschreibung

`blarksbackup.sh` ist ein vielseitiges Backup- und Restore-Skript für Linux-Systeme, das sowohl lokale als auch Remote-Sicherungen über SSH unterstützt.  
Es erkennt automatisch den Betriebsmodus, liest bei Bedarf Konfigurationen ein und erstellt vollständige oder teilweise Sicherungen in einem klar strukturierten Zielverzeichnis.

Das Skript ist robust, interaktiv und modular aufgebaut – ideal für den täglichen Einsatz, manuell oder automatisiert.

---

## Hauptfunktionen

- Automatische Moduserkennung (lokal oder über SSH)
- Optionales Einlesen einer Konfigurationsdatei (`blarksbackup.conf`)
- Speicherplatzprüfung mit Größenabschätzung vor dem Backup
- Effiziente rsync-Sicherungen (lokal oder über SSH)
- Pro-Backup-Logdatei und separate Fehlersammelliste
- Aufräumfunktion: alte Backups löschen (max. 10, nach Rückfrage)
- Visuelle Übersicht aller Backups mit Prozentbalken
- Restore-Modus (komplett, Webserver-Teile oder RustDesk)

---

## Verwendung

bash
sudo ./blarksbackup.sh [HOST] [--dry] [--verbose] [--quick]

WARNUNG!
Used at your own Risk!

ich übernehme keine Haftung, wenn Dein Rechner hinterher in Flammen aufgeht,
oder sich weisse maden aus dem DVD-Laufwerk winden!!EINSELF!!

| Option      | Bedeutung                                                         |
| ----------- | ----------------------------------------------------------------- |
| `HOST`      | SSH-Host aus `~/.ssh/config` (Standard: `strato`)                 |
| `--dry`     | Testlauf, es werden keine Daten kopiert                           |
| `--verbose` | Detaillierte Ausgaben waehrend des Backups                        |
| `--quick`   | Ueberspringt Speicherpruefung und Wartezeit (z. B. fuer Cronjobs) |
| `--help`    | Hilfe anzeigen                                                    |

Verwendung auf eigenes Risiko. Stelle sicher, dass du Restore-Pfade und Inhalte kennst und 
vor produktivem Einsatz Tests durchfuehrst.

