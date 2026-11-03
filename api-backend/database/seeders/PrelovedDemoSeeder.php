<?php

namespace Database\Seeders;

use App\Enums\StatusPreloved;
use App\Models\PrelovedItem;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

/**
 * Barang preloved contoh agar etalase web terisi saat demo.
 *
 * Sebagian barang memakai foto contoh dari storage/app/public/preloved.
 * Bila foto belum ada di disk upload (mis. disk palsu saat test), foto
 * disalin dari folder itu lebih dulu.
 *
 * Tidak dipanggil otomatis; jalankan setelah DemoSeeder:
 *   php artisan db:seed --class=PrelovedDemoSeeder
 *
 * Aman dijalankan ulang.
 */
class PrelovedDemoSeeder extends Seeder
{
    private const BARANG = [
        ['warga' => 1, 'judul' => 'Sepeda anak 16 inci', 'kategori' => 'Mainan', 'kondisi' => 'seperti_baru', 'harga' => 250000, 'kecamatan' => 'Tulang Bawang Tengah', 'deskripsi' => 'Ban baru diganti, rem masih pakem.', 'foto' => ['preloved/39712fce-6b09-4b07-abc8-b82924ab2854.jpg']],
        ['warga' => 2, 'judul' => 'Kursi rotan teras', 'kategori' => 'Perabot', 'kondisi' => 'bekas_baik', 'harga' => 150000, 'kecamatan' => 'Tumijajar', 'deskripsi' => 'Masih kokoh, cocok untuk teras rumah.'],
        ['warga' => 3, 'judul' => 'Rak buku kayu tiga susun', 'kategori' => 'Perabot', 'kondisi' => 'bekas', 'harga' => 120000, 'kecamatan' => 'Gunung Agung', 'deskripsi' => 'Ada sedikit goresan di sisi samping.'],
        ['warga' => 4, 'judul' => 'Kipas angin berdiri', 'kategori' => 'Elektronik', 'kondisi' => 'bekas_baik', 'harga' => 175000, 'kecamatan' => 'Lambu Kibang', 'deskripsi' => 'Semua kecepatan berfungsi normal.'],
        ['warga' => 5, 'judul' => 'Blender dua gelas', 'kategori' => 'Elektronik', 'kondisi' => 'seperti_baru', 'harga' => 200000, 'kecamatan' => 'Pagar Dewa', 'deskripsi' => 'Jarang dipakai, lengkap dengan dusnya.'],
        ['warga' => 1, 'judul' => 'Jaket denim ukuran L', 'kategori' => 'Pakaian', 'kondisi' => 'bekas_baik', 'harga' => 85000, 'kecamatan' => 'Tulang Bawang Tengah', 'deskripsi' => 'Warna masih bagus, tidak ada sobekan.'],
        ['warga' => 2, 'judul' => 'Set buku pelajaran SMP', 'kategori' => 'Buku', 'kondisi' => 'bekas', 'harga' => 60000, 'kecamatan' => 'Tumijajar', 'deskripsi' => 'Lengkap kelas 7 sampai 9, ada sedikit coretan.'],
        ['warga' => 3, 'judul' => 'Tas sekolah baru', 'kategori' => 'Pakaian', 'kondisi' => 'baru', 'harga' => 95000, 'kecamatan' => 'Batu Putih', 'deskripsi' => 'Belum pernah dipakai, masih ada label.'],
        ['warga' => 4, 'judul' => 'SD card SanDisk Extreme Pro 64GB', 'kategori' => 'Elektronik', 'kondisi' => 'bekas_baik', 'harga' => 90000, 'kecamatan' => 'Lambu Kibang', 'deskripsi' => 'Kecepatan baca 170 MB/s, cocok untuk kamera. Masih normal, tidak ada bad sector.', 'foto' => ['preloved/05cbf214-a757-4d66-9b4e-b81eaf104242.jpg']],
        ['warga' => 5, 'judul' => 'Lemari plastik empat pintu', 'kategori' => 'Perabot', 'kondisi' => 'bekas', 'harga' => 180000, 'kecamatan' => 'Pagar Dewa', 'deskripsi' => 'Dua susun, pintu masih rapat. Ada sedikit noda di bagian atas.', 'foto' => ['preloved/18cfd509-a261-44fd-8609-331103f8339b.jpg']],
        ['warga' => 1, 'judul' => 'Hair dryer Revlon Shine Booster', 'kategori' => 'Elektronik', 'kondisi' => 'seperti_baru', 'harga' => 220000, 'kecamatan' => 'Tulang Bawang Tengah', 'deskripsi' => 'Lengkap dengan dus, diffuser, dan buku petunjuk. Baru dipakai beberapa kali.', 'foto' => ['preloved/7f6f587e-974b-42d4-b408-52d02700a2e7.jpg']],
        ['warga' => 2, 'judul' => 'Baju lengan panjang putih', 'kategori' => 'Pakaian', 'kondisi' => 'bekas_baik', 'harga' => 45000, 'kecamatan' => 'Tumijajar', 'deskripsi' => 'Bahan rib, ada bordir kamera di dada. Ukuran M.', 'foto' => ['preloved/ca5a4ed5-db3a-40a5-bc96-ad8d7187ef6c.jpg']],
    ];

    public function run(): void
    {
        if (app()->environment('production')) {
            throw new RuntimeException('PrelovedDemoSeeder tidak boleh dijalankan di production.');
        }

        foreach (self::BARANG as $data) {
            $penjual = User::where('email', "warga{$data['warga']}@banksampah.test")->first();

            if (! $penjual) {
                throw new RuntimeException('Akun warga demo belum ada. Jalankan DemoSeeder lebih dulu.');
            }

            $foto = $this->siapkanFoto($data['foto'] ?? []);
            $barang = PrelovedItem::where('penjual_id', $penjual->id)->where('judul', $data['judul'])->first();

            if ($barang) {
                // Barang lama tanpa foto ikut mendapat foto contohnya.
                if ($foto && ! $barang->foto) {
                    $barang->foto = $foto;
                    $barang->save();
                }

                continue;
            }

            $barang = new PrelovedItem(collect($data)->except(['warga', 'foto'])->all());
            $barang->penjual_id = $penjual->id;
            $barang->status = StatusPreloved::Tersedia;
            $barang->foto = $foto;
            $barang->save();
        }

        $this->command?->info('  Barang preloved demo siap.');
    }

    /**
     * Pastikan foto contoh ada di disk upload; foto yang sumbernya hilang dilewati.
     *
     * @param  array<int, string>  $paths
     * @return array<int, string>
     */
    private function siapkanFoto(array $paths): array
    {
        $disk = Storage::disk(config('filesystems.upload_disk'));
        $siap = [];

        foreach ($paths as $path) {
            if (! $disk->exists($path)) {
                $sumber = storage_path('app/public/'.$path);

                if (! is_file($sumber)) {
                    continue;
                }

                $disk->put($path, file_get_contents($sumber));
            }

            $siap[] = $path;
        }

        return $siap;
    }
}
