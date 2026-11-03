#!/bin/sh
set -eu

export PORT="${PORT:-8080}"
case "$PORT" in ''|*[!0-9]*) echo 'PORT harus berupa angka.' >&2; exit 1 ;; esac
: "${APP_KEY:?APP_KEY wajib diisi di service staging}"

# Cache hanya dibuat saat runtime, sesudah env service tersedia.
# Migrasi/seed TIDAK dijalankan otomatis oleh image ini.
php artisan config:cache
php artisan route:cache
php artisan view:cache
chown -R www-data:www-data storage bootstrap/cache

case "${PROCESS_ROLE:-api}" in
    api) exec apache2-foreground ;;
    scheduler) exec php artisan schedule:work ;;
    *) echo 'PROCESS_ROLE harus api atau scheduler.' >&2; exit 1 ;;
esac
