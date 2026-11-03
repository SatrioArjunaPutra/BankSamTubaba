# Konteks Proyek Bank Sampah Tubaba

> Detail tugas per tahap ada di docs/prompt-bank-sampah-v2.md

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
  POST /auth/login               email, password, device_name?, role? (403 bila tidak cocok dgn role akun) → data.user, data.token, data.expires_at
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
