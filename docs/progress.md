# Progres Sprint v2

Branch: `sprint-v2`. Urutan mode sprint: B1 → B2 → C → D → E → F (G-staging & G ditunda).
Jika sesi terputus, mulai dari file ini lalu `docs/prompt-bank-sampah-v2.md`.

PHP lokal: pakai PHP 8.4 winget (`php` di PATH adalah XAMPP 8.2). Test: `vendor/bin/phpunit` di `api-backend/`.
Postgres lokal untuk verifikasi: `docker compose -p banksampah-cek up -d pgsql` dengan
`DB_DATABASE=bank_sampah DB_USERNAME=sail DB_PASSWORD=password FORWARD_DB_PORT=55432`.

---

## B1 – Skema, auth, bank sampah ✅ (2026-10-28)

**Selesai**
- Migration semua tabel MODEL DATA kecuali preloved/chat: `bank_sampah`, `jenis_sampah`, `harga_sampah`,
  `nasabah`, `armada`, `penjemputan`, `setoran`, `setoran_items`, `penarikan`, `penjualan_pengepul`;
  `users` + `bank_sampah_id`, `alamat`, `lat`, `lng`, `is_aktif`, − `saldo`.
- Tabel `transactions` Tahap 1 di-drop beserta seluruh kodenya (controller, service, model, test).
- Route pindah ke `/api/v1`. Route lama dihapus kecuali `/api/health` dan `/api/sensor` (IoT, di balik `FITUR_IOT`).
- Auth: `POST /auth/register` (selalu warga), `POST /auth/login`, `POST /auth/logout`, `GET/PATCH /me`, `PUT /me/password`.
- Middleware `akun.aktif`: akun nonaktif → 403; role bank_sampah/bentor tanpa `bank_sampah_id` atau bank nonaktif → 403.
- Trait `BelongsToBankSampah` (`scopeMilik($user)`, `dimilikiOleh($user)`) — dipakai Policy di B2.
- Umum: `GET /bank-sampah`, `/bank-sampah/nearby`, `/bank-sampah/{id}` (+harga), `/jenis-sampah`.
- DLH: `GET/POST/PATCH /dlh/bank-sampah`, `POST /dlh/bank-sampah/{id}/operator`, `GET/POST/PATCH /dlh/jenis-sampah`.
- `php artisan banksampah:import {csv}` + `App\Support\KoordinatParser` (port `parseTubaba.js`).
- Seeder: `JenisSampahSeeder` (juga di production), `DemoSeeder` (lokal).
- Pesan validasi Bahasa Indonesia: `lang/id/validation.php`, `APP_LOCALE=id`.

**File utama**: `database/migrations/2026_10_28_*`, `app/Models/{BankSampah,JenisSampah,HargaSampah,Armada}.php`,
`app/Models/Concerns/BelongsToBankSampah.php`, `app/Http/Middleware/EnsureAkunAktif.php`,
`app/Http/Controllers/Api/{AuthController,ProfilController,BankSampahController,JenisSampahController}.php`,
`app/Http/Controllers/Api/Dlh/*`, `app/Console/Commands/ImportBankSampah.php`, `app/Support/KoordinatParser.php`,
`database/seeders/{DemoSeeder,JenisSampahSeeder}.php`, `routes/api.php`.

**Hasil test**
- `phpunit` SQLite in-memory: 74 lulus (583 assertion).
- `phpunit` terhadap PostgreSQL 17 lokal (Docker): 74 lulus.
- `migrate:fresh --seed` di Postgres 17: OK. Import CSV asli: 76 bank sampah (22 koordinat estimasi, 0 tanpa koordinat);
  import ulang 0 dibuat / 76 diperbarui. Dibandingkan dengan `frontend/src/data/tubabaBankSampah.json`: 54 koordinat
  pasti identik, 22 estimasi sama-sama estimasi, 0 beda.

**Keputusan (disetujui sebelum migration)**
1. FK `restrict` di tabel uang/riwayat; nonaktifkan lewat `is_aktif`, bukan hapus.
2. Drop `transactions` ditolak di production jika berisi data, kecuali `IZINKAN_HAPUS_TRANSACTIONS=true`.
3. `users.saldo` dihapus; `/me` tidak lagi berisi saldo (pakai `GET /warga/saldo` di B2).
4. `setoran.penjemputan_id` unique (1 jemput = 1 setoran).
5. Kode import `BS-TUBABA-` + nomor baris CSV (sama dengan parseTubaba.js); jangan ubah urutan baris CSV.
6. Koordinat estimasi deterministik (hash nama/kode), bukan acak.
7. Baris CSV tanpa koordinat & kecamatan tak dikenal tetap diimpor dengan lat/lng NULL (di data asli: 0 baris).
8. Seeder lokal = data DEMO (`BS-DEMO-01..03`), satu password `SEED_DEMO_PASSWORD`.

