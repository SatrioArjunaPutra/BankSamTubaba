<?php

namespace Database\Seeders;

use App\Models\BankSampah;
use App\Models\JenisSampah;
use App\Models\User;
use App\Services\SetoranService;
use Illuminate\Database\Seeder;
use Ramsey\Uuid\Uuid;
use RuntimeException;

/**
 * Setoran contoh bulan berjalan agar warna keaktifan peta DLH terlihat saat
 * demo: 3 bank BS-DEMO mewakili tingkat tinggi, sedang, dan rendah. Bank
 * registri tidak disentuh. Saldo warga demo ikut bertambah untuk tipe jual.
 *
 * Tidak dipanggil otomatis; jalankan setelah DemoSeeder:
 *   php artisan db:seed --class=AktivitasPetaDemoSeeder
 *
 * Aman dijalankan ulang dalam bulan yang sama. Jalankan lagi di bulan
 * berikutnya karena peta hanya menghitung setoran bulan berjalan.
 */
class AktivitasPetaDemoSeeder extends Seeder
{
    /** Total kg bulan ini per bank. */
    private const TARGET_KG = ['BS-DEMO-01' => 640, 'BS-DEMO-02' => 240, 'BS-DEMO-03' => 45];

    // Satu setoran per baris; baris terakhir donasi agar kg_donasi ikut terisi
    private const RINCIAN = [
        ['warga' => 1, 'tipe' => 'jual', 'jenis' => 'Plastik'],
        ['warga' => 2, 'tipe' => 'jual', 'jenis' => 'Kardus'],
        ['warga' => 3, 'tipe' => 'jual', 'jenis' => 'Kertas'],
        ['warga' => 4, 'tipe' => 'donasi', 'jenis' => 'Logam'],
    ];

    public function run(SetoranService $setoran): void
    {
        if (app()->environment('production')) {
            throw new RuntimeException('AktivitasPetaDemoSeeder tidak boleh dijalankan di production.');
        }

        $bulan = now()->format('Y-m');

        foreach (array_keys(self::TARGET_KG) as $i => $kode) {
            $no = $i + 1;
            $bank = BankSampah::where('kode', $kode)->first();
            $operator = User::where('email', "operator{$no}@banksampah.test")->first();

            if (! $bank || ! $operator || $operator->bank_sampah_id !== $bank->id) {
                throw new RuntimeException("Data {$kode} belum lengkap. Jalankan DemoSeeder lebih dulu.");
            }

            foreach (self::RINCIAN as $j => $baris) {
                $setoran->catat($operator, [
                    'warga_id' => User::where('email', "warga{$baris['warga']}@banksampah.test")->firstOrFail()->id,
                    'tipe' => $baris['tipe'],
                    'items' => [[
                        'jenis_sampah_id' => JenisSampah::where('nama', $baris['jenis'])->firstOrFail()->id,
                        'berat_kg' => self::TARGET_KG[$kode] / count(self::RINCIAN),
                    ]],
                    'catatan' => 'Data demo peta',
                    // Tetap per bulan: dijalankan ulang tidak menggandakan setoran dan saldo
                    'request_id' => Uuid::uuid5(Uuid::NAMESPACE_URL, "banksampah/demo-peta/{$bulan}/{$kode}/{$j}")->toString(),
                ]);
            }
        }

        $this->command?->info("  Setoran demo peta untuk {$bulan} siap.");
    }
}
