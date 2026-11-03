# Prompt Pengembangan Bank Sampah Tubaba — v2 (Sprint 7 Hari)

Menggantikan `prompt-bank-sampah.md` (v1). Perubahan utama: 4 role (DLH, Bank Sampah, Bentor, Warga), saldo per bank sampah, aplikasi mobile Flutter, fitur preloved dengan chat (pembayaran COD), dan sensor IoT ditunda.

## Cara pakai

1. Tempel **Prompt 0** di awal **setiap** sesi agent, baik untuk backend, web, maupun mobile. Prompt ini juga menjadi dokumen desain dan kontrak API bersama.
2. Setelah itu tempel prompt untuk tugas yang mau dikerjakan (A sampai G).
3. Prompt-prompt ini bisa dikerjakan **bersamaan oleh orang yang berbeda**: mobile (E, F) cukup berpegang pada kontrak API di Prompt 0, tanpa perlu menunggu backend selesai.
4. Setiap tugas selesai: test lulus, cek manual, commit di branch sendiri, lalu buat PR.

## Alur kerja tim (Git)

- **Clone sekali** (`git clone ...`), jangan Download ZIP. `.env` dibagikan lewat chat pribadi, tidak di-commit.
- **Mulai kerja:** `git checkout main && git pull && git checkout -b fitur/<nama>`, lalu `composer install` dan `php artisan migrate` ke database **lokal**.
- **Selesai:** test lulus, commit, `git push -u origin fitur/<nama>`, buat PR, teman review, lalu merge ke `main`.
- **Bagi wilayah per folder** (`api-backend/`, `frontend/`, `mobile/`) supaya tidak konflik. Kalau harus mengubah file milik wilayah lain, kabari dulu.
- **Database:** setiap laptop memakai Postgres lokal di Docker (Sail). Supabase dipakai lewat Railway. **Jangan pernah** menjalankan `migrate:fresh` atau seeder demo ke Supabase dari laptop.
- **Railway (staging) otomatis deploy dari `main`** sejak hari 2. Flutter di HP dan web DLH memakai URL Railway ini.

## Jadwal 7 hari

| Hari | Backend (Laravel) | Web DLH (React) | Mobile (Flutter) |
|---|---|---|---|
| 1 | **A**: ganti role + saklar IoT + Docker ke Postgres, merge PR Tahap 1. **B1**: skema & auth | — | **E**: kerangka app, login, routing per role (data mock sesuai kontrak) |
| 2 | **B2**: setoran, donasi, saldo, penarikan, penjemputan, bentor. **G-staging**: deploy Railway staging, auto-deploy dari `main` | — | **E**: layar Warga |
| 3 | **C**: preloved + chat | **D**: login DLH, data dari API | **E**: layar Bank Sampah & Bentor |
| 4 | Perbaikan dari hasil integrasi | **D**: grafik kinerja, peta, moderasi | **F**: preloved + chat |
| 5 | Finalisasi produksi (lihat G) | Deploy web | Sambungkan ke API staging/produksi |
| 6 | **G**: uji alur end-to-end, perbaikan bug | Perbaikan bug | Build APK, perbaikan bug |
| 7 | Cadangan waktu + seed data demo | Cadangan | Cadangan + APK final |

**Kalau waktu tidak cukup, pangkas dalam urutan ini:** penjualan ke pengepul → jadwal jemput rutin → laporan/moderasi preloved → tawaran harga terstruktur di chat (cukup chat teks) → foto lebih dari 1 per barang. Push notification dan iOS memang **tidak masuk** sprint ini.

---

## Prompt 0: Konteks, Desain & Kontrak API (tempel di awal SETIAP sesi)

