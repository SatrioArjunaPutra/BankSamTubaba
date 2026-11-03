<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BankSampahController;
use App\Http\Controllers\Api\Bentor;
use App\Http\Controllers\Api\BeritaController;
use App\Http\Controllers\Api\Bs;
use App\Http\Controllers\Api\Dlh;
use App\Http\Controllers\Api\JenisSampahController;
use App\Http\Controllers\Api\Preloved;
use App\Http\Controllers\Api\ProfilController;
use App\Http\Controllers\Api\SensorController;
use App\Http\Controllers\Api\StatistikPublikController;
use App\Http\Controllers\Api\TeksBerjalanController;
use App\Http\Controllers\Api\Warga;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json(['status' => 'sukses', 'pesan' => 'API aktif']));

// --- PERANGKAT IoT (ditunda, aktif hanya jika FITUR_IOT=true) ---
// Tetap di /api/sensor (bukan /api/v1) karena alamat ini tertanam di firmware perangkat.
if (config('banksampah.fitur_iot')) {
    // Autentikasi dulu (percobaan gagal dibatasi per IP), baru kuota per perangkat
    Route::post('/sensor', [SensorController::class, 'store'])->middleware(['device.auth', 'throttle:sensor']);
    Route::get('/sensor', [SensorController::class, 'index'])->middleware(['auth:sanctum', 'akun.aktif']);
}

