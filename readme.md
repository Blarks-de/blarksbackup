# blarksbackup.sh: Universelles SSH- & Lokales Backup/Restore Skript 💾

**Version:** 18.10.2025 (finale Version mit Moduserkennung)
**Autor:** blarks-de

---

## ⚠️ HAFTUNGSAUSSCHLUSS – WARNUNG!

**Used at your own Risk!**

Ich übernehme **keine Haftung**, wenn Dein Rechner hinterher in Flammen aufgeht, oder sich weiße Maden aus dem DVD-Laufwerk winden!!EINSELF!!

---

## 💡 Übersicht

Das Skript **`blarksbackup.sh`** ist ein robustes `bash`-Skript, das entwickelt wurde, um **vollautomatische** und **konfigurierbare** Backups von lokalen Systemen oder über SSH erreichbaren Remote-Servern zu erstellen. Es nutzt `rsync` für effiziente, inkrementelle Sicherungen und bietet zusätzlich einen interaktiven **Restore-Modus**.

Es ist primär darauf ausgelegt, die Konfigurationen und Daten von Webservern (wie Ihrem **Strato-Server** `217.154.239.187` mit **blarks.de** und **rowoldt.de**), Docker-Setups und kritischen Systemverzeichnissen zu sichern.

### Hauptfunktionen

* **Backup-Modus:** Sichert definierte Verzeichnisse von Remote-Hosts (via SSH-Config) oder vom lokalen System.
* **Restore-Modus:** Interaktives Wiederherstellen des gesamten Backups oder spezifischer Teile (z. B. nur Apache/Webseiten, nur RustDesk).
* **Konfigurierbarkeit:** Lädt Host-spezifische Konfigurationen aus `blarksbackup.conf`.
* **Sicherheit:** Prüft vor dem Start den verfügbaren Speicherplatz auf dem Ziel.
* **Wartung:** Automatische Bereinigung alter Backups (behält standardmäßig die letzten 10).
* **Logging:** Erstellt detaillierte Log- und Fehlerdateien für jede Ausführung.

---

## 🛠️ Voraussetzungen

* Ein System mit **Bash**
* **`rsync`** (für Backup und Restore)
* **`ssh`** (für Remote-Backups, muss passwortlos via Key funktionieren)
* **`awk`**, **`grep`**, **`numfmt`**, **`tee`**

Für Remote-Backups muss der Ziel-Host in Ihrer lokalen SSH-Konfiguration (`~/.ssh/config`) definiert sein.

---

## 🚀 Erste Schritte

### 1. Konfiguration (Optional)

Legen Sie eine Konfigurationsdatei mit dem Namen **`blarksbackup.conf`** im selben Ordner wie das Skript oder unter `/etc/blarksbackup.conf` an. Dies ermöglicht Ihnen, hostspezifische Einstellungen zu definieren.

#### Beispiel für `blarksbackup.conf`:

```ini
[strato]
# Verzeichnisse, die auf dem Remote-Host gesichert werden sollen
REMOTE_VERZEICHNISSE=(
  "/var/www"
  "/etc/apache2"
  "/etc/letsencrypt"
  "/docker/rustdesk"
  "/home/blarks"
)

# Optional: Überschreibt den globalen BACKUP_ROOT für diesen Host
# BACKUP_ROOT_CONF="/mnt/speicher/strato_backups"

[dockfish]
# Lokaler Host (wird automatisch erkannt, wenn kein Argument übergeben wird)
REMOTE_VERZEICHNISSE=(
  "/etc"
  "/home"
  "/var/lib/docker"
)