```
Kamu bekerja di proyek "Smart Bank Sampah Tubaba" (Kabupaten Tulang Bawang Barat). Monorepo:
- api-backend/ → Laravel 13, PHP 8.3+, Sanctum 4, PostgreSQL (Supabase). REST API JSON.
- frontend/    → Web dashboard DLH: React 19 + Vite + Tailwind v4 + react-leaflet.
- mobile/      → Aplikasi Flutter (dibuat di sprint ini) untuk role bank_sampah, bentor, warga.
Deadline: 7 hari. Utamakan fitur yang BERJALAN end-to-end daripada fitur lengkap tapi setengah jadi.

== ROLE ==
- dlh         (WEB)    : pengawas tertinggi. Lihat SEMUA data, grafik kinerja per bank sampah, peta, buat/verifikasi akun bank sampah, kelola master jenis sampah, moderasi preloved. Tidak mengurus operasional harian.
- bank_sampah (MOBILE) : operator satu bank sampah. Timbang setoran/donasi, atur harga per jenis sampah, kelola bentor & tugaskan penjemputan, setujui penarikan saldo, catat penjualan ke pengepul. HANYA data bank sampahnya sendiri.
- bentor      (MOBILE) : driver milik satu bank sampah. Lihat & jalankan tugas jemput miliknya, update status.
- warga       (MOBILE) : daftar sendiri. Setor/donasi sampah, minta jemput, lihat saldo per bank sampah, ajukan penarikan, jual-beli preloved + chat.
Aturan tenancy: users.bank_sampah_id WAJIB untuk role bank_sampah & bentor, NULL untuk dlh & warga. Semua query role bank_sampah/bentor otomatis dibatasi ke bank_sampah_id miliknya (pakai Policy + scope), dan akses lintas bank sampah → 403/404.

== FITUR DITUNDA (JANGAN dikerjakan) ==
- Sensor IoT: kode Tahap 1 (tabel devices, middleware device.auth, POST /api/sensor) dipertahankan tapi dimatikan dengan config banksampah.fitur_iot (env FITUR_IOT=false). Jangan dibangun lebih lanjut.
- Pembayaran online preloved (COD saja), push notification, aplikasi iOS.

== MODEL DATA ==
- bank_sampah: id, kode (BS-TUBABA-xx, unique), nama, tiyuh, kecamatan, alamat, lat, lng, koordinat_estimasi bool, no_hp_publik nullable, is_aktif bool, timestamps. Diimpor dari CSV (tanpa no HP ketua & link Drive).
- users: id, name, email unique, phone, password, role enum, bank_sampah_id nullable FK, alamat nullable, lat/lng nullable, is_aktif bool, timestamps.
- jenis_sampah (master, dikelola dlh): id, nama (Plastik, Kardus, Kertas, Logam, Botol Kaca, Minyak Jelantah, dll), satuan (kg), is_aktif.
- harga_sampah: id, bank_sampah_id, jenis_sampah_id, harga_per_kg decimal(12,2), unique(bank_sampah_id, jenis_sampah_id).
- nasabah (saldo per bank sampah): id, warga_id, bank_sampah_id, saldo decimal(15,2) default 0, unique(warga_id, bank_sampah_id). Dibuat otomatis saat setoran pertama.
- setoran: id, bank_sampah_id, warga_id, tipe enum(jual|donasi), total_kg decimal(10,2), total_nilai decimal(15,2) (0 untuk donasi), penjemputan_id nullable, dicatat_oleh, catatan, timestamps.
- setoran_items: id, setoran_id, jenis_sampah_id, berat_kg decimal(8,2), harga_per_kg decimal(12,2) (snapshot saat transaksi), subtotal decimal(15,2).
- armada: id, bank_sampah_id, driver_id (user role bentor, unique), plat_nomor, kapasitas_kg, status enum(siaga|bertugas|nonaktif), timestamps.
- penjemputan: id, warga_id, bank_sampah_id, armada_id nullable, alamat, lat, lng, perkiraan_kg nullable, catatan, foto_path nullable, jadwal_at nullable, status enum(diajukan|dijadwalkan|menuju|diambil|selesai|ditolak|dibatalkan), alasan_tolak nullable, timestamps + kolom waktu tiap status (dijadwalkan_at, diambil_at, selesai_at).
- penarikan: id, warga_id, bank_sampah_id, jumlah decimal(15,2), status enum(diajukan|disetujui|ditolak), diproses_oleh nullable, catatan, timestamps.
- penjualan_pengepul: id, bank_sampah_id, nama_pengepul, jenis_sampah_id, berat_kg, harga_per_kg, total, tanggal, dicatat_oleh, timestamps.
- preloved_items: id, penjual_id, judul, deskripsi, kategori, kondisi enum(baru|seperti_baru|bekas_baik|bekas), harga decimal(12,2), kecamatan, foto (json array path, maks 5), status enum(tersedia|terjual|disembunyikan), timestamps.
- percakapan: id, preloved_item_id, pembeli_id, penjual_id, last_message_at, unique(preloved_item_id, pembeli_id).
- pesan: id, percakapan_id, pengirim_id, isi text nullable, tawaran_harga decimal nullable, dibaca_at nullable, timestamps. Minimal salah satu dari isi/tawaran_harga terisi.
- laporan_preloved: id, preloved_item_id, pelapor_id, alasan, status enum(baru|ditindak|diabaikan), timestamps.

== ATURAN BISNIS ==
- Setoran tipe jual: subtotal = berat × harga_sampah bank itu (snapshot). Saldo nasabah (warga, bank_sampah) += total_nilai. Wajib DB::transaction + lockForUpdate.
- Setoran tipe donasi: tetap dicatat per item & berat, total_nilai = 0, saldo tidak berubah. Dihitung di kinerja.
- Penarikan: jumlah <= saldo nasabah di bank itu. Saldo DIKURANGI saat disetujui (bukan saat diajukan), dicek ulang dalam lock. Maks 1 penarikan berstatus diajukan per nasabah.
- Penjemputan: warga pilih bank sampah tujuan → diajukan → bank_sampah tugaskan armada + jadwal (dijadwalkan) atau tolak → bentor: menuju → diambil → bank_sampah mencatat setoran dengan penjemputan_id → selesai. Validasi urutan status, transisi tidak sah → 422.
- Bentor hanya melihat & mengubah penjemputan yang armada_id-nya miliknya.
- Preloved: warga tidak bisa chat dengan barangnya sendiri. Hanya penjual & pembeli percakapan itu yang bisa membaca/mengirim pesan. Penjual menandai terjual. DLH bisa menyembunyikan barang.
- Uang & berat di JSON selalu number. Tanggal ISO 8601.

== KONTRAK API (prefix /api/v1, Bearer token Sanctum) ==
Format sukses: {"status":"sukses","pesan":"...","data":...}  (+ "meta","links" untuk pagination, 20/halaman)
Format gagal : {"status":"gagal","pesan":"...","errors":{...}?}

Auth (publik):
  POST /auth/register            warga saja: name, email, phone, password, password_confirmation
  POST /auth/login               email, password, device_name? → data.user, data.token, data.expires_at
Auth (login):
  GET  /me    PATCH /me    PUT /me/password    POST /auth/logout
Umum (login):
  GET  /bank-sampah?kecamatan=&q=            GET /bank-sampah/{id} (termasuk daftar harga)
  GET  /bank-sampah/nearby?lat=&lng=&radius_km=
  GET  /jenis-sampah
Warga:
  GET  /warga/saldo                          daftar saldo per bank sampah
  GET  /warga/setoran?bank_sampah_id=        riwayat setoran & donasi
  POST /warga/penjemputan                    GET /warga/penjemputan    POST /warga/penjemputan/{id}/batal
  POST /warga/penarikan                      GET /warga/penarikan
Bank sampah (scoped ke bank miliknya):
  GET  /bs/dashboard                         ringkasan hari ini/bulan ini
  GET  /bs/harga    PUT /bs/harga            (array {jenis_sampah_id, harga_per_kg})
  GET  /bs/nasabah?q=                        cari warga (nama/phone/email) untuk dicatat setorannya
  POST /bs/setoran                           {warga_id, tipe, items:[{jenis_sampah_id, berat_kg}], penjemputan_id?}
  GET  /bs/setoran
  GET  /bs/penjemputan?status=               PATCH /bs/penjemputan/{id} {aksi: jadwalkan|tolak, armada_id?, jadwal_at?, alasan?}
  GET  /bs/armada   POST /bs/armada  PATCH /bs/armada/{id}    POST /bs/bentor (buat akun driver)
  GET  /bs/penarikan?status=                 PATCH /bs/penarikan/{id} {aksi: setujui|tolak, catatan?}
  POST /bs/penjualan-pengepul                GET /bs/penjualan-pengepul
Bentor:
  GET  /bentor/tugas?status=                 PATCH /bentor/tugas/{id}/status {status: menuju|diambil}
  PATCH /bentor/armada/status {status: siaga|nonaktif}
Preloved (warga):
  GET  /preloved?q=&kategori=&kecamatan=     GET /preloved/{id}
  POST /preloved (multipart, foto[] maks 5, maks 2MB/foto)   PATCH /preloved/{id}   DELETE /preloved/{id}
  POST /preloved/{id}/terjual                GET /preloved/saya
  POST /preloved/{id}/lapor {alasan}
Chat (warga):
  POST /preloved/{id}/chat                   buka/ambil percakapan sebagai pembeli
  GET  /chat                                 daftar percakapan + pesan terakhir + jumlah belum dibaca
  GET  /chat/{id}/pesan?after_id=            polling: hanya pesan baru setelah after_id
  POST /chat/{id}/pesan {isi?, tawaran_harga?}
  POST /chat/{id}/baca                       tandai dibaca
DLH:
  GET  /dlh/ringkasan                        total kg, nasabah aktif, nilai transaksi, jemput aktif, se-Tubaba
  GET  /dlh/kinerja?periode=bulan&dari=&sampai=   per bank sampah: total_kg, kg_donasi, nasabah_aktif, nilai_setoran, rata2_waktu_jemput_jam, jemput_selesai
  GET  /dlh/kinerja/{bank_sampah_id}/tren    deret waktu harian/bulanan untuk grafik
  GET  /dlh/bank-sampah  POST /dlh/bank-sampah  PATCH /dlh/bank-sampah/{id}
  POST /dlh/bank-sampah/{id}/operator        buat akun role bank_sampah
  GET/POST/PATCH /dlh/jenis-sampah
  GET  /dlh/laporan-preloved   PATCH /dlh/preloved/{id} {status: disembunyikan|tersedia}

Chat realtime: pakai POLLING (mobile panggil GET /chat/{id}/pesan?after_id= tiap 3 detik saat layar chat terbuka, 15 detik untuk daftar chat). JANGAN pakai WebSocket di sprint ini.
File upload: selalu lewat Storage::disk(config('filesystems.upload_disk')). Lokal/test = "public"; produksi = "supabase" (driver s3 ke Supabase Storage, bucket publik "uploads"), karena server hosting tidak menyimpan file permanen. Validasi mimes:jpg,jpeg,png,webp.
Arsitektur deploy: Laravel di Railway (region Singapura) → database & storage di Supabase. Supabase TIDAK menjalankan Laravel.

== ATURAN KERJA (WAJIB) ==
1. Baca file relevan, tulis rencana singkat (file yang diubah/dibuat), tunggu konfirmasi saya sebelum eksekusi.
2. Kerjakan HANYA tugas yang saya minta.
3. Laravel: Form Request, Policy, API Resource, Service untuk logika uang. Pesan user Bahasa Indonesia.
4. Feature test WAJIB untuk: uang/saldo, otorisasi per role, isolasi antar bank sampah, akses chat. Endpoint lain minimal 1 test sukses + 1 test akses ditolak. Test pakai SQLite in-memory.
5. Jangan commit .env, password, token, data pribadi.
6. Akhiri dengan: ringkasan, daftar file, perintah menjalankan, hasil test, hal yang perlu dicek manual.
```

