<?php

namespace Database\Seeders;

use App\Enums\StatusBerita;
use App\Models\Berita;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

/**
 * Artikel contoh agar bagian berita di beranda terisi saat demo. Judulnya
 * berawalan "Contoh:" supaya tidak tertukar dengan berita asli.
 *
 * Tidak dipanggil otomatis: php artisan db:seed --class=BeritaDemoSeeder
 *
 * Aman dijalankan ulang.
 */
class BeritaDemoSeeder extends Seeder
{
    private const ARTIKEL = [
        ['judul' => 'Contoh: Warga dapat meminta penjemputan sampah lewat aplikasi', 'kategori' => 'kegiatan', 'gambar' => 'layanan-jemput',
            'ringkasan' => 'Warga mengajukan penjemputan dari aplikasi, lalu bank sampah menjadwalkan bentor untuk datang ke alamat warga.'],
        ['judul' => 'Contoh: Cara menabung sampah di bank sampah terdekat', 'kategori' => 'berita', 'gambar' => 'layanan-tabungan',
            'ringkasan' => 'Sampah ditimbang dan nilainya masuk ke saldo warga. Saldo dapat ditarik dengan mengajukan penarikan.'],
        ['judul' => 'Contoh: Donasi sampah tetap tercatat dalam kinerja bank sampah', 'kategori' => 'pengumuman', 'gambar' => 'layanan-donasi',
            'ringkasan' => 'Sampah dapat didonasikan tanpa menambah saldo, dan beratnya tetap dihitung dalam kinerja bank sampah.'],
        ['judul' => 'Contoh: Barang bekas layak pakai bisa dijual lewat aplikasi warga', 'kategori' => 'berita', 'gambar' => 'layanan-preloved',
            'ringkasan' => 'Warga dapat memasang barang bekas layak pakai, berbincang lewat chat, dan bertransaksi secara COD.'],
    ];

    public function run(): void
    {
        if (app()->environment('production')) {
            throw new RuntimeException('Artikel contoh tidak boleh dibuat di production.');
        }

        foreach (self::ARTIKEL as $i => $data) {
            $berita = Berita::firstOrNew(['judul' => $data['judul']]);
            $berita->fill([
                'ringkasan' => $data['ringkasan'],
                'kategori' => $data['kategori'],
                'isi' => $data['ringkasan']."\n\n> Ini contoh kutipan. Tulis dengan tanda lebih besar dan spasi di awal baris.\n\n## Contoh subjudul\n\nIni artikel contoh untuk melihat tampilan berita. Ganti atau hapus artikel ini dari menu Berita di panel DLH.",
            ]);

            if (! $berita->exists) {
                $berita->status = StatusBerita::Terbit;
                $berita->diterbitkan_at = now()->subDays($i);
                $berita->foto_path = $this->salinGambar($data['gambar']);
            }

            $berita->save();
        }
    }

    private function salinGambar(string $nama): ?string
    {
        $sumber = base_path("../frontend/public/beranda/{$nama}.webp");

        if (! File::exists($sumber)) {
            return null;
        }

        $tujuan = "berita/contoh-{$nama}.webp";
        Storage::disk(config('filesystems.upload_disk'))->put($tujuan, File::get($sumber));

        return $tujuan;
    }
}
