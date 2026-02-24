# OwlGaming Community

Community fork gamemode'u [OwlGaming](https://owlgaming.net/) dla [Multi Theft Auto](https://multitheftauto.com/) (GTA: San Andreas).
Naprawione bugi, poprawione bezpieczeństwo, łatwe postawienie własnego serwera.

Licencja: GPL-2.0

---

## Kanały wydań

| Kanał | Źródło | Przeznaczenie |
|---|---|---|
| **Testowy** | `main` branch | testerzy, kontrybutorzy |
| **Stabilny** | [GitHub Releases](https://github.com/NoTenTego/owlgaming-community/releases) | serwery produkcyjne |

---

## Opcja 1 – Docker (MTA + MySQL razem)

Najprostsza opcja. Docker stawia wszystko automatycznie.

**Wymagania:** Docker, Docker Compose v2

```bash
git clone https://github.com/NoTenTego/owlgaming-community.git
cd owlgaming-community
cp .env.example .env
# Uzupełnij hasła w .env
docker compose --profile with-db up -d
```

Bazy danych (`mta`, `core`) i użytkownicy MySQL tworzone są automatycznie przy pierwszym starcie.

---

## Opcja 2 – Docker (MTA) + własna baza

Masz już MySQL na VPS lub managed database (np. PlanetHoster, Hetzner, DigitalOcean).

```bash
git clone https://github.com/NoTenTego/owlgaming-community.git
cd owlgaming-community
cp .env.example .env
# Uzupełnij w .env: MTA_DATABASE_HOST, CORE_DATABASE_HOST i dane logowania
docker compose up -d
```

Schematy baz danych znajdziesz w `mods/deathmatch/data/`:
- `mta.sql` – główna baza
- `core.sql` – baza kont
- `data.sql` – dane początkowe

---

## Opcja 3 – Hosting FTP (ServerProject i podobne)

Nie używasz Dockera – serwer MTA działa bezpośrednio na hostingu.

**Krok 1 – Przygotuj pliki konfiguracyjne**

```bash
cd mods/deathmatch
cp mtaserver.conf.example mtaserver.conf
cp settings.xml.example   settings.xml
```

Otwórz oba pliki i zastąp wszystkie placeholdery (np. `MTA_DATABASE_HOST`) prawdziwymi wartościami.

**Krok 2 – Wgraj przez FTP**

Wgraj katalog `mods/deathmatch/` na swój serwer MTA.

**Krok 3 – Zaimportuj bazy danych**

Zaimportuj przez phpMyAdmin lub panel hostingu:
- `mods/deathmatch/data/mta.sql`
- `mods/deathmatch/data/core.sql`
- `mods/deathmatch/data/data.sql`

**Krok 4 – Uruchom serwer**

Przez panel hostingu lub SSH:
```bash
./mta-server64 -n -t -u
```

---

## Konfiguracja (.env)

| Zmienna | Opis | Domyślnie |
|---|---|---|
| `SERVER_IP` | IP serwera (puste = wszystkie interfejsy) | *(puste)* |
| `SHOULD_BROADCAST` | Widoczność w masterlist (0/1) | `0` |
| `OWNER_EMAIL_ADDRESS` | E-mail właściciela serwera | — |
| `PRODUCTION_SERVER` | Tryb (0 = dev, 1 = produkcja) | `0` |
| `WEBSITE_PASSWORD` | Hasło do UCP | — |
| `MTA_DATABASE_HOST` | Host bazy MTA | `db` |
| `MTA_DATABASE_NAME` | Nazwa bazy MTA | `mta` |
| `MTA_DATABASE_USERNAME` | Użytkownik bazy MTA | `mta_user` |
| `MTA_DATABASE_PASSWORD` | Hasło bazy MTA | — |
| `CORE_DATABASE_HOST` | Host bazy Core | `db` |
| `CORE_DATABASE_NAME` | Nazwa bazy Core | `core` |
| `CORE_DATABASE_USERNAME` | Użytkownik bazy Core | `core_user` |
| `CORE_DATABASE_PASSWORD` | Hasło bazy Core | — |
| `MYSQL_ROOT_PASSWORD` | Hasło roota MySQL (tylko opcja 1) | — |
| `FORUMS_API_KEY` | Klucz API forum (opcjonalne) | *(puste)* |
| `IMGUR_API_KEY` | Klucz Imgur (opcjonalne) | *(puste)* |

---

## Przydatne komendy (Docker)

```bash
# Logi serwera MTA na żywo
docker compose logs -f mta

# Rebuild po zmianie kodu
docker compose up -d --build mta

# Zatrzymanie
docker compose down

# Zatrzymanie + reset baz danych (!)
docker compose down -v
```

---

## Contributing

1. Zrób fork repozytorium
2. Utwórz gałąź: `git checkout -b fix/nazwa-bledu`
3. Commituj zmiany
4. Otwórz **Pull Request** – każda zmiana wymaga akceptacji przed mergem

---

## Linki

- [Konwencje kodowania](coding_conventions.md)
- [Przydatne funkcje](useful_functions.md)
- [MTA Wiki](https://wiki.multitheftauto.com/)
- [Oryginalne repo OwlGaming](https://github.com/OwlGamingCommunity/MTA)