---

## Prompt A: Ganti Role + Saklar IoT (di branch `tahap-1-keamanan`, hari 1)

```
Sebelum PR Tahap 1 di-merge, sesuaikan dengan desain v2 (lihat Prompt 0):

1. Enum UserRole menjadi: Dlh='dlh', BankSampah='bank_sampah', Bentor='bentor', Warga='warga'. Hapus admin/petugas/nasabah.
   Default kolom role = 'warga' (migration baru, jangan edit migration lama).
   Migration juga memetakan data lama: admin→dlh, petugas→bank_sampah, nasabah→warga.
2. Update middleware route, Form Request (exists ... where role warga), factory state (dlh(), bankSampah(), bentor(), warga()), seeder (production: hanya 1 akun dlh dari SEED_ADMIN_*), dan semua test.
   Sementara POST /api/transaksi boleh untuk role bank_sampah (akan diganti /api/v1/bs/setoran di Prompt B).
3. Saklar IoT: config banksampah.fitur_iot = env('FITUR_IOT', false). Di routes/api.php, route POST/GET /sensor hanya didaftarkan jika true.
   Test: fitur_iot false → POST /api/sensor 404; true → perilaku lama tetap lulus.
   Tambah FITUR_IOT=false ke .env.example.
4. Docker lokal disamakan dengan Supabase (PostgreSQL), bukan MySQL:
   - compose.yaml: ganti service mysql dengan pgsql (pakai `php artisan sail:install --with=pgsql` atau edit manual, image postgres 17, volume sail-pgsql, healthcheck pg_isready).
   - .env.example: tambahkan komentar 2 profil DB: (a) LOKAL Sail → DB_HOST=pgsql, DB_PORT=5432, DB_DATABASE=bank_sampah, DB_USERNAME=sail, DB_PASSWORD=password; (b) SUPABASE → diisi hanya di Railway.
   - Pastikan `sail up -d`, `sail artisan migrate --seed`, dan `sail artisan test` berjalan. Tulis langkah setup untuk anggota tim baru di README (Windows: Docker Desktop + WSL2).
5. Jalankan php artisan test, commit baru, lalu push & buat PR (sesuai instruksi sebelumnya).
```

