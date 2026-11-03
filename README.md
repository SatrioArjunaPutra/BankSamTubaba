# Bank Sampah Pintar Tubaba

Satu backend Laravel untuk web DLH dan aplikasi Android warga, operator bank sampah, serta bentor.
Web menggunakan API nyata, bukan mock fallback. IoT, pembayaran online, dan push notification di luar sprint v2.

## Struktur

- [API Laravel](api-backend/README.md): auth, saldo, setoran, jemput, preloved/chat.
- [Web React](frontend/README.md): dashboard DLH.
- [Mobile Flutter](mobile/README.md): tiga role operasional.
- [CI](.github/workflows/checks.yml): tes SQLite/PostgreSQL, lint/build web, Flutter, kontrak API, build image.
- [Progres dan keputusan](docs/progress.md).

Konfigurasi staging tersedia, tetapi service Railway/Supabase **belum dibuat atau di-deploy**.

## Lokal

Gunakan PHP 8.4+ sesuai dependency lock, Composer, Node 24, Flutter 3.47.7/Dart 3.13.5, dan PostgreSQL lokal.
Ikuti setup API untuk dependency, environment, key, dan migrasi. Jangan arahkan seeder/migrasi lokal ke Supabase.

Jalankan di terminal terpisah, dari subfolder masing-masing:

- api-backend/: `php artisan serve --host=127.0.0.1 --port=8000`.
- frontend/: `npm ci`, lalu `npm run dev`.
- mobile/: `flutter pub get`, lalu `flutter run --dart-define=USE_MOCK=false --dart-define=API_URL=http://10.0.2.2:8000/api/v1`.

Web: http://localhost:5173; API: http://localhost:8000/api/v1; health: /api/health.
Sesuaikan CORS_ALLOWED_ORIGINS dengan origin web. Jika memakai `adb reverse tcp:8000 tcp:8000`,
mobile dapat memakai http://127.0.0.1:8000/api/v1.
Mode mock mobile: `flutter run --dart-define=USE_MOCK=true`; data di memori, terpisah dari web,
dan hilang setelah proses berhenti.

## Akun demo backend

DemoSeeder membuat 3 bank sampah demo, harga, dan akun berikut:

| Role | Email |
| --- | --- |
| DLH/web | dlh@banksampah.test |
| Operator/mobile | operator1@banksampah.test (juga 2 dan 3) |
| Bentor/mobile | bentor1a@banksampah.test (juga 1b, 2a/2b, 3a/3b) |
| Warga/mobile | warga1@banksampah.test (hingga 5) |

Password melalui SEED_DEMO_PASSWORD, atau acak saat seed. Jangan commit password.
Seeder tidak mengganti password akun yang sudah ada. Gunakan data sintetis.

## Pencegahan setoran dobel

Mobile menyimpan request_id UUID dan rincian sebelum mengirim request. Jika respons putus atau aplikasi
ditutup, buka Catat setoran lalu **Cek ulang setoran**. ID/rincian lama dipakai kembali.
Jangan buat ulang transaksi yang belum terkonfirmasi dari perangkat/operator lain.

Backend mengunci operator, memeriksa hash rincian, dan memakai indeks unik operator/ID.
Request sama mengembalikan setoran dan saldo setelah transaksi pertama, bukan saldo terkini bila ada
transaksi berikutnya. Rincian berbeda dengan ID lama ditolak 422. Hasil terisolasi antaroperator.
Klien lama tanpa request_id tetap didukung, tetapi tidak mendapat perlindungan retry ini.
Penyimpanan tertunda dipisahkan per alamat API, operator, dan bank.

## Verifikasi

- api-backend/: `php vendor/phpunit/phpunit/phpunit`.
- frontend/: `npm run lint` dan `npm run build`.
- mobile/: `flutter analyze` dan `flutter test`.
- Kontrak: lihat [petunjuk mobile](mobile/README.md). CI menjalankan kontrak melawan PostgreSQL terisolasi.
  Jangan arahkan tes kontrak ke database operasional karena membuat/mengubah data.

