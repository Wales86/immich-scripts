# Konfiguracja Mailgun dla wysyłania emaili

## Wymagania
- `curl` (zainstalowany domyślnie na większości systemów Linux)
- Konto Mailgun z API key

## Konfiguracja

### 1. Skopiuj plik konfiguracyjny
```bash
cp mailgun_config.sh mailgun_config.sh.example  # zachowaj oryginał jako przykład
```

### 2. Edytuj konfigurację
Otwórz `mailgun_config.sh` i ustaw:
- `MAILGUN_API_KEY` - Twój prawdziwy API key z Mailgun
- `MAILGUN_DOMAIN` - Twój domain/sandbox z Mailgun
- `MAILGUN_FROM` - Adres nadawcy
- `EMAIL_TO_DEFAULT` - Domyślny adres odbiorcy

### 3. Znajdź API Key w Mailgun
1. Zaloguj się do [Mailgun Dashboard](https://app.mailgun.com)
2. Przejdź do Settings → API Keys
3. Skopiuj Private API Key

## Testowanie

### Test wysyłania maila
```bash
./test_mail.sh
# lub z parametrami:
./test_mail.sh "twoj@email.com" "Temat testowy" "Treść wiadomości"
```

## Użycie w backup_immich.sh

### Włączenie powiadomień email
W pliku `backup_immich.sh` zmień:
```bash
EMAIL_ENABLED=false  # na true
```

### Dodatkowe opcje
Możesz też zmienić:
- `EMAIL_TO` - adres odbiorcy
- `EMAIL_SUBJECT` - temat maila

## Przykład użycia curl bezpośrednio
```bash
curl -s --user 'api:TWOJ_API_KEY' \
  https://api.mailgun.net/v3/TWOJ_DOMAIN/messages \
  -F from='Nadawca <postmaster@TWOJ_DOMAIN>' \
  -F to='Odbiorca <email@example.com>' \
  -F subject='Temat' \
  -F text='Treść wiadomości'
```

## Troubleshooting

### Błąd autoryzacji
- Sprawdź czy API key jest poprawny
- Upewnij się że używasz Private API Key (nie Public)

### Mails nie dochodzą
- Sprawdź czy używasz sandbox domain
- Sandbox domains wysyłają tylko na zweryfikowane adresy
- Dla produkcji użyj własnego domain

### Błąd: Brak pliku konfiguracyjnego
- Upewnij się że `mailgun_config.sh` istnieje w tym samym katalogu
- Sprawdź uprawnienia pliku