---

## Prompt G-staging: Deploy Staging Railway (hari 2)

```
Siapkan STAGING di Railway (region Singapura) yang otomatis deploy setiap ada perubahan di branch main, sesuai bagian deploy di Prompt G butir 2 (konfigurasi build, env, schedule), dengan perbedaan:
- APP_ENV=staging, database = project Supabase DEV (bukan produksi), UPLOAD_DISK=supabase ke bucket dev.
- Setelah deploy pertama: migrate --force lalu seeder demo (boleh, karena ini database dev).
- Endpoint /api/health harus bisa diakses dari HP lewat HTTPS.
- Tulis di README: URL staging, cara melihat log Railway, dan aturan "main harus selalu lulus test karena langsung ter-deploy".
Tulis rencana dan langkah yang harus saya lakukan di dashboard Railway/Supabase, lalu tunggu konfirmasi saya.
```

---

## Prompt B: Backend Inti (hari 1–2)

```
Kerjakan BACKEND INTI sesuai Prompt 0. Bagi jadi 2 bagian, berhenti & laporkan di antaranya.

BAGIAN B1 – Skema, auth, bank sampah:
- Migration untuk semua tabel di MODEL DATA KECUALI preloved_items, percakapan, pesan, laporan_preloved (itu Prompt C).
- Tabel transactions lama dari Tahap 1: cek dulu isinya. Jika hanya data uji, ganti dengan setoran/setoran_items (migration drop + create). Jika ada data asli, BERHENTI dan tanya saya.
- Pindahkan route ke prefix /api/v1 (hapus route lama non-v1 kecuali /api/health).
- Auth: register warga, login, me, logout, ganti password. Rate limiter login & register tetap.
- Middleware/scope tenancy: trait BelongsToBankSampah + Policy. Role bank_sampah/bentor tanpa bank_sampah_id → 403.
- Command `php artisan banksampah:import {csv}`: port parser koordinat dari parseTubaba.js ke PHP, idempoten (updateOrCreate by kode), JANGAN simpan no HP ketua & link Drive. Kolom angka teks bebas tidak perlu diimpor di sprint ini.
- Seeder jenis_sampah default (Plastik, Kardus, Kertas, Logam, Botol Kaca, Minyak Jelantah).
- Endpoint Umum & DLH bagian bank-sampah, jenis-sampah, operator.
- Seeder DEMO (hanya local): 3 bank sampah dengan harga, 1 operator & 2 bentor + armada per bank, 5 warga. Cetak kredensial ke console.

BAGIAN B2 – Operasional:
- SetoranService (jual/donasi, snapshot harga, update saldo nasabah dalam lock), PenarikanService (setujui dalam lock, cek saldo ulang), PenjemputanService (state machine transisi status).
- Semua endpoint Warga, Bank sampah, Bentor di kontrak API.
- Endpoint DLH ringkasan & kinerja (pakai query agregat, tanpa N+1; rata2_waktu_jemput_jam = rata-rata selesai_at - created_at).
- Test wajib: setoran jual menambah saldo sesuai harga bank itu; donasi tidak menambah saldo; harga berubah tidak mengubah setoran lama; penarikan > saldo ditolak; dua penarikan diajukan ditolak; operator bank A tidak bisa melihat/mengubah data bank B (setoran, penjemputan, penarikan, armada); bentor tidak bisa mengubah tugas armada lain; transisi status tidak sah → 422; warga tidak bisa akses /bs/* dan /dlh/*.

Tulis rencana B1 dulu dan tunggu konfirmasi saya.
```