## Staging Railway + Supabase DEV

Image memakai PHP 8.4/Apache, document root public/. Dockerfile dipilih agar ekstensi GD/PostgreSQL
dan runtime konsisten di lokal, CI, serta Railway. Build context: api-backend/.

1. Siapkan **Supabase DEV terpisah**. Ambil parameter Session pooler port 5432 dan S3 dari dashboard.
   Disk upload saat ini masih publik. Sebelum foto jemput dipisahkan ke bucket privat, hanya gunakan foto sintetis.
2. Buat service API Railway: root directory /api-backend, Dockerfile bernama Dockerfile, region Singapura,
   healthcheck /api/health, timeout 120 detik. Jangan set pre-deploy migration.
3. Isi environment di tabel. APP_KEY harus baru untuk staging dan tetap sama antar-deploy.
4. Setelah backup dan memastikan target DEV, jalankan `php artisan migrate --force` manual.
   Seed hanya database demo DEV: `php artisan db:seed --class=DemoSeeder --force`.
   Jangan memakai migrate:fresh pada database bersama.
   Untuk memindahkan data lokal ke database kosong, jalankan dari laptop dengan variabel `DB_*`, `UPLOAD_DISK`, dan
   `SUPABASE_S3_*` milik Supabase: `php artisan banksampah:salin-data database/database.sqlite`.
   Token login, sesi, cache, dan data sensor tidak ikut. Akun tetap memakai password lokal, jadi segera ganti sesudahnya.
5. Buat scheduler dari root/image sama, environment sama ditambah PROCESS_ROLE=scheduler.
   Scheduler tidak membutuhkan domain/healthcheck HTTP; menjalankan pemangkasan token terjadwal.
6. Web: root frontend/, build `npm ci && npm run build`, output dist, VITE_API_URL=https://<domain-api>/api/v1.
   Isi CORS service API dengan origin web persis.
7. Periksa tab Logs Railway, lalu uji login, upload, jemput/setoran/penarikan, dan isolasi bank A/B.
   /api/health hanya menyatakan API hidup, bukan membuktikan DB/storage.
8. Setelah CI pertama lulus, sepakati branch deployment dan aktifkan Wait for CI di Railway.
   Jangan aktifkan auto-deploy sebelum review.

Template tanpa rahasia: [API dan scheduler](api-backend/.env.staging.example) serta
[web](frontend/.env.staging.example). Nilai kosong dan domain `example.invalid` wajib diganti
di dashboard hosting. Jangan salin template staging ke `.env` backend laptop.

Setelan Railway yang disiapkan untuk kedua service:

| Setelan | API | Scheduler |
| --- | --- | --- |
| Root directory | `/api-backend` | `/api-backend` |
| Builder / Dockerfile | Dockerfile / `Dockerfile` | Dockerfile / `Dockerfile` |
| Start command | `sh deploy/start.sh` | `sh deploy/start.sh` |
| `PROCESS_ROLE` | `api` | `scheduler` |
| Healthcheck | `/api/health`, timeout 120 detik | Tidak diaktifkan |
| Public domain | HTTPS API staging | Tidak diperlukan |
| Pre-deploy command | Kosong; migrasi manual | Kosong |

