#!/bin/env bash
set -o pipefail

# =====================================================
#  blarksbackup.sh – universelles SSH-/Lokal-Backupskript
#  Version: 18.10.2025 – finale Version mit Moduserkennung
# =====================================================

# === Globale Variablen ===
DATUM=$(date +"%Y-%m-%d_%H.%M")
DEFAULT_HOST="strato"
BACKUP_ROOT="/RAID/backup"
VERBOSE=false
DRYRUN=""
QUELLE=""
QUICK=false
RUECKGABE=0

# === Moduswahl: Backup oder Restore ===
echo "Backup oder Restore?"
read -p "B) Backup  R) Restore  [B/r]: " MODE
MODE=${MODE:-B}

if [[ "$MODE" =~ ^[Rr]$ ]]; then
  echo ">> RESTORE-Modus <<"
  echo "Verfügbare Backups:"
  ls -1 "${BACKUP_ROOT}/${DEFAULT_HOST}/" || { echo "Keine Backups gefunden."; exit 1; }

  read -p "Backup-Ordner (z. B. 2025-09-17_13.00): " RESTORE_DIR
  RESTORE_PATH="${BACKUP_ROOT}/${DEFAULT_HOST}/${RESTORE_DIR}"
  [[ -d "$RESTORE_PATH" ]] || { echo "Ordner nicht gefunden."; exit 1; }

  echo "Was soll wiederhergestellt werden?"
  echo "1) Alles"
  echo "2) Nur Apache/Webseiten"
  echo "3) Nur RustDesk"
  read -p "[1/2/3]: " PART

  case "$PART" in
    1) rsync -av "$RESTORE_PATH"/ / ;;
    2)
      rsync -av "$RESTORE_PATH"/var/www/ /var/www/
      rsync -av "$RESTORE_PATH"/etc/apache2/ /etc/apache2/
      rsync -av "$RESTORE_PATH"/etc/letsencrypt/ /etc/letsencrypt/
      ;;
    3)
      rsync -av "$RESTORE_PATH"/docker/rustdesk/ /docker/rustdesk/
      ;;
    *) echo "Abbruch."; exit 1 ;;
  esac
  exit 0
fi

# === Standardverzeichnisse (Fallback) ===
REMOTE_VERZEICHNISSE=(
  "/certs"
  "/etc/apache2"
  "/etc/letsencrypt"
  "/etc/docker"
  "/home/blarks"
  "/opt"
  "/srv"
  "/var/www"
  "/var/lib/docker"
)

zeige_hilfe() {
  echo
  echo "🧰 Verwendung: $0 [HOST] [--dry] [--verbose] [--quick]"
  echo
  echo "  HOST        SSH-Host aus ~/.ssh/config (Standard: $DEFAULT_HOST)"
  echo "  --dry       Nur Testlauf, keine Daten werden kopiert"
  echo "  --verbose   Detaillierte Ausgabe während des Backups"
  echo "  --quick     Überspringt Platzprüfung & Wartezeit (für Cronjobs)"
  echo "  --help      Diese Hilfe anzeigen"
  exit 0
}

parse_argumente() {
  for ARG in "$@"; do
    case "$ARG" in
      --help|-h) zeige_hilfe ;;
      --dry) DRYRUN="--dry-run" ;;
      --verbose) VERBOSE=true ;;
      --quick) QUICK=true ;;
      *) QUELLE="$ARG" ;;
    esac
  done
  [[ -z "$QUELLE" ]] && QUELLE="$DEFAULT_HOST"

  ZIEL="${BACKUP_ROOT}/${QUELLE}"
  ZIELVERZEICHNIS="$ZIEL/$DATUM"
  LOGFILE="$ZIEL/backup_$DATUM.log"

  mkdir -p "$ZIELVERZEICHNIS" || {
    echo "🛑 Fehler: Konnte '$ZIELVERZEICHNIS' nicht anlegen."
    exit 1
  }
}

lade_ssh_config() {
  SSHCONFIG=$(ssh -G "$QUELLE" 2>/dev/null)
  SSH_HOST=$(echo "$SSHCONFIG" | awk '/^hostname / {print $2}')
  SSH_PORT=$(echo "$SSHCONFIG" | awk '/^port / {print $2}')
  SSH_USER=$(echo "$SSHCONFIG" | awk '/^user / {print $2}')
}

# 🧩 Lokalerkennung
ist_lokal() {
  [[ "$QUELLE" == "$(hostname)" || "$SSH_HOST" == "localhost" ]]
}

