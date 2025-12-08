# Konfiguracja Mailgun dla skryptów
# Skopiuj ten plik jako mailgun_config.sh i dostosuj ustawienia

# Mailgun API Key - znajdź go w dashboard Mailgun
MAILGUN_API_KEY="API_KEY"

# Mailgun Domain/Sandbox
MAILGUN_DOMAIN="sandbox42f2207f2a6b463daa8259a3b1bd981d.mailgun.org"

# Adres nadawcy
MAILGUN_FROM="Raspberry Pi Backup <postmaster@${MAILGUN_DOMAIN}>"

# Adres odbiorcy domyślny
EMAIL_TO_DEFAULT="leszek.walszewski@gmail.com"

# Funkcja wysyłania maila przez Mailgun
send_mailgun_email() {
    local to="$1"
    local subject="$2"
    local text="$3"

    curl -s --user "api:${MAILGUN_API_KEY}" \
         "https://api.mailgun.net/v3/${MAILGUN_DOMAIN}/messages" \
         -F from="${MAILGUN_FROM}" \
         -F to="${to}" \
         -F subject="${subject}" \
         -F text="${text}"
}