Gunakan dashboard untuk setelan di atas. Konfigurasi legacy `railway.json`/`railway.toml`
tidak ditambahkan karena [Railway mengalihkannya ke Infrastructure as Code](https://docs.railway.com/infrastructure-as-code).
SDK IaC tidak diperlukan untuk menjalankan image Docker ini.

Yang perlu disiapkan sebelum deploy cloud:

- Project Railway dan izin mengakses repository GitHub ini, serta branch deployment yang dipilih.
- Project **Supabase DEV khusus demo**: host, port, nama database, username dan password dari
  [Connect / Session pooler](https://supabase.com/docs/guides/database/connecting-to-postgres).
- Bucket publik `uploads`, S3 Access Key ID, Secret Access Key, endpoint dan region dari
  [S3 configuration Supabase](https://supabase.com/docs/guides/storage/s3/authentication).
  URL publik bucket dipakai untuk `SUPABASE_S3_URL`.
- Hosting web dengan URL HTTPS untuk `CORS_ALLOWED_ORIGINS`; URL API HTTPS dipakai oleh web dan APK.
- `APP_KEY` baru khusus staging, sama untuk API dan scheduler, serta password kuat khusus akun demo.
  Key dapat dibuat dengan PHP 8.4+ lewat `php artisan key:generate --show`; masukkan langsung
  ke Railway Variables, jangan simpan nilainya dalam Git atau chat.

Password database, S3 secret dan key aplikasi diisi langsung di hosting. Cukup bagikan nama/link
project untuk koordinasi. Keystore Android baru diperlukan sebelum distribusi APK rilis,
bukan untuk uji emulator/debug.

| Environment API + scheduler | Nilai staging |
| --- | --- |
| APP_ENV / APP_DEBUG / APP_LOCALE | staging / false / id |
| APP_KEY / APP_URL | Key staging / URL HTTPS API |
| DB_CONNECTION / DB_HOST / DB_PORT | pgsql / host Session pooler DEV / 5432 |
| DB_DATABASE / DB_USERNAME / DB_PASSWORD | Dari project Supabase DEV |
| DB_SSLMODE | require |
| UPLOAD_DISK | supabase |
| SUPABASE_S3_KEY / SUPABASE_S3_SECRET / SUPABASE_S3_REGION | S3 key / secret / region DEV |
| SUPABASE_S3_BUCKET / SUPABASE_S3_ENDPOINT / SUPABASE_S3_URL | Bucket DEV / endpoint S3 / URL publik DEV |
| CORS_ALLOWED_ORIGINS | Origin HTTPS web, dipisah koma jika lebih dari satu |
| SESSION_DRIVER / CACHE_STORE / QUEUE_CONNECTION | database / database / sync |
| LOG_CHANNEL / LOG_LEVEL | stderr / warning |
| SANCTUM_EXPIRATION / FITUR_IOT | 10080 / false |
| SEED_DEMO_PASSWORD | Password lewat environment |
| PROCESS_ROLE | api atau scheduler |

PORT disediakan Railway. Image tidak membawa .env, database SQLite, upload, cache lokal, atau vendor dev.
Entrypoint tidak menjalankan migrate/seed. Untuk produksi gunakan APP_ENV=production dan SEED_ADMIN_EMAIL
serta SEED_ADMIN_PASSWORD; seeder produksi tidak membuat akun demo.

Uji image dari root repo dengan file environment khusus dev di luar repo:

```sh
docker build -t banksampah-staging ./api-backend
docker run --rm -p 8080:8080 --env-file <file-env-dev> banksampah-staging
```

Acuan: [Railway Dockerfiles](https://docs.railway.com/builds/dockerfiles),
[healthchecks](https://docs.railway.com/deployments/healthchecks).

## APK dan cadangan demo

APK debug/emulator bukan rilis. Pakai API HTTPS staging, USE_MOCK=false, keystore pribadi (jangan commit).
Gradle saat ini masih signing debug: penggantian signing dan uji HP fisik diperlukan sebelum distribusi.

Jika staging belum tersedia, gunakan backend laptop/data demo. Bila diperlukan akses dari luar jaringan,
`cloudflared tunnel --url http://localhost:8000` dapat membuat URL HTTPS sementara jika cloudflared tersedia.
Tunnel mengekspos API ke internet: hanya data/akun demo, tutup sesudah demo, dan sesuaikan URL mobile/CORS web.