**Keputusan kecil tambahan**
- `/api/sensor` tetap di luar `/api/v1` karena alamatnya tertanam di firmware perangkat.
- Kolom status/enum disimpan sebagai string + PHP Enum (seperti `role`).
- Register mengembalikan token (langsung login). Ganti password mencabut token di perangkat lain.
- `PATCH /me` hanya name, phone, alamat, lat, lng (email tidak bisa diubah sendiri).
- `POST /dlh/bank-sampah` membuat kode `BS-TUBABA-xx` berikutnya jika `kode` tidak dikirim.
- Env `BANK_SAMPAH_HARGA_PER_KG` dihapus (harga kini per bank sampah per jenis).
- Env `SEED_BANK_SAMPAH_PASSWORD`/`SEED_BENTOR_PASSWORD`/`SEED_WARGA_PASSWORD` (Prompt A) diganti `SEED_DEMO_PASSWORD`.

**Catatan untuk G (production)**
- Set `APP_LOCALE=id` di Railway.
- Cek isi `transactions` di Supabase sebelum migrate; backup jika ada data.

**Ditunda/dipangkas**: tidak ada.

---

## B2 – Operasional ✅ (2026-10-28) — MENUNGGU REVIEW sebelum C

**Selesai**
- Service: `SetoranService` (jual/donasi, snapshot harga, saldo nasabah dalam `DB::transaction` + `lockForUpdate`),
  `PenarikanService` (saldo dikurangi saat disetujui, cek ulang dalam lock, maks 1 diajukan per nasabah),
  `PenjemputanService` (state machine, transisi tidak sah → 422), `KinerjaService` (agregat tanpa N+1).
- Hitungan uang/berat dalam sen (integer) lewat `App\Support\Uang` agar tidak ada selisih float.
- Policy: `PenjemputanPolicy` (kelola/batal/jalankan), `PenarikanPolicy`, `ArmadaPolicy`; daftar memakai scope `milik()`.
- Endpoint Warga: `GET /warga/saldo`, `GET /warga/setoran`, `GET|POST /warga/penjemputan`, `POST /warga/penjemputan/{id}/batal`,
  `GET|POST /warga/penarikan`.
- Endpoint Bank sampah: `GET /bs/dashboard`, `GET|PUT /bs/harga`, `GET /bs/nasabah`, `GET|POST /bs/setoran`,
  `GET /bs/penjemputan`, `PATCH /bs/penjemputan/{id}`, `GET|POST /bs/armada`, `PATCH /bs/armada/{id}`, `POST /bs/bentor`,
  `GET /bs/penarikan`, `PATCH /bs/penarikan/{id}`, `GET|POST /bs/penjualan-pengepul`.
- Endpoint Bentor: `GET /bentor/tugas`, `PATCH /bentor/tugas/{id}/status`, `PATCH /bentor/armada/status`.
- Endpoint DLH: `GET /dlh/ringkasan`, `GET /dlh/kinerja`, `GET /dlh/kinerja/{id}/tren`.
- Config `filesystems.upload_disk` (env `UPLOAD_DISK`, default `public`) — dipakai foto penjemputan; disk `supabase` di Prompt C.

**File utama**: `app/Services/{Setoran,Penarikan,Penjemputan,Kinerja}Service.php`, `app/Enums/{TipeSetoran,StatusPenjemputan,StatusPenarikan}.php`,
`app/Models/{Nasabah,Setoran,SetoranItem,Penjemputan,Penarikan,PenjualanPengepul}.php`, `app/Policies/*`,
`app/Http/Controllers/Api/{Warga,Bs,Bentor}/*`, `app/Http/Controllers/Api/Dlh/KinerjaController.php`,
`app/Support/{Uang,SqlWaktu}.php`, `routes/api.php`.

**Hasil test**
- `phpunit` SQLite in-memory: 116 lulus.
- `phpunit` terhadap PostgreSQL 17 lokal (Docker): 116 lulus.
- Test wajib Prompt B semua ada: setoran jual menambah saldo sesuai harga bank itu (saldo terpisah per bank); donasi tidak
  menambah saldo; harga berubah tidak mengubah setoran lama; penarikan > saldo ditolak; dua penarikan diajukan ditolak;
  operator bank A tidak bisa melihat/mengubah setoran, penjemputan, penarikan, armada bank B; bentor tidak bisa mengubah
  tugas armada lain; transisi status tidak sah → 422; warga (dan role lain) tidak bisa akses route role lain (`AksesRoleTest`);
  kinerja tanpa N+1 (jumlah query sama untuk 2 dan 7 bank sampah).

**Bentuk respons yang perlu diketahui mobile/web (melengkapi kontrak Prompt 0)**
- `GET /warga/saldo` → `data: {total_saldo, daftar: [{bank_sampah_id, bank_sampah:{id,kode,nama}, saldo, updated_at}]}`.
- `PUT /bs/harga` body `{"harga": [{"jenis_sampah_id", "harga_per_kg"}]}`; `GET /bs/harga` → semua jenis aktif, `harga_per_kg` null jika belum diatur.
- `POST /bs/setoran` → `data: {setoran: {...items}, saldo_sekarang}`.
- `GET /bs/nasabah` tanpa `q` = nasabah bank ini; dengan `q` (min 3 huruf) = semua warga aktif; tiap baris `saldo` & `sudah_nasabah`.
- `GET /bs/armada` → `data: {armada: [...], bentor_tanpa_armada: [...]}`.
- `POST /bs/bentor` boleh sekalian `plat_nomor`, `kapasitas_kg` → `data: {bentor, armada|null}`.
- `GET /bs/dashboard` → `data: {hari_ini, bulan_ini: {jumlah_setoran,total_kg,kg_donasi,total_nilai}, penjemputan: {diajukan,berjalan}, penarikan_diajukan: {jumlah,total}, nasabah: {jumlah,total_saldo}}`.
- `GET /dlh/kinerja` → `data: {dari, sampai, daftar: [{bank_sampah:{id,kode,nama,kecamatan,lat,lng}, total_kg, kg_donasi, nasabah_aktif, nilai_setoran, jemput_selesai, rata2_waktu_jemput_jam|null}]}` urut total_kg.
- `GET /dlh/kinerja/{id}/tren?interval=harian|bulanan` → `data: {bank_sampah, interval, dari, sampai, data: [{periode, total_kg, kg_donasi, nilai_setoran, jumlah_setoran}]}`; periode kosong diisi 0.
- Filter status boleh lebih dari satu dipisah koma (`/bs/penjemputan?status=dijadwalkan,menuju`, `/bentor/tugas?status=`).

