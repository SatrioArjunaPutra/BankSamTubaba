<?php

namespace Tests\Feature;

use App\Models\Penjemputan;
use App\Models\PrelovedItem;
use App\Support\GambarAman;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

/**
 * Foto unggahan di-encode ulang: EXIF (termasuk GPS rumah warga) terbuang.
 */
class GambarAmanTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    /** @var array<int, string> */
    private array $sementara = [];

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');

        if (! function_exists('exif_read_data')) {
            $this->fail('Ekstensi PHP "exif" wajib aktif untuk menjalankan test ini (aktifkan extension=exif di php.ini).');
        }
    }

    protected function tearDown(): void
    {
        array_map('unlink', array_filter($this->sementara, 'is_file'));
        parent::tearDown();
    }

    /**
     * JPEG 40x20 dengan EXIF: GPS (lintang 4°35'12" S) dan Orientation=6
     * (harus diputar 90° searah jarum jam → 20x40).
     */
    private function jpegDenganGps(): UploadedFile
    {
        $gambar = imagecreatetruecolor(40, 20);
        imagefill($gambar, 0, 0, imagecolorallocate($gambar, 30, 160, 60));
        ob_start();
        imagejpeg($gambar);
        $jpeg = ob_get_clean();

        // TIFF little-endian: IFD0 (Orientation, pointer GPS) → GPS IFD (LatRef, Lat) → data rasional
        $tiff = "II*\0".pack('V', 8)
            .pack('v', 2)
            .pack('vvV', 0x0112, 3, 1).pack('vv', 6, 0)
            .pack('vvVV', 0x8825, 4, 1, 38)
            .pack('V', 0)
            .pack('v', 2)
            .pack('vvV', 0x0001, 2, 2)."S\0\0\0"
            .pack('vvVV', 0x0002, 5, 3, 68)
            .pack('V', 0)
            .pack('V*', 4, 1, 35, 1, 12, 1);
        $app1 = "\xFF\xE1".pack('n', 2 + 6 + strlen($tiff))."Exif\0\0".$tiff;

        $path = tempnam(sys_get_temp_dir(), 'gps').'.jpg';
        file_put_contents($path, substr($jpeg, 0, 2).$app1.substr($jpeg, 2));
        $this->sementara[] = $path;

        // Pastikan file uji memang berisi GPS sebelum diunggah
        $exif = exif_read_data($path);
        $this->assertSame('S', $exif['GPSLatitudeRef']);
        $this->assertSame(6, $exif['Orientation']);

        return new UploadedFile($path, 'foto-rumah.jpg', 'image/jpeg', null, true);
    }

    private function assertTanpaExifGps(string $pathRelatif): void
    {
        $file = Storage::disk('public')->path($pathRelatif);
        $exif = @exif_read_data($file) ?: [];
        $kunciGps = array_filter(array_keys($exif), fn ($k) => str_starts_with($k, 'GPS'));

        $this->assertSame([], $kunciGps, 'Masih ada data GPS di file tersimpan');
        $this->assertArrayNotHasKey('Orientation', $exif);
        $this->assertStringNotContainsString('Exif', file_get_contents($file));
    }

    public function test_foto_penjemputan_tersimpan_tanpa_exif_gps_dan_orientasi_diterapkan(): void
    {
        $bank = $this->bank();
        Sanctum::actingAs($this->warga());

        $this->post('/api/v1/warga/penjemputan', [
            'bank_sampah_id' => $bank->id,
            'alamat' => 'Jl. Melati 1',
            'lat' => -4.58,
            'lng' => 105.13,
            'foto' => $this->jpegDenganGps(),
        ], ['Accept' => 'application/json'])->assertCreated();

        $path = Penjemputan::first()->foto_path;
        $this->assertMatchesRegularExpression('#^penjemputan/[0-9a-f-]{36}\.jpg$#', $path);
        $this->assertTanpaExifGps($path);

        // Orientation=6 diterapkan sebelum EXIF dibuang: 40x20 → 20x40
        [$lebar, $tinggi] = getimagesize(Storage::disk('public')->path($path));
        $this->assertSame([20, 40], [$lebar, $tinggi]);
    }

    public function test_foto_preloved_tersimpan_tanpa_exif_gps(): void
    {
        Sanctum::actingAs($this->warga());

        $this->post('/api/v1/preloved', [
            'judul' => 'Kursi',
            'deskripsi' => 'Kursi kayu',
            'kategori' => 'Perabot',
            'kondisi' => 'bekas_baik',
            'harga' => 50000,
            'kecamatan' => 'Tumijajar',
            'foto' => [$this->jpegDenganGps(), $this->jpegDenganGps()],
        ], ['Accept' => 'application/json'])->assertCreated();

        $foto = PrelovedItem::first()->foto;
        $this->assertCount(2, $foto);
        foreach ($foto as $path) {
            $this->assertTanpaExifGps($path);
        }
    }

    public function test_png_dan_webp_tetap_formatnya(): void
    {
        Sanctum::actingAs($this->warga());

        $this->post('/api/v1/preloved', [
            'judul' => 'Lampu',
            'deskripsi' => 'Lampu meja',
            'kategori' => 'Elektronik',
            'kondisi' => 'baru',
            'harga' => 20000,
            'kecamatan' => 'Tumijajar',
            'foto' => [UploadedFile::fake()->image('a.png', 30, 30), UploadedFile::fake()->image('b.webp', 30, 30)],
        ], ['Accept' => 'application/json'])->assertCreated();

        [$png, $webp] = PrelovedItem::first()->foto;
        $this->assertStringEndsWith('.png', $png);
        $this->assertStringEndsWith('.webp', $webp);
        $this->assertSame(IMAGETYPE_PNG, getimagesize(Storage::disk('public')->path($png))[2]);
        $this->assertSame(IMAGETYPE_WEBP, getimagesize(Storage::disk('public')->path($webp))[2]);
    }

    public function test_resolusi_terlalu_besar_ditolak_dan_tidak_ada_file_tertinggal(): void
    {
        config(['banksampah.maks_piksel_foto' => 1000]);
        Sanctum::actingAs($this->warga());

        $this->post('/api/v1/preloved', [
            'judul' => 'Poster',
            'deskripsi' => 'Poster besar',
            'kategori' => 'Lainnya',
            'kondisi' => 'baru',
            'harga' => 10000,
            'kecamatan' => 'Tumijajar',
            'foto' => [UploadedFile::fake()->image('kecil.jpg', 20, 20), UploadedFile::fake()->image('besar.jpg', 100, 100)],
        ], ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonPath('errors', ['foto.1' => ['Resolusi foto terlalu besar. Perkecil foto lalu coba lagi.']]);

        $this->assertSame([], Storage::disk('public')->allFiles());
        $this->assertSame(0, PrelovedItem::count());
    }

    public function test_gd_tersedia_dengan_jpeg_png_webp(): void
    {
        GambarAman::pastikanTersedia();
        $this->addToAssertionCount(1);
    }
}