---

## Prompt C: Preloved + Chat Backend (hari 3)

```
Kerjakan PRELOVED + CHAT sesuai Prompt 0 (tabel preloved_items, percakapan, pesan, laporan_preloved dan semua endpoint Preloved, Chat, serta DLH moderasi).

- Upload foto: Storage::disk(config('filesystems.upload_disk')), nama file acak (Str::uuid), simpan path relatif, resource mengembalikan URL lengkap lewat Storage::url(). Hapus file saat barang dihapus.
- Siapkan disk "supabase" di config/filesystems.php (driver s3; env SUPABASE_S3_KEY, SUPABASE_S3_SECRET, SUPABASE_S3_REGION, SUPABASE_S3_BUCKET, SUPABASE_S3_ENDPOINT, SUPABASE_S3_URL, use_path_style_endpoint=true) + paket league/flysystem-aws-s3-v3. Env UPLOAD_DISK=public untuk lokal. Test pakai Storage::fake().
- GET /preloved hanya menampilkan status tersedia (kecuali milik sendiri di /preloved/saya). Barang disembunyikan tidak bisa dibuka chat baru.
- POST /preloved/{id}/chat: idempoten (firstOrCreate), tolak jika pembeli = penjual.
- GET /chat/{id}/pesan?after_id=: urut naik, maks 50, cepat (index percakapan_id,id).
- GET /chat: pesan terakhir + unread_count tanpa N+1.
- Rate limit kirim pesan: 30/menit per user. Panjang isi maks 1000 karakter. tawaran_harga > 0.
- Test wajib: orang ketiga tidak bisa membaca/mengirim pesan percakapan orang lain (403); penjual tidak bisa chat barangnya sendiri; after_id hanya mengembalikan pesan baru; barang terjual/disembunyikan tidak muncul di daftar; hanya pemilik yang bisa edit/hapus/tandai terjual; DLH bisa menyembunyikan; upload non-gambar ditolak.

Tulis rencana dan tunggu konfirmasi saya.
```

