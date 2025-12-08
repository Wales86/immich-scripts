#!/bin/bash

# Testowy skrypt wysyłania maila przez Mailgun API
# Użycie: ./test_mail.sh [adres_email] [temat] [wiadomość]

# Ładowanie konfiguracji Mailgun
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/mailgun_config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Błąd: Brak pliku konfiguracyjnego $CONFIG_FILE"
    echo "Utwórz plik mailgun_config.sh na podstawie mailgun_config.sh.example"
    exit 1
fi

source "$CONFIG_FILE"

# Sprawdź czy MAILGUN_API_KEY jest ustawiony
if [ "$MAILGUN_API_KEY" = "API_KEY" ]; then
    echo "❌ Błąd: MAILGUN_API_KEY nie jest skonfigurowany!"
    echo "Edytuj plik $CONFIG_FILE i ustaw prawdziwy API key."
    exit 1
fi

# Parametry
EMAIL_TO="${1:-$EMAIL_TO_DEFAULT}"
SUBJECT="${2:-Test maila z Raspberry Pi}"
MESSAGE="${3:-To jest testowa wiadomość wysłana z Raspberry Pi.
Czas: $(date)
Hostname: $(hostname)
Uptime: $(uptime)}"

echo "Wysyłanie testowego maila..."
echo "Do: $EMAIL_TO"
echo "Temat: $SUBJECT"
echo "Wiadomość:"
echo "$MESSAGE"
echo "---"

RESPONSE=$(send_mailgun_email "$EMAIL_TO" "$SUBJECT" "$MESSAGE")

if echo "$RESPONSE" | grep -q '"id":'; then
    echo "✅ Mail wysłany pomyślnie!"
    echo "Response: $RESPONSE"
else
    echo "❌ Błąd wysyłania maila!"
    echo "Response: $RESPONSE"
    exit 1
fi
