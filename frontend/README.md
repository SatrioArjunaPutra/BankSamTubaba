# Web Dashboard DLH – Bank Sampah Tubaba

React 19 + Vite + Tailwind v4 + react-leaflet. Hanya untuk akun role `dlh`; operator, bentor, dan warga memakai aplikasi mobile.

## Menjalankan

```bash
npm install
cp .env.example .env.local   # isi VITE_API_URL (contoh: http://localhost:8000/api/v1)
npm run dev                  # http://localhost:5173
```

Backend harus mengizinkan origin web ini di `CORS_ALLOWED_ORIGINS` (default `http://localhost:5173`).
Akun DLH lokal dibuat oleh `php artisan migrate --seed` (lihat `api-backend/README.md`).

## Halaman

| Hash            | Isi                                                                 | Endpoint                                   |
|-----------------|---------------------------------------------------------------------|--------------------------------------------|
| `#ringkasan`    | Kartu angka se-Tubaba, filter periode                               | `GET /dlh/ringkasan`                       |
| `#kinerja`      | Peringkat bank sampah (bisa diurutkan), klik baris → grafik tren   | `GET /dlh/kinerja`, `/dlh/kinerja/{id}/tren` |
| `#peta`         | Titik bank sampah, warna kinerja bulan ini / jemput aktif           | `GET /dlh/kinerja`                         |
| `#bank-sampah`  | Daftar, tambah/ubah, aktif/nonaktif, buat akun operator             | `/dlh/bank-sampah`                         |
| `#jenis-sampah` | Master jenis sampah                                                 | `/dlh/jenis-sampah`                        |
| `#moderasi`     | Laporan preloved, sembunyikan/tampilkan barang                      | `/dlh/laporan-preloved`, `/dlh/preloved/{id}` |

## Struktur

- `src/services/api.js` – satu fungsi `request()`: base URL dari `VITE_API_URL`, token Bearer di `sessionStorage`,
  pesan Indonesia untuk 401/403/422/429; 401 memicu kembali ke halaman login.
- `src/hooks/useFetch.js` – `{ data, loading, error, refetch }`.
- `src/components/ui.jsx` – kartu, tombol, form, skeleton, empty state, modal, paginasi. Toast di `Toast.jsx`
  (toast sukses hanya setelah API membalas sukses).
- Grafik tren memakai SVG sendiri (`GrafikTren.jsx`), tanpa library grafik.

## Pemeriksaan

```bash
npm run lint
npm run build
```