---

## Prompt D: Web Dashboard DLH (hari 3–4)

```
Kerjakan WEB DASHBOARD DLH di folder frontend/ sesuai Prompt 0. Web ini HANYA untuk role dlh.

1. Login (POST /api/v1/auth/login), tolak role selain dlh. Token di sessionStorage. 401 → kembali ke login. Tombol logout.
2. services/api.js: satu fungsi request() terpusat (VITE_API_URL, Bearer token, tangani 401/403/422/429 dengan pesan Indonesia). Hook useFetch sederhana (loading, error, data, refetch). Tanpa library baru kecuali saya setujui.
3. Halaman:
   - Ringkasan: kartu angka dari /dlh/ringkasan.
   - Kinerja: tabel peringkat bank sampah (/dlh/kinerja) bisa diurutkan + filter periode; klik baris → grafik tren (/dlh/kinerja/{id}/tren). Grafik pakai SVG/komponen ringan (atau recharts jika saya setujui).
   - Peta: titik bank sampah dari /bank-sampah, warna berdasarkan kinerja/jumlah jemput aktif. Pertahankan gaya visual yang ada.
   - Kelola Bank Sampah: daftar, tambah/edit, aktif/nonaktif, buat akun operator.
   - Jenis Sampah: CRUD master.
   - Moderasi Preloved: daftar laporan, sembunyikan/tampilkan barang.
4. HAPUS komponen yang tidak dipakai lagi: DropPointMonitor (sensor), simulator, BentorDispatch, TransactionsPengepul, RecycleMarketplace versi mock, mockData.js, tubabaBankSampah.json. FlowchartViewer boleh dipertahankan jika diperbarui ke alur v2, atau dihapus.
5. Loading skeleton, empty state, toast error. Toast sukses hanya setelah API membalas sukses.
6. frontend/.env.example (VITE_API_URL). npm run build & npm run lint lolos.

Tulis rencana per halaman dan tunggu konfirmasi saya.
```

---

