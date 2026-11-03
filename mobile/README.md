# Aplikasi Mobile Bank Sampah Tubaba

Flutter (Android) untuk role **warga**, **bank_sampah** (operator), dan **bentor** dalam satu aplikasi.
Akun DLH memakai web dashboard (`frontend/`).

## Menjalankan

```bash
flutter pub get

# Tanpa backend: data palsu di memori (akun warga@demo.id / operator@demo.id / bentor@demo.id, password: password)
flutter run --dart-define=USE_MOCK=true

# Backend lokal (emulator Android: 10.0.2.2 = localhost komputer). Default API_URL sudah ini.
flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1

# HP fisik di Wi-Fi yang sama: pakai IP komputer, mis. http://192.168.1.10:8000/api/v1
```

HTTP polos hanya diizinkan di build **debug**. Build release wajib HTTPS:

```bash
flutter build apk --release --dart-define=API_URL=https://<domain-staging>/api/v1
```

## Struktur

```
lib/
  core/        api client (dio) & mock backend, model, repository, router (go_router + redirect per role),
               tema, format Rupiah/tanggal, peta (flutter_map), daftar berhalaman
  features/
    auth/      splash, login, daftar warga, status login (Riverpod)
    akun/      profil, ganti password, keluar
    warga/     beranda saldo, cari bank (daftar + peta + terdekat), detail & harga, minta jemput, tarik saldo
    bank_sampah/ dashboard, catat setoran (total realtime), jemput (jadwalkan/tolak), bentor & armada,
               harga, persetujuan penarikan, penjualan pengepul
    bentor/    tugas jemput, detail + Google Maps & telepon, status menuju → diambil, siaga/nonaktif
    preloved/  jual-beli barang bekas (grid, filter, foto 1–5), chat polling (after_id, 3 dtk / 15 dtk), tawar harga
```

- Mode mock dipasang di lapisan HTTP (`core/api/mock_backend.dart`), jadi repository & model yang sama dipakai
  untuk mock dan API asli.
- Error API ditampilkan dari field `pesan`; 401 dari endpoint mana pun → logout otomatis.

## Pemeriksaan

```bash
flutter analyze
flutter test

# Uji kontrak ke backend asli berisi data DEMO (jangan ke produksi)
flutter test test/kontrak_api_test.dart \
  --dart-define=KONTRAK_API_URL=http://127.0.0.1:8000/api/v1 \
  --dart-define=KONTRAK_PASSWORD=<SEED_DEMO_PASSWORD>
```
