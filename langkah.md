# Panduan Menjalankan Smart Bank Sampah Tubaba

Dokumen ini berisi panduan lengkap langkah demi langkah untuk menjalankan aplikasi **Website (Dashboard DLH)** dan **Aplikasi Mobile (Flutter di HP Realme fisik)** pada lingkungan komputer ini.

---

## DAFTAR ISI
1. [Cara Menjalankan Website (Dashboard Web DLH)](#1-cara-menjalankan-website-dashboard-web-dlh)
2. [Prasyarat Sekali Pakai untuk Android / Flutter](#2-prasyarat-sekali-pakai-untuk-android--flutter)
3. [Cara Menjalankan Aplikasi Mobile di HP Realme](#3-cara-menjalankan-aplikasi-mobile-di-hp-realme)
4. [Daftar Akun Demo untuk Pengujian](#4-daftar-akun-demo-untuk-pengujian)
5. [Troubleshooting & Solusi Kendala Umum](#5-troubleshooting--solusi-kendala-umum)

---

## 1. Cara Menjalankan Website (Dashboard Web DLH)

Website dashboard DLH membutuhkan **Backend (Laravel API)** dan **Frontend (React Vite)** berjalan bersamaan di dua terminal terpisah.

### Langkah A: Jalankan Backend Laravel (Terminal 1)
> **Penting:** Laptop ini memiliki PHP 8.3 dan PHP 8.4. Karena dependensi Laravel proyek ini membutuhkan PHP 8.4+, jalankan perintah berikut di PowerShell agar terminal menggunakan PHP 8.4:

```powershell
cd "C:\KULIAH\SEMESTER 7\CD\backend-bank-sampah\api-backend"
$env:PATH = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe;" + $env:PATH
php artisan serve
```
*Tunggu hingga muncul pesan:*  
`INFO Server running on [http://127.0.0.1:8000].`  
*(Biarkan terminal ini tetap terbuka).*

---

### Langkah B: Jalankan Frontend Dashboard (Terminal 2)
Buka terminal baru di VS Code / PowerShell, lalu jalankan:

```powershell
cd "C:\KULIAH\SEMESTER 7\CD\backend-bank-sampah\frontend"
npm run dev
```
*Tunggu hingga muncul link:*  
`➜ Local: http://localhost:5173/`

---

### Langkah C: Buka di Browser & Login
1. Buka browser ke alamat: **http://localhost:5173**
2. Masuk menggunakan akun DLH:
   * **Email dinas:** `dlh@banksampah.test`
   * **Kata sandi:** `password`
3. Anda akan masuk ke halaman pemantauan bank sampah, peta tiyuh Tubaba, grafik kinerja, dan moderasi preloved.

---

## 2. Prasyarat Sekali Pakai untuk Android / Flutter

*(Hanya perlu dilakukan jika `flutter doctor` masih menampilkan tanda silang pada Android Toolchain / Android SDK).*

1. **Pasang Android Studio:**
   * Unduh dan instal dari [developer.android.com/studio](https://developer.android.com/studio).
   * Buka Android Studio dan selesaikan **Setup Wizard** pertama kali agar SDK otomatis terunduh ke `%LOCALAPPDATA%\Android\Sdk`.
2. **Pasang Android SDK Command-line Tools:**
   * Di Android Studio, buka menu **Settings / More Actions > SDK Manager**.
   * Buka tab **SDK Tools**, lalu beri centang pada:
     * **Android SDK Command-line Tools (latest)** *(Wajib untuk Flutter)*
     * **Android SDK Platform-Tools**
   * Klik **Apply** lalu **OK**.
3. **Setujui Lisensi Android:**
   Buka terminal PowerShell dan jalankan:
   ```powershell
   flutter doctor --android-licenses
   ```
   *Ketik `y` lalu Enter untuk semua pertanyaan persetujuan.*

---

## 3. Cara Menjalankan Aplikasi Mobile di HP Realme

### Langkah A: Siapkan HP Realme
1. Hubungkan HP Realme ke laptop menggunakan **kabel data** (pastikan kabel mendukung transfer data, bukan hanya pengisian daya).
2. Di layar HP Realme:
   * Masuk ke **Pengaturan > Opsi Pengembang**.
   * Aktifkan **Debugging USB** dan **Nonaktifkan pemantauan izin**.
   * Tarik notifikasi atas, ubah mode USB ke **Transfer Foto (PTP)** atau **Transfer File (MTP)**.
   * Saat muncul pop-up izin *"Izinkan Debugging USB dari komputer ini?"*, centang **Selalu izinkan** lalu klik **OK / Izinkan**.
3. Pastikan perangkat terdeteksi di laptop:
   ```powershell
   adb devices
   ```
   *(Harus muncul serial number dengan status `device`, contoh: `YPAYZTUSGYA6AYG6 device`).*

---

### Langkah B: Hubungkan Port API ke HP Realme (ADB Reverse)
Karena aplikasi berjalan di HP fisik Realme, HP harus bisa menjangkau server Laravel laptop. Jalankan perintah ini di PowerShell:

```powershell
adb reverse tcp:8000 tcp:8000
```
*(Perintah ini meneruskan port 8000 HP langsung ke port 8000 laptop via kabel USB).*

---

### Langkah C: Menjalankan / Menguji Aplikasi

Pilih salah satu cara berikut tergantung kebutuhan:

#### Cara 1: Langsung Buka dari HP (Paling Cepat — Tanpa Build Ulang)
Jika aplikasi sudah terpasang di HP dan Anda **tidak mengubah kode**, Anda tidak perlu menjalankan `flutter run` lagi:
1. Pastikan backend Laravel di laptop tetap aktif di port 8000.
2. Colokkan kabel USB HP ke laptop, lalu jalankan satu perintah ini di terminal:
   ```powershell
   adb reverse tcp:8000 tcp:8000
   ```
3. **Langsung buka ikon aplikasi "Bank Sampah Tubaba" di layar HP Realme Anda.** Aplikasi langsung siap digunakan untuk login, setor sampah, dan mencoba fitur lainnya.

#### Cara 2: Lewat Terminal (Jika Mengubah Kode / Butuh Debug)
Jika Anda sedang **mengembangkan aplikasi atau mengubah kode**, jalankan via terminal untuk memanfaatkan fitur *Hot Reload* dan melihat catatan log:
```powershell
cd "C:\KULIAH\SEMESTER 7\CD\backend-bank-sampah\mobile"
flutter run --dart-define=API_URL=http://localhost:8000/api/v1
```
*(Selama terminal aktif, tekan tombol `r` di keyboard untuk reload perubahan kode secara instan, atau tekan `q` untuk keluar).*

---

## 4. Daftar Akun Demo untuk Pengujian

Semua akun demo menggunakan kata sandi yang sama: **`password`**

| Role | Email | Catatan |
|---|---|---|
| **DLH (Pengawas)** | `dlh@banksampah.test` | Akses web dashboard, pantau seluruh bank sampah Tubaba |
| **Bank Sampah (Operator 1)** | `operator1@banksampah.test` | Bank Sampah Demo Panaragan (Kec. Tulang Bawang Tengah) |
| **Bank Sampah (Operator 2)** | `operator2@banksampah.test` | Bank Sampah Demo Daya Murni (Kec. Tumijajar) |
| **Bank Sampah (Operator 3)** | `operator3@banksampah.test` | Bank Sampah Demo Gunung Agung (Kec. Gunung Agung) |
| **Bentor (Driver Jemput 1A)** | `bentor1a@banksampah.test` | Armada penjemputan wilayah Panaragan |
| **Bentor (Driver Jemput 1B)** | `bentor1b@banksampah.test` | Armada penjemputan wilayah Panaragan |
| **Warga 1 - 5** | `warga1@banksampah.test` s/d `warga5@banksampah.test` | Pengguna mobile untuk setor, jemput, & preloved |

---

## 5. Troubleshooting & Solusi Kendala Umum

### 1. Pesan "Tidak dapat terhubung ke server" di Web Dashboard
* **Penyebab 1:** Backend Laravel di port 8000 belum menyala.  
  *Solusi:* Jalankan backend di Terminal 1 sesuai [Langkah 1A](#langkah-a-jalankan-backend-laravel-terminal-1).
* **Penyebab 2:** File `frontend/.env` tidak memiliki port 8000.  
  *Solusi:* Pastikan isi file `frontend/.env` adalah:  
  `VITE_API_URL=http://localhost:8000/api/v1`

### 2. Error Composer Platform Check (`PHP version ">= 8.4.1". You are running 8.3.36`)
* **Penyebab:** Perintah `php` memanggil PHP 8.3 bawaan Windows.  
* **Solusi:** Jalankan perintah set environment PATH PHP 8.4 sebelum `artisan serve`:  
  `$env:PATH = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe;" + $env:PATH`

### 3. HP Realme Tidak Terdeteksi (`No devices found` di adb)
* **Penyebab 1:** Kabel hanya kabel charger daya (tanpa pin data).  
  *Solusi:* Cek di Windows Device Manager. Jika tidak ada kategori `Portable Devices`, ganti dengan kabel data bawaan HP.
* **Penyebab 2:** Mode koneksi USB memblokir ADB.  
  *Solusi:* Ubah mode koneksi dari *Transfer File* ke *Transfer Foto (PTP)* atau *MIDI* di notifikasi HP Realme.

### 4. Aplikasi di HP Realme Tidak Bisa Login / Koneksi Timeout
* **Penyebab:** HP fisik tidak bisa mengenali `localhost` laptop secara otomatis.  
* **Solusi:** Pastikan kabel USB tetap terhubung dan jalankan perintah:  
  `adb reverse tcp:8000 tcp:8000`