## Prompt E: Aplikasi Flutter: Kerangka + Role Warga, Bank Sampah, Bentor (hari 1–3)

```
Buat aplikasi Flutter di folder mobile/ sesuai Prompt 0 (role bank_sampah, bentor, warga dalam SATU aplikasi).

Teknologi: Flutter stable terbaru, Riverpod (state), dio (HTTP), go_router (navigasi + redirect per role), flutter_secure_storage (token), flutter_map + latlong2 (peta OpenStreetMap, tanpa API key), geolocator, image_picker, intl (format Rupiah & tanggal Indonesia). Tambah paket lain hanya dengan persetujuan saya.

Struktur: lib/core (api client, error, theme, router), lib/features/<fitur>/{data,domain? opsional,presentation}. Model dari JSON kontrak API (boleh pakai json_serializable atau manual, konsisten).

1. Kerangka:
   - ApiClient dengan base URL dari --dart-define=API_URL (default http://10.0.2.2:8000/api/v1 untuk emulator Android), interceptor Bearer token, tangani 401 (logout otomatis) & tampilkan pesan error dari field "pesan".
   - MODE MOCK: flag --dart-define=USE_MOCK=true memakai repository palsu yang mengembalikan data sesuai kontrak API, supaya UI bisa dikerjakan sebelum backend siap.
   - Splash → cek token → GET /me → arahkan ke shell sesuai role. Login & Register (warga).
   - Tema hijau daur ulang, Bahasa Indonesia, mendukung layar kecil (Android low-end).
2. Warga (bottom nav: Beranda, Jemput, Preloved [placeholder untuk Prompt F], Chat [placeholder], Akun):
   - Beranda: total saldo, saldo per bank sampah, tombol Minta Jemput, riwayat setoran/donasi terbaru.
   - Cari bank sampah (list + peta, nearby berdasar lokasi), detail bank + daftar harga.
   - Minta Jemput: pilih bank, pin lokasi di peta (default lokasi GPS), perkiraan kg, catatan, foto opsional. Daftar & status permintaan, batalkan saat masih diajukan.
   - Penarikan: pilih bank, jumlah (≤ saldo), riwayat.
   - Akun: profil, ganti password, logout.
3. Bank Sampah (bottom nav: Beranda, Setoran, Jemput, Bentor, Lainnya):
   - Beranda: ringkasan /bs/dashboard.
   - Catat Setoran: cari warga → pilih tipe Jual/Donasi → tambah baris jenis sampah + berat → tampilkan total realtime dari harga bank → konfirmasi → simpan. Riwayat setoran.
   - Jemput: tab per status; jadwalkan (pilih armada + waktu) atau tolak; setelah status diambil tombol "Catat Setoran" yang mengisi penjemputan_id.
   - Bentor: daftar armada & driver, tambah akun bentor + armada, ubah status.
   - Lainnya: atur harga per jenis sampah, persetujuan penarikan, penjualan ke pengepul, logout.
4. Bentor (satu layar utama + akun):
   - Daftar tugas aktif; detail tugas dengan peta lokasi warga, tombol buka Google Maps (url_launcher, minta persetujuan saya), telepon warga, tombol status Menuju → Diambil. Toggle siaga/nonaktif.
5. Kualitas: flutter analyze bersih, widget test untuk login redirect per role dan form setoran (hitung total). Cara build APK: flutter build apk --release --dart-define=API_URL=...

Kerjakan bertahap: (1) kerangka + auth, BERHENTI & lapor; (2) warga; (3) bank sampah; (4) bentor. Tulis rencana tahap (1) dan tunggu konfirmasi saya.
```

---

## Prompt F: Flutter: Preloved + Chat (hari 4)