**Keputusan kecil (tidak mengubah Prompt 0)**
- Pembatalan warga & penolakan operator hanya saat status `diajukan`.
- Armada → `bertugas` saat bentor `menuju`; kembali `siaga` saat setoran jemput dicatat (jika tidak ada tugas lain berjalan).
- Armada yang sedang `menuju`/`diambil` tidak bisa dinonaktifkan (operator maupun bentor) → 422.
- Menjadwalkan ke armada `nonaktif` atau armada bank lain → 422.
- Donasi boleh untuk jenis yang belum punya harga di bank itu; item donasi menyimpan harga 0.
- Rekening `nasabah` dibuat pada setoran pertama, termasuk donasi.
- Middleware `akun.aktif` & `role` dijalankan sebelum route model binding: role yang salah selalu 403 (tidak bisa menebak ID).
- `/dlh/ringkasan` tanpa `periode`/`dari` = sepanjang waktu; `/dlh/kinerja` default bulan berjalan.
- `nasabah_aktif` = jumlah warga berbeda yang menyetor dalam rentang.

**Ditunda/dipangkas**: tidak ada.

---

## C – Preloved + chat backend ✅ (2026-10-29) — MENUNGGU REVIEW sebelum D

**Selesai**
- Tabel `preloved_items`, `percakapan`, `pesan` (index `percakapan_id,id`), `laporan_preloved`.
- Preloved (warga): `GET /preloved?q=&kategori=&kecamatan=` (hanya tersedia), `GET /preloved/saya`, `GET /preloved/{id}`,
  `POST /preloved` (multipart `foto[]` 1–5, jpg/jpeg/png/webp, maks 2MB), `PATCH /preloved/{id}`, `DELETE /preloved/{id}`
  (file foto ikut dihapus), `POST /preloved/{id}/terjual`, `POST /preloved/{id}/lapor`.
- Chat (warga, polling): `POST /preloved/{id}/chat` (idempoten), `GET /chat`, `GET /chat/{id}/pesan?after_id=` (naik, maks 50),
  `POST /chat/{id}/pesan` (30/menit/user, isi ≤ 1000, tawaran > 0), `POST /chat/{id}/baca`.
- DLH: `GET /dlh/laporan-preloved?status=` (default baru), `PATCH /dlh/preloved/{id}` `{status: disembunyikan|tersedia}`.
- Disk `supabase` (driver s3, `use_path_style_endpoint`) + paket `league/flysystem-aws-s3-v3` (disebut di Prompt C).
  Nama file `Str::uuid()`, DB menyimpan path relatif, resource mengembalikan `Storage::url()`.

**File utama**: `database/migrations/2026_10_29_000001_create_preloved_dan_chat_table.php`,
`app/Models/{PrelovedItem,Percakapan,Pesan,LaporanPreloved}.php`, `app/Http/Controllers/Api/Preloved/{BarangController,ChatController}.php`,
`app/Http/Controllers/Api/Dlh/ModerasiController.php`, `app/Policies/{PrelovedItemPolicy,PercakapanPolicy}.php`, `config/filesystems.php`.

**Hasil test**
- `phpunit` SQLite: 137 lulus. `phpunit` PostgreSQL 17: 137 lulus.
- Test wajib Prompt C: orang ketiga 403 baca/kirim/baca-tandai; penjual tidak bisa chat barang sendiri; `after_id` hanya pesan
  baru; barang terjual/disembunyikan tidak muncul di daftar; hanya pemilik edit/hapus/terjual; DLH bisa menyembunyikan;
  upload non-gambar & > 2MB ditolak. Plus: `GET /chat` tanpa N+1 (jumlah query sama untuk 2 dan 5 percakapan), rate limit 30/menit.
- Disk `supabase` dicek dengan kredensial dummy: adapter S3 terbentuk, URL publik benar (tanpa koneksi ke Supabase).

**Bentuk respons untuk mobile/web**
- Barang: `{id, judul, deskripsi, kategori, kondisi, harga, kecamatan, foto: [url...], status, penjual:{id,name}, milik_saya, created_at, updated_at}`.
- Ganti foto saat ubah: kirim `POST /preloved/{id}` multipart dengan `_method=PATCH`; `foto[]` mengganti SEMUA foto lama.
- Percakapan (`GET /chat`, `POST /preloved/{id}/chat`): `{id, peran_saya: pembeli|penjual, barang:{id,judul,harga,status,foto},
  lawan_bicara:{id,name}, pesan_terakhir: Pesan|null, unread_count, last_message_at}`.
