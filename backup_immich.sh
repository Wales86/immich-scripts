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
LICZBA_KOPII=3

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
tar -czf "$BACKUP_DIR/$FILENAME" \
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