# =====================================================
# 🔧 Config-Datei laden (lokal oder /etc)
# =====================================================
lade_config_datei() {
  LOCAL_CONFIG="$(dirname "$0")/blarksbackup.conf"
  SYSTEM_CONFIG="/etc/blarksbackup.conf"

  if [[ -f "$LOCAL_CONFIG" ]]; then
    CONFIG_FILE="$LOCAL_CONFIG"
    echo "📄 Lokale Konfigurationsdatei gefunden: $CONFIG_FILE"
  elif [[ -f "$SYSTEM_CONFIG" ]]; then
    CONFIG_FILE="$SYSTEM_CONFIG"
    echo "⚙️  Verwende systemweite Konfiguration: $CONFIG_FILE"
  else
    echo "⚠️  Keine Konfigurationsdatei gefunden. Verwende Standardverzeichnisse."
    return
  fi

  echo "📖 Lese Konfiguration aus $CONFIG_FILE ..."
  BLOCK=$(awk -v host="[$QUELLE]" '
    $0 == host {inblock=1; next}
    /^\[/{inblock=0}
    inblock
  ' "$CONFIG_FILE")

  if [[ -z "$BLOCK" ]]; then
    echo "⚠️  Kein Abschnitt für Host '$QUELLE' gefunden, verwende Standardverzeichnisse."
    return
  fi

  eval "$BLOCK"
  echo "✅ Konfiguration für Host '$QUELLE' geladen (${#REMOTE_VERZEICHNISSE[@]} Verzeichnisse)"
}

# =====================================================
# 🚦 Moduserkennung vor Backupstart
# =====================================================
zeige_modusinfo() {
  if ist_lokal; then
    echo "💻 Lokales Backup erkannt – Sicherung erfolgt direkt ohne SSH."
  else
    echo "🌐 Remote-Backup aktiv – Verbindungen erfolgen über SSH."
  fi
  echo
}

zeige_zusammenfassung() {
  echo "=============================="
  echo "🛰️  Backup-Quelle: $QUELLE"
  echo "🌐 IP / Hostname:  ${SSH_HOST:-lokal}"
  echo "🔐 Port:           ${SSH_PORT:-–}"
  echo "👤 Benutzer:       ${SSH_USER:-(Standard)}"
  echo "📂 Zielverz.:      $ZIELVERZEICHNIS"
  echo "📝 Log-Datei:      $LOGFILE"
  [[ -n "$DRYRUN" ]] && echo "⚠️  Dry-Run ist aktiv"
  [[ "$QUICK" == true ]] && echo "⚡ Quick-Modus: Keine Prüfung oder Wartezeit"
  echo "=============================="
  echo
  echo "📁 Die folgenden Verzeichnisse werden gesichert:"
  for VERZ in "${REMOTE_VERZEICHNISSE[@]}"; do echo "  - $VERZ"; done
  echo

  if ist_lokal; then
    echo "💻 Lokaler Modus erkannt – SSH-Verbindungen werden übersprungen."
  else
    echo "🐳 Docker-Container auf dem Server:"
    ssh "$QUELLE" "docker ps --format '  - {{.Names}} ({{.Status}})'" || echo "⚠️  Docker nicht installiert oder nicht erreichbar"
  fi
  echo
}

# =====================================================
# 💾 Speicherplatzprüfung
# =====================================================
pruefe_platz() {
  echo "💾 Schätze benötigten Speicherplatz..."
  VALID_DIRS=()
  for VERZ in "${REMOTE_VERZEICHNISSE[@]}"; do
    if ist_lokal; then
      [[ -d "$VERZ" ]] && VALID_DIRS+=("$VERZ") || echo "⚠️  Überspringe nicht vorhandenes Verzeichnis: $VERZ"
    else
      if ssh "$QUELLE" "[ -d \"$VERZ\" ]"; then
        VALID_DIRS+=("$VERZ")
      else
        echo "⚠️  Überspringe nicht vorhandenes Verzeichnis: $VERZ"
      fi
    fi
  done

  (( ${#VALID_DIRS[@]} == 0 )) && { echo "🛑 Keine gültigen Quellverzeichnisse gefunden."; return; }

  if ist_lokal; then
    GESAMT_BYTES=$(du -sb "${VALID_DIRS[@]}" 2>/dev/null | awk '{s+=$1} END{print s+0}')
  else
    RSYNC_CMD=(env LC_ALL=C rsync -an --stats --exclude='*~' --exclude='.DS_Store' --exclude='*.swp' --exclude='*.bak' --exclude='Thumbs.db' -e ssh)
    SOURCES=()
    for d in "${VALID_DIRS[@]}"; do SOURCES+=("$QUELLE:$d"); done
    STATS="$("${RSYNC_CMD[@]}" "${SOURCES[@]}" "$ZIELVERZEICHNIS/" 2>&1)"
    TOTAL_LINE=$(printf '%s\n' "$STATS" | awk '/^Total file size:/{line=$0} END{print line}')
    GESAMT_BYTES=$(printf '%s\n' "$TOTAL_LINE" | grep -Eo '[0-9]+' | tail -n1)
  fi

  [[ -z "$GESAMT_BYTES" ]] && GESAMT_BYTES=0
  FREI_BYTES=$(df -B1 "$BACKUP_ROOT" | awk 'NR==2 {print $4}')
  HUMAN_NEED=$(numfmt --to=iec --suffix=B "$GESAMT_BYTES")
  HUMAN_FREE=$(numfmt --to=iec --suffix=B "$FREI_BYTES")
  echo "📦 Geschätzte Backupgröße: $HUMAN_NEED"
  echo "🧮 Freier Speicher auf Ziel: $HUMAN_FREE"

  if (( GESAMT_BYTES > FREI_BYTES )); then
    DIFF=$(( GESAMT_BYTES - FREI_BYTES ))
    HUMAN_DIFF=$(numfmt --to=iec --suffix=B "$DIFF")
    echo "🛑 Nicht genug Speicherplatz! Es fehlen $HUMAN_DIFF."
    read -rp "Trotzdem fortfahren? [y/N] " ANTWORT
    [[ ! "$ANTWORT" =~ ^[YyJj]$ ]] && { echo "🚫 Abgebrochen."; exit 1; }
  else
    echo "✅ Genug Platz vorhanden."
    sleep 1
  fi
  echo
}

# =====================================================
# 🚀 Backup ausführen
# =====================================================
fuhre_backup_aus() {
  mkdir -p "$ZIELVERZEICHNIS"
  exec > >(tee -a "$LOGFILE") 2>&1
  FEHLERDATEI="$ZIEL/fehler_$DATUM.log"
  : > "$FEHLERDATEI"

  echo
  echo "==== 📦 Backup gestartet am $(date) ===="

  for VERZ in "${REMOTE_VERZEICHNISSE[@]}"; do
    echo "📂 Sicherung von: $VERZ"
    if ist_lokal; then
      rsync -avz $DRYRUN \
        --exclude='*~' --exclude='.DS_Store' --exclude='*.swp' \
        --exclude='*.bak' --exclude='Thumbs.db' \
        --log-file="$FEHLERDATEI" \
        --log-file-format="%i %n%L %M" \
        "$VERZ" "$ZIELVERZEICHNIS" || RUECKGABE=$?
    else
      rsync -avz $DRYRUN \
        --exclude='*~' --exclude='.DS_Store' --exclude='*.swp' \
        --exclude='*.bak' --exclude='Thumbs.db' \
        --log-file="$FEHLERDATEI" \
        --log-file-format="%i %n%L %M" \
        -e ssh "$QUELLE:$VERZ" "$ZIELVERZEICHNIS" || RUECKGABE=$?
    fi
  done
}

# =====================================================
# 📋 Fehlerauswertung & Backupgrößen
# =====================================================
zeige_backup_groessen() {
  echo
  echo "📊 Größenvergleich aller Backups unter $ZIEL:"
  local max=$(du -s "$ZIEL"/* 2>/dev/null | sort -nr | head -n1 | awk '{print $1}')
  for eintrag in "$ZIEL"/*; do
    [[ -d "$eintrag" ]] || continue
    size=$(du -s "$eintrag" | awk '{print $1}')
    human=$(du -sh "$eintrag" | awk '{print $1}')
    name=$(basename "$eintrag")
    [[ -n "$max" && "$max" -gt 0 ]] && prozent=$((100 * size / max)) || prozent=100
    breite=$((prozent / 5))
    bar=$(printf "%-${breite}s" "#" | tr ' ' '#')
    printf "📁 %-20s [%-20s] %3d%% (%s)\n" "$name" "$bar" "$prozent" "$human"
  done
}

zeige_fehler_zusammenfassung() {
  FEHLERDATEI="$ZIEL/fehler_$DATUM.log"
  echo
  echo "📋 Fehlerauswertung:"
  echo "------------------------------------------"
  if grep -E "rsync error|failed|Permission denied|No such file" "$FEHLERDATEI" >/dev/null; then
    grep -E "rsync error|failed|Permission denied|No such file" "$FEHLERDATEI" | sort | uniq -c
    echo
    echo "⚠️  Details siehe: $FEHLERDATEI"
  else
    echo "✅ Keine fehlerhaften Dateien gefunden."
  fi
  echo "------------------------------------------"
  echo
}

# =====================================================
# 🧹 Alte Backups löschen (max. 10 behalten)
# =====================================================
bereinige_alte_backups() {
  local MAX_BACKUPS=10
  local BACKUP_PATH="$ZIEL"
  echo
  echo "🧹 Prüfe Anzahl vorhandener Backups unter: $BACKUP_PATH"

  local BACKUPS=($(ls -1t "$BACKUP_PATH" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}_'))
  local ANZAHL=${#BACKUPS[@]}

  if (( ANZAHL <= MAX_BACKUPS )); then
    echo "✅ Es sind $ANZAHL Backups vorhanden (max. $MAX_BACKUPS erlaubt)."
    return
  fi

  echo "⚠️  Es sind $ANZAHL Backups vorhanden. Maximal erlaubt: $MAX_BACKUPS"
  local ZU_LOESCHEN=$((ANZAHL - MAX_BACKUPS))
  echo "Die folgenden $ZU_LOESCHEN ältesten Backups können gelöscht werden:"
  local ALT=($(ls -1tr "$BACKUP_PATH" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}_' | head -n "$ZU_LOESCHEN"))
  for b in "${ALT[@]}"; do echo "  🗑️  $b"; done
  echo

  read -rp "Möchtest du diese $ZU_LOESCHEN alten Backups löschen? [y/N] " ANTWORT
  if [[ "$ANTWORT" =~ ^[YyJj]$ ]]; then
    for b in "${ALT[@]}"; do
      echo "🗑️  Lösche $BACKUP_PATH/$b ..."
      rm -rf "$BACKUP_PATH/$b"
    done
    echo "✅ Alte Backups wurden gelöscht."
  else
    echo "🚫 Keine Backups gelöscht."
  fi
  echo
}

# =====================================================
# 🧩 Zusammenfassung & Hauptablauf
# =====================================================
zeige_ergebnis() {
  echo
  echo "📏 Backupgröße:"
  du -sh "$ZIELVERZEICHNIS"
  echo

  if [[ $RUECKGABE -eq 23 ]]; then
    echo "⚠️  Warnung: Einige Dateien konnten nicht gesichert werden (Code 23)."
  elif [[ $RUECKGABE -ne 0 ]]; then
    echo "🛑 Fehler: rsync meldet Code $RUECKGABE!"
  else
    echo "✅ Backup erfolgreich beendet um $(date)"
  fi

  [[ -n "$DRYRUN" ]] && echo "🚧 Hinweis: Es wurde nur ein Dry-Run durchgeführt."

  zeige_backup_groessen
  zeige_fehler_zusammenfassung
  bereinige_alte_backups

  [[ $RUECKGABE -ne 0 ]] && exit $RUECKGABE
}

main() {
  # Prüfen, ob Skript mit Root-Rechten läuft
  if [[ $EUID -ne 0 ]]; then
    echo
    echo "⚠️  Hinweis: Dieses Skript läuft ohne Root-Rechte."
    echo "   Einige Systemverzeichnisse (z. B. /etc, /var/lib/docker) können nicht vollständig gesichert werden."
    read -rp "Trotzdem fortfahren? [y/N]: " ANTWORT
    if [[ ! "$ANTWORT" =~ ^[YyJj]$ ]]; then
      echo "🚫 Abgebrochen. Bitte mit 'sudo ./blarksbackup.sh' erneut starten."
      exit 1
    fi
    echo "➡️  Fahre fort ohne Root-Rechte..."
    echo
    sleep 1
  fi
    parse_argumente "$@"
  [[ "$VERBOSE" == true ]] && echo "🔧 Parameter: Host=$QUELLE DryRun=$DRYRUN Verbose=$VERBOSE Quick=$QUICK"
  lade_ssh_config
  lade_config_datei
  zeige_modusinfo
  zeige_zusammenfassung

  if [[ "$QUICK" == false ]]; then
    pruefe_platz
  else
    echo "⚡ Überspringe Prüfung und Wartezeit (Quick-Modus aktiv)"
  fi

  fuhre_backup_aus
  zeige_ergebnis
}

main "$@"
