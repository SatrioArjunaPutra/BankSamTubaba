# API Backend Bank Sampah Tubaba

REST API Laravel 13 (PHP 8.3+, Sanctum 4) untuk aplikasi Smart Bank Sampah Tubaba.
Desain, role, dan kontrak API ada di [`../docs/prompt-bank-sampah-v2.md`](../docs/prompt-bank-sampah-v2.md) (bagian Prompt 0).

## Role

| Role          | Dipakai di | Keterangan                                              |
|---------------|------------|---------------------------------------------------------|
| `dlh`         | Web        | Pengawas tertinggi, melihat semua data                  |
| `bank_sampah` | Mobile     | Operator satu bank sampah                               |
| `bentor`      | Mobile     | Driver milik satu bank sampah                           |
| `warga`       | Mobile     | Daftar sendiri; default role untuk akun baru            |

## Setup lokal (anggota tim baru)

Database lokal memakai PostgreSQL 17 di Docker (Laravel Sail), sama dengan Supabase di produksi.

### 1. Siapkan Docker (Windows)

1. Aktifkan WSL2: buka PowerShell sebagai Administrator, jalankan `wsl --install`, lalu restart.
2. Pasang [Docker Desktop](https://www.docker.com/products/docker-desktop/). Di **Settings → General**, centang *Use the WSL 2 based engine*. Di **Settings → Resources → WSL integration**, aktifkan distro Ubuntu.
3. Buka terminal **Ubuntu** (WSL). Semua perintah di bawah dijalankan dari sana.

Clone repo di dalam filesystem WSL (misalnya `~/projects`), **bukan** di `/mnt/c/...`. Di `/mnt/c` Docker jauh lebih lambat.

### 2. Clone dan pasang dependency

```bash
git clone <url-repo> ~/projects/backend-bank-sampah
cd ~/projects/backend-bank-sampah/api-backend
cp .env.example .env

# Pasang vendor/ lewat container, tanpa perlu PHP/Composer di laptop
docker run --rm -u "$(id -u):$(id -g)" -v "$(pwd):/var/www/html" -w /var/www/html \
    laravelsail/php85-composer:latest composer install --ignore-platform-reqs
```

Nilai `DB_*` di `.env.example` sudah berisi profil LOKAL Sail (`DB_HOST=pgsql`, `bank_sampah`, `sail`/`password`). Jangan isi kredensial Supabase di laptop.

### 3. Jalankan

```bash
alias sail='sh $([ -f sail ] && echo sail || echo vendor/bin/sail)'   # simpan di ~/.bashrc

sail up -d                    # container app + pgsql (build pertama beberapa menit)
sail artisan key:generate
sail artisan migrate --seed   # data DEMO; password acak dicetak di console (atau SEED_DEMO_PASSWORD)
sail artisan test             # test memakai SQLite in-memory (lihat phpunit.xml)
```

API tersedia di `http://localhost/api/health`; endpoint aplikasi ada di `/api/v1` (kontrak di Prompt 0). Hentikan dengan `sail down`.
Data database tersimpan di volume Docker `sail-pgsql`. Untuk mengosongkannya, jalankan `sail down -v`.

### Tanpa Docker

Kalau Docker tidak bisa dipakai, test tetap jalan dengan PHP 8.3+ lokal (ekstensi `pdo_sqlite`):
`composer install` lalu `php artisan test`.

## Konfigurasi penting

| Env                 | Keterangan                                                                                       |
|---------------------|--------------------------------------------------------------------------------------------------|
| `FITUR_IOT`         | Default `false`. Route `/api/sensor` hanya didaftarkan jika `true`. Setelah mengubahnya di server yang memakai `route:cache`, jalankan ulang `php artisan route:cache`. |
| `APP_LOCALE`        | `id` agar pesan validasi berbahasa Indonesia (`lang/id/validation.php`).                          |
| `SEED_ADMIN_*`      | Akun `dlh` awal. Di production hanya akun ini (plus master jenis sampah) yang dibuat oleh `db:seed`, dan keduanya wajib diisi. |
| `SEED_DEMO_PASSWORD`| Password bersama semua akun DEMO lokal. Jika kosong, password dibuat acak dan dicetak sekali.     |
| `UPLOAD_DISK`       | `public` di lokal (jalankan `sail artisan storage:link` sekali), `supabase` di Railway. Isi juga `SUPABASE_S3_*`. |
| `IZINKAN_HAPUS_TRANSACTIONS` | Hanya untuk migrate di production: izinkan menghapus tabel `transactions` Tahap 1 yang masih berisi data. Backup dulu. |

## Data demo dan import bank sampah

`sail artisan migrate --seed` di lokal membuat data DEMO: 3 bank sampah (`BS-DEMO-01..03`) dengan harga, tiap bank 1 operator (`operator1@banksampah.test`, ...) dan 2 bentor + armada (`bentor1a@...`), 5 warga (`warga1@...`), dan 1 akun `dlh@banksampah.test`. Daftar email dicetak di console.

Data 76 bank sampah asli diimpor dari CSV formulir DLH (file ada di `data-private/`, tidak di-commit):

```bash
sail artisan banksampah:import "../data-private/DAFTAR BANK SAMPAH TUBABA 2026.csv"
```

Import aman diulang (berdasarkan kode `BS-TUBABA-xx` = nomor baris CSV, jadi jangan ubah urutan baris). No HP ketua dan link Google Drive tidak dibaca. Koordinat yang tidak terbaca diisi titik tengah kecamatan dengan `koordinat_estimasi=true`.

## Aturan database

- Laptop: hanya Postgres lokal di Docker.
- Supabase: hanya diakses dari Railway. **Jangan pernah** menjalankan `migrate:fresh` atau seeder demo ke Supabase dari laptop.
