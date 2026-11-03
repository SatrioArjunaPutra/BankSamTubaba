<?php

namespace App\Console\Commands;

use App\Models\BankSampah;
use App\Support\KoordinatParser;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Import daftar bank sampah dari CSV formulir DLH (pemisah ';').
 *
 * Hanya kolom nama, tiyuh, kecamatan, alamat, dan koordinat yang dibaca.
 * No HP ketua, link Google Drive, dan kolom lain sengaja TIDAK dibaca.
 * Kode BS-TUBABA-xx mengikuti nomor baris data (sama dengan parseTubaba.js),
 * jadi jangan mengubah urutan baris CSV di antara dua import.
 */
class ImportBankSampah extends Command
{
    protected $signature = 'banksampah:import {csv : Path file CSV}';

    protected $description = 'Import/perbarui data bank sampah dari CSV DLH (idempoten berdasarkan kode)';

    private const KOLOM_NAMA = 1;

    private const KOLOM_TIYUH = 2;

    private const KOLOM_KECAMATAN = 3;

    private const KOLOM_ALAMAT = 8;

    private const KOLOM_KOORDINAT = 9;

    // Titik di formulir keliru dan sudah dikoreksi. Nama ikut dicek agar tidak salah baris bila urutan CSV berubah.
    private const KOREKSI_KOORDINAT = [
        'BS-TUBABA-01' => ['nama' => 'anggrek', 'lat' => -4.2044374, 'lng' => 105.2030875],
        'BS-TUBABA-66' => ['nama' => 'randu indah', 'lat' => -4.3299, 'lng' => 105.228],
        'BS-TUBABA-71' => ['nama' => 'sinar harapan', 'lat' => -4.4069668, 'lng' => 105.1731042],
    ];

    public function handle(): int
    {
        $path = $this->argument('csv');

        if (! is_file($path) || ! is_readable($path)) {
            $this->error("File tidak ditemukan atau tidak bisa dibaca: {$path}");

            return self::FAILURE;
        }

        $handle = fopen($path, 'r');
        fgetcsv($handle, null, ';', '"', ''); // header

        $hitung = ['dibuat' => 0, 'diperbarui' => 0, 'dilewati' => 0, 'tanpa_koordinat' => 0, 'koordinat_estimasi' => 0];
        $nomorBaris = 0;

        DB::transaction(function () use ($handle, &$hitung, &$nomorBaris) {
            while (($kolom = fgetcsv($handle, null, ';', '"', '')) !== false) {
                $nomorBaris++;
                $nama = trim((string) ($kolom[self::KOLOM_NAMA] ?? ''));

                if ($nama === '') {
                    $hitung['dilewati']++;

                    continue;
                }

                $tiyuh = trim((string) ($kolom[self::KOLOM_TIYUH] ?? ''));
                $kecamatan = Str::title(Str::lower(trim((string) ($kolom[self::KOLOM_KECAMATAN] ?? ''))));
                $alamat = trim((string) ($kolom[self::KOLOM_ALAMAT] ?? '')) ?: "{$tiyuh}, Kec. {$kecamatan}";
                $kode = 'BS-TUBABA-'.str_pad((string) $nomorBaris, 2, '0', STR_PAD_LEFT);

                $koreksi = self::KOREKSI_KOORDINAT[$kode] ?? null;
                $koordinat = $koreksi && Str::contains($nama, $koreksi['nama'], ignoreCase: true)
                    ? ['lat' => $koreksi['lat'], 'lng' => $koreksi['lng'], 'estimasi' => false]
                    : KoordinatParser::parse($kolom[self::KOLOM_KOORDINAT] ?? null, $kecamatan, $kode);

                if (! $koordinat) {
                    $hitung['tanpa_koordinat']++;
                } elseif ($koordinat['estimasi']) {
                    $hitung['koordinat_estimasi']++;
                }

                $bankSampah = BankSampah::updateOrCreate(['kode' => $kode], [
                    'nama' => $nama,
                    'tiyuh' => $tiyuh,
                    'kecamatan' => $kecamatan,
                    'alamat' => Str::limit($alamat, 250, ''),
                    'lat' => $koordinat['lat'] ?? null,
                    'lng' => $koordinat['lng'] ?? null,
                    'koordinat_estimasi' => $koordinat['estimasi'] ?? false,
                ]);

                $hitung[$bankSampah->wasRecentlyCreated ? 'dibuat' : 'diperbarui']++;
            }
        });

        fclose($handle);

        $this->info('Import selesai.');
        $this->table(['Dibuat', 'Diperbarui', 'Baris kosong dilewati', 'Koordinat estimasi', 'Tanpa koordinat'], [[
            $hitung['dibuat'], $hitung['diperbarui'], $hitung['dilewati'], $hitung['koordinat_estimasi'], $hitung['tanpa_koordinat'],
        ]]);

        return self::SUCCESS;
    }
}