- Pesan: `{id, percakapan_id, pengirim_id, milik_saya, isi|null, tawaran_harga|null, dibaca_at, created_at}`.
- `POST /chat/{id}/baca` → `data: {jumlah}`.

**Keputusan kecil**
- `kategori` teks bebas (maks 50) sesuai Prompt 0; daftar kategori sebaiknya disamakan di dropdown mobile.
- `GET /chat` hanya menampilkan percakapan yang sudah ada pesannya (chat yang dibuka lalu ditinggal tidak muncul).
- Tanpa `after_id`, `GET /chat/{id}/pesan` mengembalikan 50 pesan terakhir (urut naik).
- Chat baru hanya untuk barang tersedia (terjual → 422, disembunyikan → 404); percakapan lama tetap bisa dibuka.
- Kirim pesan ke barang yang disembunyikan DLH → 422.
- Detail barang disembunyikan → 404 untuk selain pemilik/DLH.
- Satu laporan per pelapor per barang; lapor ulang memperbarui alasan.
- Moderasi: sembunyikan → laporan `baru` jadi `ditindak`; tampilkan lagi → laporan `baru` jadi `diabaikan`.
- Hapus barang ikut menghapus percakapan & pesannya (cascade).

**Catatan untuk G**: env `UPLOAD_DISK=supabase` + `SUPABASE_S3_*` (lihat `.env.example`); buat bucket publik `uploads`.

**Ditunda/dipangkas**: tidak ada.

---

## D – Web dashboard DLH ✅ (2026-10-29)

**Selesai**
- Login `POST /auth/login`; role selain `dlh` ditolak dan tokennya langsung dicabut. Token di `sessionStorage`;
  401 dari API mana pun → kembali ke login dengan pesan. Tombol keluar (`POST /auth/logout`).
- `src/services/api.js`: satu `request()` (VITE_API_URL, Bearer, pesan Indonesia 401/403/422/429, `ApiError.pesanField`).
  `src/hooks/useFetch.js`: `{data, loading, error, refetch}`, respons terlambat diabaikan, data lama tetap tampil saat memuat ulang.
- Halaman: Ringkasan, Kinerja (urut kolom, filter periode, klik baris → grafik tren SVG), Peta (warna kinerja/jemput aktif,
  filter kecamatan, legenda bisa dilipat), Kelola Bank Sampah (cari, filter status, tambah/ubah, aktif/nonaktif, buat operator),
  Jenis Sampah (tambah, ubah nama, aktif/nonaktif), Moderasi Preloved (filter status laporan, sembunyikan/tampilkan).
- Skeleton saat memuat, empty state, toast gagal; toast sukses hanya setelah API sukses. Tema gelap/terang dan gaya liquid glass dipertahankan.
- Dihapus: DropPointMonitor, simulator, BentorDispatch, TransactionsPengepul, RecycleMarketplace, FlowchartViewer (alur v1),
  BackendStatusModal, HeroSection, MenuGrid, SpatialMap (diganti `pages/Peta.jsx`), mockData.js, tubabaBankSampah.json, App.css, aset template.
- `frontend/.env.example` (VITE_API_URL); `.env`/`.env.local` di-ignore.
- Backend: `/dlh/kinerja` kini juga berisi `jemput_aktif` per bank (untuk peta), dengan test.

**File utama**: `frontend/src/{App.jsx,menu.js}`, `src/services/api.js`, `src/hooks/useFetch.js`, `src/components/{ui,Toast,Navbar,FilterPeriode,GrafikTren}.jsx`,
`src/pages/{Login,Ringkasan,Kinerja,Peta,BankSampah,JenisSampah,Moderasi}.jsx`, `src/utils/{format,periode}.js`.

**Hasil test**
- `npm run lint`: 0 warning, 0 error. `npm run build`: lolos (JS 427 kB, gzip 131 kB).
- `phpunit` backend: 137 lulus.
- Smoke test alur web ke backend asli (Postgres lokal, data demo + 76 bank impor), meniru panggilan `api.js` dengan header
  Origin `http://localhost:5173`: 15/15 lulus (preflight CORS, login dlh, penolakan & pencabutan token operator, ringkasan,
  kinerja 79 bank berkoordinat, tren 31 titik, cari, tambah, validasi 422 Indonesia, nonaktifkan, buat operator, jenis sampah,
  laporan, 401 token palsu, logout). Data uji smoke dihapus lagi.

**Keputusan**
- Peta memakai `GET /dlh/kinerja` (bukan `/bank-sampah`): satu request tanpa paginasi berisi koordinat + angka kinerja
  + jemput aktif untuk semua bank aktif. Bank nonaktif tidak tampil di peta.
- Warna kinerja: sepertiga atas total kg bulan ini = tinggi, tengah = sedang, bawah = rendah, 0 kg = abu-abu.
- Navigasi pakai `#hash` (tanpa library router); tidak ada library baru.
- Saat ubah bank sampah, lat/lng hanya dikirim jika berubah (agar penanda koordinat estimasi tidak hilang tanpa sengaja).

