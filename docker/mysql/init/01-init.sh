#!/bin/bash
# =============================================================
#  OwlGaming MTA – Inicjalizacja baz danych MySQL
#  Uruchamiane automatycznie przy pierwszym starcie kontenera
# =============================================================
set -e

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
    -- Tworzenie baz danych
    CREATE DATABASE IF NOT EXISTS \`${MTA_DATABASE_NAME}\`
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

    CREATE DATABASE IF NOT EXISTS \`${CORE_DATABASE_NAME}\`
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

    -- Użytkownik bazy MTA
    CREATE USER IF NOT EXISTS '${MTA_DATABASE_USERNAME}'@'%'
        IDENTIFIED BY '${MTA_DATABASE_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MTA_DATABASE_NAME}\`.* TO '${MTA_DATABASE_USERNAME}'@'%';

    -- Użytkownik bazy Core
    CREATE USER IF NOT EXISTS '${CORE_DATABASE_USERNAME}'@'%'
        IDENTIFIED BY '${CORE_DATABASE_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${CORE_DATABASE_NAME}\`.* TO '${CORE_DATABASE_USERNAME}'@'%';

    FLUSH PRIVILEGES;
EOSQL

echo "[init] Bazy danych i użytkownicy utworzeni."

# Wczytaj schematy z plików SQL (jeśli istnieją)
for db_sql in /mta-sql/*.sql; do
    [ -f "$db_sql" ] || continue
    echo "[init] Wczytywanie schematu: $db_sql"
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${MTA_DATABASE_NAME}" < "$db_sql"
done

echo "[init] Gotowe."
