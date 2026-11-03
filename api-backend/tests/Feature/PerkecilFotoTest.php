<?php

namespace Tests\Feature;

use App\Support\GambarAman;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PerkecilFotoTest extends TestCase
{
    use RefreshDatabase;

    /** @return array{0: int, 1: int} */
    private function ukuran(string $isi): array
    {
        $info = getimagesizefromstring($isi);

        return [$info[0], $info[1]];
    }

    public function test_foto_besar_diperkecil_dengan_perbandingan_yang_sama(): void
    {
        $datar = GambarAman::bersihkan(UploadedFile::fake()->image('datar.jpg', 3000, 2000));
        $tegak = GambarAman::bersihkan(UploadedFile::fake()->image('tegak.jpg', 1500, 3000));

        $this->assertSame([1280, 853], array_slice(getimagesize($datar->getRealPath()), 0, 2));
        $this->assertSame([640, 1280], array_slice(getimagesize($tegak->getRealPath()), 0, 2));

        @unlink($datar->getRealPath());
        @unlink($tegak->getRealPath());
    }

    public function test_foto_kecil_tidak_diperbesar(): void
    {
        $bersih = GambarAman::bersihkan(UploadedFile::fake()->image('kecil.jpg', 800, 600));

        $this->assertSame([800, 600], array_slice(getimagesize($bersih->getRealPath()), 0, 2));

        @unlink($bersih->getRealPath());
    }

    public function test_png_tetap_transparan_setelah_diperkecil(): void
    {
        $asli = imagecreatetruecolor(2000, 1000);
        imagealphablending($asli, false);
        imagesavealpha($asli, true);
        imagefill($asli, 0, 0, imagecolorallocatealpha($asli, 0, 0, 0, 127));
        $path = tempnam(sys_get_temp_dir(), 'uji-png-');
        imagepng($asli, $path);

        $bersih = GambarAman::bersihkan(new UploadedFile($path, 'a.png', 'image/png', null, true));
        $hasil = imagecreatefrompng($bersih->getRealPath());

        $this->assertSame(1280, imagesx($hasil));
        $this->assertSame(127, imagecolorat($hasil, 10, 10) >> 24 & 0x7F);

        @unlink($path);
        @unlink($bersih->getRealPath());
    }

    public function test_perintah_memperkecil_foto_lama_tanpa_mengubah_nama_file(): void
    {
        Storage::fake('public');
        $disk = Storage::disk('public');
        $besar = UploadedFile::fake()->image('b.jpg', 2560, 1440);
        $kecil = UploadedFile::fake()->image('k.jpg', 600, 400);
        $disk->put('preloved/besar.jpg', file_get_contents($besar->getRealPath()));
        $disk->put('berita/kecil.jpg', file_get_contents($kecil->getRealPath()));
        $isiKecil = $disk->get('berita/kecil.jpg');

        $this->artisan('foto:perkecil')
            ->expectsOutputToContain('1 foto diperkecil')
            ->assertSuccessful();

        $this->assertSame([1280, 720], $this->ukuran($disk->get('preloved/besar.jpg')));
        $this->assertSame($isiKecil, $disk->get('berita/kecil.jpg'));

        // Dijalankan ulang tidak mengubah apa pun
        $hasilPertama = $disk->get('preloved/besar.jpg');
        $this->artisan('foto:perkecil')->expectsOutputToContain('0 foto diperkecil')->assertSuccessful();
        $this->assertSame($hasilPertama, $disk->get('preloved/besar.jpg'));
    }

    public function test_izin_cors_disimpan_browser_agar_tidak_diminta_ulang(): void
    {
        $this->call('OPTIONS', '/api/v1/dlh/dashboard', [], [], [], [
            'HTTP_ORIGIN' => 'http://localhost:5173',
            'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'GET',
            'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => 'authorization',
        ])->assertHeader('Access-Control-Max-Age', '7200');
    }
}
