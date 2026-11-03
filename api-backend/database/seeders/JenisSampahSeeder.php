<?php

namespace Database\Seeders;

use App\Models\JenisSampah;
use Illuminate\Database\Seeder;

/**
 * Master jenis sampah default. Aman dijalankan ulang dan dipakai juga di
 * production (jenis yang sudah ada tidak diubah).
 */
class JenisSampahSeeder extends Seeder
{
    public const DEFAULT = ['Plastik', 'Kardus', 'Kertas', 'Logam', 'Botol Kaca', 'Minyak Jelantah'];

    public function run(): void
    {
        foreach (self::DEFAULT as $nama) {
            JenisSampah::firstOrCreate(['nama' => $nama], ['satuan' => 'kg', 'is_aktif' => true]);
        }
    }
}
