<?php

namespace Database\Seeders;

use App\Models\TeksBerjalan;
use Illuminate\Database\Seeder;
use RuntimeException;

/**
 * Teks contoh agar strip di beranda terisi saat demo.
 *
 * Tidak dipanggil otomatis: php artisan db:seed --class=TeksBerjalanDemoSeeder
 *
 * Aman dijalankan ulang.
 */
class TeksBerjalanDemoSeeder extends Seeder
{
    private const TEKS = [
        'Selamat datang di portal Bank Sampah Tubaba, Dinas Lingkungan Hidup Kabupaten Tulang Bawang Barat.',
        'Tabung sampah Anda di bank sampah terdekat, nilainya masuk ke saldo Anda.',
        'Minta penjemputan sampah dan jual barang bekas layak pakai lewat aplikasi warga.',
    ];

    public function run(): void
    {
        if (app()->environment('production')) {
            throw new RuntimeException('Teks contoh tidak boleh dibuat di production.');
        }

        foreach (self::TEKS as $i => $teks) {
            TeksBerjalan::firstOrCreate(['teks' => $teks], ['urutan' => $i + 1]);
        }
    }
}