**Belum diverifikasi (perlu cek manual di browser)**: tampilan visual tiap halaman (gelap/terang, layar HP), interaksi peta
& grafik. Saya tidak punya akses browser di sesi ini; yang diuji adalah build, lint, dan alur API yang dipakai halaman.

**Ditunda/dipangkas**: FlowchartViewer dihapus (opsi di Prompt D), tidak diperbarui ke alur v2.

---

## E – Aplikasi Flutter: kerangka, warga, bank sampah, bentor ✅ (2026-10-29)

**Selesai**
- Proyek `mobile/` (Android saja, `id.tubaba.bank_sampah_tubaba`), Flutter 3.47.7 terpasang (tidak di-upgrade).
- Paket: flutter_riverpod 3, dio, go_router, flutter_secure_storage, flutter_map + latlong2, geolocator, image_picker,
  intl, **url_launcher (disetujui pengguna)**, flutter_localizations (bagian SDK).
- Kerangka: `ApiClient` (API_URL dari dart-define, Bearer, pesan error dari "pesan", 401 → logout otomatis),
  MODE MOCK (`USE_MOCK=true`), splash → GET /me → shell per role, login & daftar warga, tema hijau, Bahasa Indonesia.
- Warga: beranda (total & saldo per bank, setoran terbaru), cari bank (daftar + peta + terdekat via GPS), detail + harga,
  minta jemput (pin peta, default GPS, foto opsional), daftar & batal jemput, tarik saldo + riwayat, akun.
- Bank sampah: dashboard, catat setoran (cari warga → jual/donasi → baris jenis + berat → total realtime → konfirmasi),
  riwayat, jemput per status (jadwalkan armada + waktu / tolak; "Catat Setoran" saat diambil mengisi penjemputan_id),
  armada & tambah akun bentor (+armada), ubah status armada, atur harga, persetujuan penarikan, penjualan pengepul.
- Bentor: daftar tugas, toggle siaga/nonaktif, detail dengan peta, tombol Google Maps & telepon, Menuju → Diambil.
- Android: izin INTERNET & lokasi, `<queries>` untuk https/tel, HTTP polos hanya di manifest debug.

**Backend**: endpoint baru `GET /api/v1/bentor/armada` (armada milik bentor, untuk status toggle) + test.
Tambahan ini di luar kontrak Prompt 0 tapi hanya menambah, tidak mengubah endpoint lain.

**Hasil test**
- `flutter analyze`: No issues found.
- `flutter test`: 13 lulus — redirect login per role (fungsi `arahkan()` + alur login UI warga/operator/bentor/password salah
  melalui mock backend), form setoran (kalkulator: jual, donasi, tanpa harga, presisi 0.1+0.2; widget: total realtime & ganti donasi).
- Uji kontrak `test/kontrak_api_test.dart` terhadap backend Laravel asli (Postgres lokal, data demo): lulus — warga minta
  jemput → operator jadwalkan → bentor menuju/diambil (armada bertugas) → operator catat setoran dengan penjemputan_id
  (saldo bertambah sesuai harga, armada siaga lagi) → warga tarik saldo → operator setujui (saldo berkurang).
- `phpunit` backend: 137 lulus.
- `flutter build apk`: BELUM bisa — lisensi Android SDK belum disetujui (`flutter doctor --android-licenses` harus dijalankan pengguna).

**Keputusan**
- Mock di lapisan HTTP (adapter Dio) alih-alih repository palsu terpisah: satu kode repository/model untuk mock & API asli.
- Daftar panjang memakai `DaftarBerhalaman` (pull-to-refresh + infinite scroll 20/halaman), dipakai ulang di F.
- Uang/berat di form setoran dihitung dalam sen seperti backend agar total di layar sama dengan yang tersimpan.
- Pilihan bank di form jemput/penarikan memuat maks. 100 bank sampah aktif (5 halaman).
- Akun DLH yang login di aplikasi diarahkan ke halaman "gunakan web DLH".

**Belum diverifikasi**: tampilan di HP/emulator sungguhan (layout layar kecil, GPS, kamera, Google Maps, telepon).
Widget test & uji kontrak tidak menjalankan plugin native.

**Ditunda/dipangkas**: tidak ada.

---

## F – Flutter: preloved + chat ✅ (2026-10-28)

**Selesai**
- Tab Preloved: grid barang tersedia, cari, filter kategori & kecamatan, pull-to-refresh, infinite scroll; FAB "Jual Barang".
- Detail: carousel foto, harga, kondisi, kategori, penjual, info COD, "Chat Penjual" (disembunyikan untuk barang sendiri),
  Laporkan; untuk pemilik: tandai terjual, ubah, hapus.
- Jual/ubah barang: judul, deskripsi, kategori, kondisi, harga, kecamatan, foto 1–5 (kamera/galeri, dikompres lebar maks.
  1600 px kualitas 75, ditolak jika masih > 2 MB). Ganti foto saat ubah: POST multipart + `_method=PATCH`. "Barang saya".
- Tab Chat: daftar percakapan (foto barang, lawan bicara, pesan terakhir, badge belum dibaca), polling 15 detik hanya saat
  tab aktif & aplikasi di foreground.
