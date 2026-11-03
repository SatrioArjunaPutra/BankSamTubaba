<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Fitur Sensor IoT (ditunda)
    |--------------------------------------------------------------------------
    |
    | Route /api/sensor hanya didaftarkan jika true. Di server yang memakai
    | `php artisan route:cache`, jalankan ulang route:cache setelah nilai ini
    | diubah agar daftar route ikut berubah.
    |
    */

    'fitur_iot' => (bool) env('FITUR_IOT', false),

    /*
    |--------------------------------------------------------------------------
    | Batas Resolusi Foto Unggahan
    |--------------------------------------------------------------------------
    |
    | Foto di-decode penuh oleh GD untuk membuang metadata (App\Support\GambarAman).
    | 25 megapiksel ≈ 100 MB memori; lebih dari itu ditolak.
    |
    */

    'maks_piksel_foto' => 25_000_000,

    /*
    |--------------------------------------------------------------------------
    | Akun Awal (db:seed)
    |--------------------------------------------------------------------------
    |
    | Dibaca lewat config (bukan env() langsung di seeder) agar tetap bekerja
    | setelah `php artisan config:cache`. Di production hanya akun dlh yang
    | dibuat dan email + password-nya wajib diisi. Di local, semua akun demo
    | memakai satu password bersama (demo_password).
    |
    */

    'seed' => [
        'admin_email' => env('SEED_ADMIN_EMAIL'),
        'admin_password' => env('SEED_ADMIN_PASSWORD'),
        'demo_password' => env('SEED_DEMO_PASSWORD'),
    ],

];
