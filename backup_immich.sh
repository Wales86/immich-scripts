#!/bin/bash

# ==========================================
# KONFIGURACJA
# ==========================================

# Katalog docelowy kopii
BACKUP_DIR="/mnt/storage/backups"

# Katalog aplikacji Immich (tam gdzie docker-compose.yml i .env)
IMMICH_UPLOAD_DIR="/mnt/storage/immich"

# Parametry bazy danych
DB_CONTAINER="immich-postgres"
DB_USER="postgres"
DB_NAME="immich"
DB_PASSWORD="postgres"

# Nazwa pliku
DATE=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME="immich_backup_${DATE}.tar.gz"

# ILE KOPII TRZYMAĆ? (Ustawienie rotacji)
LICZBA_KOPII=1

# Konfiguracja powiadomień email przez Mailgun (opcjonalne)
EMAIL_ENABLED=true
EMAIL_TO="leszek.walszewski@gmail.com"
EMAIL_SUBJECT="Backup Immich zakończony"

# Ładowanie konfiguracji Mailgun
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/mailgun_config.sh"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "[UWAGA] Brak pliku konfiguracyjnego $CONFIG_FILE - email nie będzie działać"
    EMAIL_ENABLED=false
fi

# ==========================================
# CZĘŚĆ WYKONAWCZA
# ==========================================

mkdir -p "$BACKUP_DIR"
TEMP_DIR=$(mktemp -d)

echo "[INFO] Start backupu: $DATE"

# 1. Zrzut bazy
echo "[INFO] Zrzucanie bazy danych..."
if docker exec -t "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$TEMP_DIR/immich-database.sql.gz"; then
    echo "[OK] Baza zrzucona."
else
    echo "[BLAD] Błąd zrzutu bazy!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 2. Pakowanie wszystkiego do jednego pliku
echo "[INFO] Tworzenie archiwum..."
tar -czvf "$BACKUP_DIR/$FILENAME" \
    -C "$TEMP_DIR" immich-database.sql.gz \
    -C "$IMMICH_UPLOAD_DIR" .

if [ $? -eq 0 ]; then
    echo "[SUKCES] Utworzono plik: $BACKUP_DIR/$FILENAME"
else
    echo "[BLAD] Błąd pakowania!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 3. Sprzątanie plików tymczasowych
rm -rf "$TEMP_DIR"

# 4. Rotacja kopii (usuwanie starych)
echo "[INFO] Sprawdzanie starych kopii (zachowujemy $LICZBA_KOPII najnowszych)..."
# Listuje pliki posortowane czasem (najnowsze u góry), pomija X pierwszych, resztę usuwa
ls -tp "$BACKUP_DIR"/immich_backup_*.tar.gz | grep -v '/$' | tail -n +$((LICZBA_KOPII + 1)) | xargs -I {} rm -- "$BACKUP_DIR/{}"

echo "[INFO] Zakończono."

# 5. Wysyłanie powiadomienia email (jeśli włączone)
if [ "$EMAIL_ENABLED" = true ]; then
    echo "[INFO] Wysyłanie powiadomienia email przez Mailgun..."
    EMAIL_BODY="Backup Immich zakończony pomyślnie.
Data: $DATE
Plik: $BACKUP_DIR/$FILENAME
Rozmiar: $(du -h "$BACKUP_DIR/$FILENAME" | cut -f1)
Serwer: $(hostname)"

    RESPONSE=$(send_mailgun_email "$EMAIL_TO" "$EMAIL_SUBJECT" "$EMAIL_BODY")

    if echo "$RESPONSE" | grep -q '"id":'; then
        echo "[OK] Email wysłany pomyślnie."
    else
        echo "[UWAGA] Nie udało się wysłać emaila."
        echo "Response: $RESPONSE"
    fi
fi