- Ruang chat: header barang + harga + info COD, bubble pesan, input teks, "Tawar Harga" (bubble khusus Rp), polling
  `after_id` tiap 3 detik HANYA saat layar terbuka & foreground (berhenti saat dispose/background), tandai dibaca saat dibuka
  dan saat ada pesan baru, kirim optimistis dengan status mengirim/gagal + kirim ulang/hapus, penjual bisa tandai terjual.
- Mode mock juga mencakup preloved & chat (lawan bicara palsu membalas tawaran agar polling terlihat).

**File utama**: `mobile/lib/features/preloved/{preloved_repository,pengelola_pesan,preloved_tab,barang_pages,chat_pages}.dart`,
`mobile/lib/core/models/preloved.dart`.

**Hasil test**
- `flutter analyze`: No issues found.
- `flutter test`: 23 lulus (+1 uji kontrak dilewati tanpa URL) — tambahan F: polling (`after_id` naik, tidak dobel walau server
  mengirim ulang, kiriman sendiri tidak dobel, optimistis gagal → kirim ulang, urutan pesan baru vs kiriman gagal, tidak ada
  polling ganda bersamaan) dan bubble tawaran (Rp, label lawan/sendiri, rata kiri/kanan, tombol kirim ulang).
- Uji kontrak ke backend asli: 2/2 lulus, termasuk preloved & chat (upload 2 foto multipart sungguhan, penjual tidak bisa chat
  barang sendiri 422, buka chat idempoten, tawaran, `after_id` hanya pesan baru, unread 2 → 0 setelah baca, orang ketiga 403,
  terjual hilang dari daftar, hapus → 404).

**Keputusan**
- Kategori dipilih dari daftar tetap di aplikasi (Pakaian, Elektronik, Perabot, Buku, Mainan, Kerajinan Daur Ulang, Lainnya);
  backend tetap menerima teks bebas.
- Logika polling dipisah ke `PengelolaPesan` (tanpa UI) agar bisa diuji.
- Upload `foto[]` disusun manual di `FormData` (bawaan Dio bisa mengirim key tanpa `[]` sehingga Laravel hanya menerima 1 foto).
- Spinner tab Chat hanya tampil saat tab aktif (sebelumnya berputar terus di latar IndexedStack).

**Belum diverifikasi**: kamera/galeri, kompresi foto, dan tampilan di HP sungguhan. `flutter build apk` masih menunggu
lisensi Android disetujui.

**Ditunda/dipangkas**: tidak ada (urutan pangkas di prompt tidak perlu dipakai).

---

## Perbaikan hasil review keamanan ✅ (2026-10-28)

Review atas saldo/penarikan, isolasi antar bank sampah, dan akses chat: tidak ada celah kritis. Diperbaiki:

1. **Privasi pencarian warga (`GET /bs/nasabah`)** — sebelumnya operator mana pun bisa menelusuri nama, email, HP, dan
   alamat semua warga dengan kata kunci umum. Sekarang: nasabah bank ini dicari sebagian; warga lain HANYA ditemukan dengan
   nomor HP (format 08/62/+62/bertanda hubung) atau email yang persis; alamat hanya dikirim untuk nasabah bank ini.
2. **Nonaktifkan akun** (keputusan pengguna: DLH → operator & bentor; operator → bentor di banknya; warga/DLH tidak):
   `GET /dlh/bank-sampah/{id}/akun`, `PATCH /dlh/akun/{id}/status`, `PATCH /bs/bentor/{id}/status` `{is_aktif}`.
   Nonaktif = semua token dicabut saat itu juga, login ditolak 403; bentor yang sedang menuju/mengambil tidak bisa
   dinonaktifkan; armada bentor ikut nonaktif. `AkunService`, `UserPolicy::kelolaBentor`.
   UI: web DLH (tombol "Akun" di Kelola Bank Sampah), aplikasi operator (menu kartu armada), mock backend.
3. Moderasi: `tersedia` hanya untuk memulihkan barang yang disembunyikan (barang terjual tidak bisa dijual ulang) → 422.
4. Penarikan hanya ke bank sampah aktif (bank nonaktif tidak punya operator untuk memprosesnya).
5. Perbandingan ID di Policy/model/resource di-cast `(int)`.

**Hasil test**: `phpunit` 145 lulus (SQLite & PostgreSQL 17); `npm run lint` 0 masalah, `npm run build` lolos;
`flutter analyze` bersih, `flutter test` 23 lulus; uji kontrak mobile 3/3 lulus dari database demo baru
(`migrate:fresh --seed`), termasuk operator menonaktifkan bentor → token bentor 401, login 403, lalu dipulihkan.

**Dicatat, tidak diubah**: belum ada fitur koreksi setoran/penarikan yang salah input — koreksi manual lewat database
oleh admin dengan pencatatan; fitur koreksi + jejak audit setelah sprint. DLH tidak bisa membaca chat (sesuai desain).

---

## Review keamanan lanjutan ✅ (2026-10-28)

1. **Verifikasi GitHub lengkap**: semua file baru (Dlh/AkunController, AkunService, UserPolicy, UbahStatusAkunRequest, …)
   ter-commit; clone ulang `origin/sprint-v2` ke folder sementara → `composer install` → test lulus.