```
Lanjutkan aplikasi mobile/: isi tab Preloved dan Chat untuk role warga sesuai kontrak API di Prompt 0.

- Preloved: grid barang + pencarian, filter kategori & kecamatan, pull-to-refresh, infinite scroll (pagination). Detail barang: carousel foto, harga, kondisi, penjual, tombol "Chat Penjual" (sembunyikan untuk barang sendiri), tombol Laporkan.
- Jual Barang: form judul, deskripsi, kategori, kondisi, harga, kecamatan, foto 1–5 (image_picker, kompres sebelum upload agar <2MB). "Barang Saya": edit, hapus, tandai terjual.
- Chat: daftar percakapan (foto barang, nama lawan bicara, pesan terakhir, badge belum dibaca), polling 15 detik saat tab aktif.
- Ruang chat: header info barang + harga; bubble pesan; input teks; tombol "Tawar Harga" yang mengirim tawaran_harga dan tampil sebagai bubble khusus (Rp). Polling GET /chat/{id}/pesan?after_id= tiap 3 detik HANYA saat layar terbuka & app di foreground (hentikan saat dispose/background). Tandai dibaca saat dibuka. Kirim pesan dengan optimistic UI + status gagal/kirim ulang.
- Penjual bisa menandai terjual langsung dari ruang chat.
- Catatan pembayaran: tampilkan info "Transaksi dilakukan langsung (COD). Periksa barang sebelum membayar."
- flutter analyze bersih; widget test untuk bubble tawaran dan logika polling (after_id bertambah, tidak duplikat).

Tulis rencana dan tunggu konfirmasi saya.
```

---

## Prompt G: Integrasi, Deploy & Demo (hari 5–7)

```
Kerjakan INTEGRASI & DEPLOY.

1. Uji alur end-to-end di lingkungan lokal (backend + web + APK di HP/emulator), buat checklist hasilnya:
   a. Warga daftar → minta jemput → operator jadwalkan ke bentor → bentor menuju & diambil → operator catat setoran jual → saldo warga bertambah → warga ajukan penarikan → operator setujui → saldo berkurang.
   b. Setoran donasi tercatat dan masuk kinerja tanpa menambah saldo.
   c. Warga A pasang barang → warga B chat & tawar → A balas → A tandai terjual → barang hilang dari daftar.
   d. DLH melihat kinerja 3 bank sampah demo, menyembunyikan barang yang dilaporkan.
   e. Operator bank A tidak bisa melihat data bank B.
2. Deploy backend ke RAILWAY (region Singapura), database & storage tetap di Supabase:
   - Siapkan konfigurasi deploy (nixpacks/railway.json atau Dockerfile, pilih yang paling sederhana dan jelaskan alasannya): PHP 8.3+, composer install --no-dev --optimize-autoloader, config:cache, route:cache, start dengan php artisan serve --host=0.0.0.0 --port=$PORT ATAU FrankenPHP/Octane jika lebih stabil.
   - Service kedua (atau cron Railway) untuk `php artisan schedule:run` tiap menit.
   - Daftar env produksi lengkap: APP_ENV=production, APP_DEBUG=false, APP_KEY, APP_URL, DB_* (Supabase Session pooler, port 5432), UPLOAD_DISK=supabase + SUPABASE_S3_*, CORS_ALLOWED_ORIGINS (domain web DLH), SANCTUM_EXPIRATION, FITUR_IOT=false, SEED_ADMIN_*.
   - Migrate: ikuti langkah aman dari Tahap 1 (cek role, backup pg_dump, uji di project dev, baru migrate --force). JANGAN migrate otomatis di setiap deploy.
   - Buat bucket "uploads" (publik) di Supabase Storage + S3 access key; tulis langkahnya untuk saya, jangan simpan key di repo.
   - RENCANA CADANGAN demo: jalankan backend di laptop + Cloudflare Tunnel (cloudflared tunnel --url http://localhost:8000) untuk URL HTTPS sementara. Tulis langkahnya.
3. Deploy web DLH (Vercel/Netlify/static di server yang sama) dengan VITE_API_URL produksi.
4. Build APK release dengan API_URL produksi. Pastikan HTTPS (Android memblokir HTTP polos secara default).
5. Seeder demo untuk presentasi (jalankan HANYA di database demo, bukan produksi asli).
6. README: arsitektur, role & hak akses, cara setup lokal 3 bagian, cara deploy, akun demo (tanpa password di repo).

Tulis rencana dan tunggu konfirmasi saya.
```

---

## Checklist cek manual setiap tugas selesai

- [ ] Test lulus (`php artisan test` / `flutter test` / `npm run build`)
- [ ] Coba alurnya langsung dengan akun tiap role
- [ ] Operator bank A tidak bisa melihat data bank B
- [ ] `git status`: tidak ada `.env`, CSV asli, `data-private/`, atau kredensial
- [ ] Baca ringkasan dari agent sebelum commit