Route::prefix('v1')->group(function () {
    // --- AREA PUBLIK ---
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:register');
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:login');
    Route::get('/pendaftaran/bank-terdekat', [BankSampahController::class, 'terdekatPublik'])->middleware('throttle:etalase');
    Route::get('/etalase-preloved', Preloved\EtalaseController::class)->middleware('throttle:etalase');
    Route::get('/statistik-publik', StatistikPublikController::class)->middleware('throttle:etalase');
    Route::get('/teks-berjalan', TeksBerjalanController::class)->middleware('throttle:etalase');
    Route::get('/berita', [BeritaController::class, 'index'])->middleware('throttle:etalase');
    Route::get('/berita/{berita}', [BeritaController::class, 'show'])->whereNumber('berita')->middleware('throttle:etalase');

    // --- AREA PRIVAT (wajib token login & akun aktif) ---
    Route::middleware(['auth:sanctum', 'akun.aktif'])->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/me', [ProfilController::class, 'show']);
        Route::patch('/me', [ProfilController::class, 'update']);
        Route::put('/me/password', [ProfilController::class, 'ubahPassword']);

        // Umum
        Route::get('/bank-sampah', [BankSampahController::class, 'index']);
        Route::get('/bank-sampah/nearby', [BankSampahController::class, 'terdekat']);
        Route::get('/bank-sampah/{bankSampah}', [BankSampahController::class, 'show'])->whereNumber('bankSampah');
        Route::get('/jenis-sampah', [JenisSampahController::class, 'index']);

        // Warga
        Route::prefix('warga')->middleware('role:warga')->group(function () {
            Route::get('/saldo', [Warga\SaldoController::class, 'index']);
            Route::get('/setoran', [Warga\SetoranController::class, 'index']);
            Route::get('/penjemputan', [Warga\PenjemputanController::class, 'index']);
            Route::post('/penjemputan', [Warga\PenjemputanController::class, 'store'])->middleware('throttle:jemput');
            Route::post('/penjemputan/{penjemputan}/batal', [Warga\PenjemputanController::class, 'batal']);
            Route::get('/penarikan', [Warga\PenarikanController::class, 'index']);
            Route::post('/penarikan', [Warga\PenarikanController::class, 'store']);
        });

        // Preloved & chat (warga). Ubah barang dengan foto baru: POST multipart + _method=PATCH
        Route::middleware('role:warga')->group(function () {
            Route::get('/preloved', [Preloved\BarangController::class, 'index']);
            Route::get('/preloved/saya', [Preloved\BarangController::class, 'saya']);
            Route::post('/preloved', [Preloved\BarangController::class, 'store'])->middleware('throttle:preloved-pasang');
            Route::get('/preloved/{prelovedItem}', [Preloved\BarangController::class, 'show'])->whereNumber('prelovedItem');
            Route::patch('/preloved/{prelovedItem}', [Preloved\BarangController::class, 'update']);
            Route::delete('/preloved/{prelovedItem}', [Preloved\BarangController::class, 'destroy']);
            Route::post('/preloved/{prelovedItem}/terjual', [Preloved\BarangController::class, 'terjual']);
            Route::post('/preloved/{prelovedItem}/lapor', [Preloved\BarangController::class, 'lapor'])->middleware('throttle:preloved-lapor');
            Route::post('/preloved/{prelovedItem}/chat', [Preloved\ChatController::class, 'buka']);

            Route::get('/chat', [Preloved\ChatController::class, 'index']);
            Route::get('/chat/{percakapan}/pesan', [Preloved\ChatController::class, 'pesan']);
            Route::post('/chat/{percakapan}/pesan', [Preloved\ChatController::class, 'kirim'])->middleware('throttle:pesan');
            Route::post('/chat/{percakapan}/baca', [Preloved\ChatController::class, 'baca']);
        });

        // Bank sampah (operator) — data dibatasi ke bank miliknya
        Route::prefix('bs')->middleware('role:bank_sampah')->group(function () {
            Route::get('/dashboard', Bs\DashboardController::class);
            Route::get('/harga', [Bs\HargaController::class, 'index']);
            Route::put('/harga', [Bs\HargaController::class, 'update']);
            Route::get('/nasabah', [Bs\NasabahController::class, 'index'])->middleware('throttle:cari-nasabah');
            Route::get('/setoran', [Bs\SetoranController::class, 'index']);
            Route::post('/setoran', [Bs\SetoranController::class, 'store']);
            Route::post('/setoran/{setoran}/batal', [Bs\SetoranController::class, 'batal'])->whereNumber('setoran');
            Route::get('/penjemputan', [Bs\PenjemputanController::class, 'index']);
            Route::patch('/penjemputan/{penjemputan}', [Bs\PenjemputanController::class, 'update']);
            Route::get('/armada', [Bs\ArmadaController::class, 'index']);
            Route::post('/armada', [Bs\ArmadaController::class, 'store']);
            Route::patch('/armada/{armada}', [Bs\ArmadaController::class, 'update']);
            Route::post('/bentor', [Bs\ArmadaController::class, 'buatBentor']);
            Route::patch('/bentor/{user}/status', [Bs\ArmadaController::class, 'ubahStatusBentor']);
            Route::get('/penarikan', [Bs\PenarikanController::class, 'index']);
            Route::patch('/penarikan/{penarikan}', [Bs\PenarikanController::class, 'update']);
            Route::get('/penjualan-pengepul', [Bs\PenjualanPengepulController::class, 'index']);
            Route::post('/penjualan-pengepul', [Bs\PenjualanPengepulController::class, 'store']);
        });

        // Bentor
        Route::prefix('bentor')->middleware('role:bentor')->group(function () {
            Route::get('/tugas', [Bentor\TugasController::class, 'index']);
            Route::patch('/tugas/{penjemputan}/status', [Bentor\TugasController::class, 'ubahStatus']);
            Route::post('/tugas/{penjemputan}/setoran', [Bentor\TugasController::class, 'catatSetoran']);
            Route::get('/armada', [Bentor\ArmadaController::class, 'show']);
            Route::patch('/armada/status', [Bentor\ArmadaController::class, 'ubahStatus'])->name('bentor.armada.status');
        });

        // DLH
        Route::prefix('dlh')->middleware('role:dlh')->group(function () {
            Route::get('/peta', Dlh\PetaController::class);
            Route::get('/dashboard', [Dlh\PantauanController::class, 'dashboard']);
            Route::get('/warga', [Dlh\PantauanController::class, 'warga']);
            Route::get('/bentor', [Dlh\PantauanController::class, 'bentor']);
            Route::get('/transaksi', [Dlh\PantauanController::class, 'transaksi']);
            Route::get('/donasi', [Dlh\PantauanController::class, 'donasi']);
            Route::get('/ringkasan', [Dlh\KinerjaController::class, 'ringkasan']);
            Route::get('/kinerja', [Dlh\KinerjaController::class, 'index']);
            Route::get('/kinerja/{bankSampah}/tren', [Dlh\KinerjaController::class, 'tren']);
            Route::get('/preloved', [Dlh\ModerasiController::class, 'index']);
            Route::get('/laporan-preloved', [Dlh\ModerasiController::class, 'laporan']);
            Route::patch('/preloved/{prelovedItem}', [Dlh\ModerasiController::class, 'ubahStatus']);
            Route::delete('/preloved/{prelovedItem}', [Dlh\ModerasiController::class, 'destroy']);

            Route::get('/bank-sampah', [Dlh\BankSampahController::class, 'index']);
            Route::post('/bank-sampah', [Dlh\BankSampahController::class, 'store']);
            Route::patch('/bank-sampah/{bankSampah}', [Dlh\BankSampahController::class, 'update']);
            Route::post('/bank-sampah/{bankSampah}/operator', [Dlh\BankSampahController::class, 'buatOperator']);
            Route::get('/bank-sampah/{bankSampah}/akun', [Dlh\AkunController::class, 'index']);
            Route::patch('/akun/{user}/status', [Dlh\AkunController::class, 'ubahStatus']);

            Route::get('/jenis-sampah', [Dlh\JenisSampahController::class, 'index']);
            Route::post('/jenis-sampah', [Dlh\JenisSampahController::class, 'store']);
            Route::patch('/jenis-sampah/{jenisSampah}', [Dlh\JenisSampahController::class, 'update']);

            Route::get('/berita', [Dlh\BeritaController::class, 'index']);
            Route::post('/berita', [Dlh\BeritaController::class, 'store']);
            Route::patch('/berita/{berita}', [Dlh\BeritaController::class, 'update'])->whereNumber('berita');
            Route::delete('/berita/{berita}', [Dlh\BeritaController::class, 'destroy'])->whereNumber('berita');

            Route::get('/teks-berjalan', [Dlh\TeksBerjalanController::class, 'index']);
            Route::post('/teks-berjalan', [Dlh\TeksBerjalanController::class, 'store']);
            Route::patch('/teks-berjalan/{teksBerjalan}', [Dlh\TeksBerjalanController::class, 'update'])->whereNumber('teksBerjalan');
            Route::delete('/teks-berjalan/{teksBerjalan}', [Dlh\TeksBerjalanController::class, 'destroy'])->whereNumber('teksBerjalan');
        });
    });
});