2. **Metadata foto dibuang**: `App\Support\GambarAman` meng-encode ulang foto dengan GD (JPEG q85, PNG, WebP) ke file
   sementara lalu itu yang disimpan — EXIF/GPS hilang; tag Orientation diterapkan dulu agar foto HP tidak miring.
   Dipakai di upload preloved (tambah & ubah) dan foto penjemputan. Batas 25 megapiksel (cegah bom dekompresi).
   Tanpa GD (JPEG/PNG/WebP) aplikasi gagal saat boot; `ext-gd` wajib di `composer.json`.
   Local: `extension=exif` diaktifkan di php.ini PHP 8.4 (dipakai test & koreksi orientasi; opsional di produksi).
3. **Batas spam**: maks 3 jemput `diajukan`/`dijadwalkan` per warga per bank sampah → 422; ajukan jemput 10/jam per
   warga; pasang barang preloved 20/hari; laporan preloved 20/hari; `GET /bs/nasabah` 60/menit per operator.
4. **Setoran pertama bersamaan**: `SetoranService::bukaRekening()` membuat rekening di savepoint dan menangkap
   `UniqueConstraintViolationException`; transaksi luar tetap sah di PostgreSQL (dibuktikan test; tanpa savepoint test gagal).

**Hasil test**: `phpunit` 157 lulus (SQLite & PostgreSQL 17).

---

## Perbaikan UI hasil uji emulator ✅ (2026-10-28)

Uji manual mode mock di emulator 720x1280 (360 dp, Android 15) untuk warga, operator, bentor.

**Solusi terpusat (`lib/core/widgets.dart`)**
- `paddingAman(context, dasar:, adaFab:)`: padding isi + inset bilah navigasi sistem (`MediaQuery.paddingOf`, sama
  seperti SafeArea; 0 saat keyboard terbuka / di dalam Scaffold ber-bottomNavigationBar). ListView dengan padding
  eksplisit tidak menambah inset sendiri, sehingga di Android 15 (edge-to-edge) tombol terakhir tertutup.
  Dipakai di semua daftar/form berpadding + `DaftarBerhalaman`; `adaFab: true` memberi ruang 88 dp agar item terakhir
  tidak tertutup FAB.
- `tampilkanSheet()`: semua bottom sheet lewat sini (`useSafeArea: true` + `SafeArea(top: false)`).
- `DialogAplikasi`: AlertDialog dengan Batal & aksi utama sejajar di kanan (tema FilledButton lebar penuh dinetralkan).
- Test `tata_letak_test.dart` memindai `lib/`: `showModalBottomSheet`/`AlertDialog` langsung di luar `widgets.dart` = gagal.

**Perbaikan**
1. Dashboard operator: GridView rasio tetap → kisi 2 kolom yang tinggi barisnya mengikuti isi; angka panjang
   mengecil (FittedBox), label boleh turun baris. Tanpa overflow di 360 dp dengan huruf sistem 130%.
2. Tombol tertutup bilah navigasi (Ajukan penjemputan, Simpan jadwal, dll.) → `paddingAman`/`tampilkanSheet`.
   Diperiksa: akun, ganti password, atur harga, tambah bentor, form barang, detail bank, minta jemput, tarik saldo,
   semua `DaftarBerhalaman`, 4 bottom sheet. Catat setoran sudah benar (bilah total ber-SafeArea).
3. Pin hilang setelah "Pakai lokasi saya": kamera peta kini dipindah (`MapController.move`) ke titik GPS.
4. Sheet "Pilih warga" tidak lagi menabrak status bar.
5. `Kosong` bisa digulir → ruang chat kosong + keyboard tidak overflow.
6. Tombol "Catat setoran" di dashboard dihapus; FAB dipertahankan (tampil di Beranda & Setoran).
7. Tombol berlabel "Tawar Harga" di atas kolom pesan.
8. Tab Jemput operator: `tabAlignment: TabAlignment.start`, keempat tab terlihat.
9. Dialog konfirmasi memakai `DialogAplikasi`.
10. "Mencari lokasi…" di atas peta; GPS mati / izin ditolak / izin diblokir / tidak ditemukan → pesan jelas +
    "Buka pengaturan" / "Coba lagi" (`lokasiSaatIni()` kini mengembalikan `HasilLokasi` dengan `MasalahLokasi`).
11. Peta detail tugas bentor zoom 15.
12. Peta di form tidak bisa digeser (hanya ketuk untuk pindah pin; gulir halaman tidak tertahan); tombol
    "Perbesar peta" membuka `PilihLokasiPage` layar penuh (geser/cubit, ketuk, "Pakai lokasi ini").

**Hasil test**: `flutter analyze` bersih; `flutter test` 26 lulus, 3 kontrak dilewati (tanpa URL backend).
Dua test baru (dashboard 360 dp + huruf 130%, chat kosong + keyboard) dipastikan gagal sebelum perbaikan.

**Catatan**: koordinat mock (−4,58; 105,13) berada di area tanpa data OSM, jadi peta tampak polos di zoom 15–17
(tile 103 byte, satu warna) — bukan galat.

**Lanjutan (2026-10-29)** — layar yang belum tercakup: alur bentor sampai "diambil", setoran dari jemput (warga
terkunci, jemput → Selesai, saldo bertambah), atur harga, persetujuan penarikan, penjualan pengepul, tarik saldo,
cari bank (daftar/terdekat/peta), jual barang, barang saya, ganti password. Semua alur berjalan. Diperbaiki:
- `tampilkanSheet` kini menaikkan isi setinggi keyboard dan membuatnya bisa digulir (sheet pengepul overflow 15 px
  saat keyboard terbuka). Inset keyboard per-sheet dihapus; sheet berisi ListView memakai `gulir: false`.
  Test baru memastikan tombol terakhir berada di atas keyboard (gagal tanpa perbaikan).
- `DaftarBerhalaman` kosong/galat: padding sama dengan daftar (kartu header tidak menempel tepi layar) dan
  `AlwaysScrollableScrollPhysics` agar tarik-untuk-segarkan tetap jalan; sama untuk tab Preloved & Chat yang kosong.
- Segmen "Menunggu" di persetujuan penarikan tidak lagi terpotong (`showSelectedIcon: false`).
- Penjualan pengepul: tombol Simpan nonaktif selama Harga/kg kosong (sebelumnya kosong = Rp 0). Mock kini menolak
  berat > 100.000 kg seperti backend.
- `LabelStatus` mengkapitalkan status mentah ("Tersedia", "Siaga"); status penarikan warga "diajukan" → "Menunggu".
- Cari bank: hint "Nama / tiyuh" (tidak terpotong), jarak "1,7 km" (`jarakKm`).

Hasil: `flutter analyze` bersih; `flutter test` 27 lulus, 3 kontrak dilewati.

---

## Penerapan referensi UI HTML (2026-10-29)

Acuan: `Bank Sampah UI.html` yang diberikan pengguna. Desain diterapkan pada kode aplikasi,
bukan mengganti layar dengan iframe/prototipe. Backend, role, tenancy, dan data transaksi tetap dipakai.

- Web DLH: sidebar responsif, login dua panel, palet hijau tua/lime, kartu putih dan latar terang,
  tipografi Plus Jakarta Sans lokal, komponen form/tombol/lencana/tabel konsisten. Tema gelap tetap tersedia.
- Ringkasan: kartu indikator, volume per bank, kontribusi jual/donasi, dan peringkat memakai data API nyata.
  Grafik komposisi jenis sampah dan menu dummy dari referensi tidak ditambahkan tanpa endpoint pendukung.
- Kelola bank sampah: filter status, pemilihan bank, panel detail lokasi/kontak, serta akses ke form dan akun
  operator/bentor yang sudah ada.
- Mobile: tema dan font lokal yang sama, login baru, header per role, kartu hero, aksi cepat, serta navigasi pill
  untuk warga/operator/bentor. Form, penjemputan, saldo, preloved, dan chat tetap menggunakan repository/API lama.
- Font diekstrak dari referensi beserta lisensi SIL OFL; Flutter memakai TTF hasil konversi variable font.

Web diverifikasi dengan `npm run lint`, `npm run build`, pemeriksaan enam halaman, login ke API lokal,
dialog bank sampah, serta layout/menu responsif. Tidak ada perubahan skema atau logika backend pada pekerjaan UI ini.

Verifikasi lanjutan UI:
- Dialog web mengikuti token tema, memiliki nama aksesibel, menahan fokus keyboard di dalam dialog,
  menutup dengan Escape, dan mengembalikan fokus ke pemicunya. Tren kinerja dapat dibuka lewat tombol keyboard.
- Layout web 390 px dan keenam halaman desktop diperiksa tanpa overflow horizontal.
- Navigasi Tugas/Riwayat bentor memuat ulang daftar ketika tab berubah; ditambahkan tes regresi.
- Tes layout operator menggulir melewati hero/aksi cepat sebelum memeriksa kartu penarikan dan nasabah,
  tetap menguji layar 360 dp dengan ukuran teks 130%.
- Status bar login mobile memakai ikon terang di atas latar hijau tua.
- Hasil: `npm run lint` dan `npm run build` lulus; `flutter analyze` bersih; `flutter test` 28 lulus,
  3 tes kontrak dilewati karena perintah pemeriksaan UI tidak memberikan URL backend.

## Ditunda setelah sprint

- **Foto penjemputan ke bucket privat + signed URL.** Saat ini foto penjemputan ada di bucket publik `uploads` (URL acak
  UUID, sulit ditebak tapi tetap publik). Setelah sprint: bucket privat `penjemputan`, resource mengembalikan signed URL
  berumur pendek (mis. 15 menit) hanya untuk warga pemilik, operator bank itu, dan bentor yang ditugaskan. Foto preloved
  tetap publik.
- **Koreksi setoran memakai SETORAN PEMBALIK**, bukan edit/hapus baris. Koreksi = baris setoran baru dengan nilai negatif
  (total_kg & total_nilai minus, item negatif) dan catatan `koreksi setoran #<id>`, dibuat lewat SetoranService dalam lock
  nasabah yang sama, ditolak jika saldo jadi negatif, hanya oleh operator bank itu (atau DLH), dan setoran asal tidak bisa
  dikoreksi dua kali. Riwayat asli tetap utuh sebagai jejak audit. Sampai fitur ini ada: koreksi manual oleh admin DB
  dengan pola yang sama (baris pembalik), dicatat.
- Fitur koreksi penarikan mengikuti pola yang sama (penarikan pembalik).
