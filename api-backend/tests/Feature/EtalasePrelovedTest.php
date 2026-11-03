<?php

namespace Tests\Feature;

use App\Enums\StatusPreloved;
use App\Models\PrelovedItem;
use App\Models\User;
use Database\Seeders\DemoSeeder;
use Database\Seeders\PrelovedDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Tests\Concerns\MembuatPreloved;
use Tests\TestCase;

class EtalasePrelovedTest extends TestCase
{
    use MembuatPreloved, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    public function test_dapat_dibuka_tanpa_login_dengan_format_angka_dan_url_foto(): void
    {
        $this->barang(User::factory()->warga()->create(), ['harga' => 150000]);

        $this->getJson('/api/v1/etalase-preloved')
            ->assertOk()
            ->assertJsonPath('status', 'sukses')
            ->assertJsonPath('data.0.judul', 'Kursi rotan')
            ->assertJsonPath('data.0.harga', 150000)
            ->assertJsonPath('data.0.foto.0', Storage::disk('public')->url('preloved/contoh.jpg'));
    }

    public function test_tidak_membocorkan_identitas_penjual(): void
    {
        $penjual = User::factory()->warga()->create(['name' => 'Sri Rahayu Penjual', 'phone' => '081299887766', 'email' => 'sri.penjual@contoh.test']);
        $this->barang($penjual);

        $response = $this->getJson('/api/v1/etalase-preloved')->assertOk();

        $this->assertSame(
            ['id', 'judul', 'deskripsi', 'kategori', 'kondisi', 'harga', 'kecamatan', 'foto', 'created_at'],
            array_keys($response->json('data.0')),
        );
        foreach ([$penjual->name, $penjual->phone, $penjual->email] as $rahasia) {
            $this->assertStringNotContainsString($rahasia, $response->getContent());
        }
    }

    public function test_hanya_barang_tersedia_dari_penjual_aktif_yang_tayang(): void
    {
        $penjual = User::factory()->warga()->create();
        $this->barang($penjual, ['judul' => 'Tayang', 'kategori' => 'Perabot', 'kecamatan' => 'Tumijajar']);
        $this->barang($penjual, ['judul' => 'Sudah terjual', 'kategori' => 'Kategori terjual'], StatusPreloved::Terjual);
        $this->barang($penjual, ['judul' => 'Disembunyikan DLH', 'kecamatan' => 'Kecamatan tersembunyi'], StatusPreloved::Disembunyikan);
        $this->barang(User::factory()->warga()->create(['is_aktif' => false]), ['judul' => 'Penjual nonaktif']);

        $this->getJson('/api/v1/etalase-preloved')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.judul', 'Tayang')
            ->assertJsonPath('filter.kategori', ['Perabot'])
            ->assertJsonPath('filter.kecamatan', ['Tumijajar']);
    }

    public function test_filter_dan_pencarian_tetap_memuat_semua_pilihan_filter(): void
    {
        $penjual = User::factory()->warga()->create();
        $this->barang($penjual, ['judul' => 'Kipas angin', 'kategori' => 'Elektronik', 'kecamatan' => 'Tumijajar']);
        $this->barang($penjual, ['judul' => 'Meja belajar', 'kategori' => 'Perabot', 'kecamatan' => 'Batu Putih', 'deskripsi' => 'Kayu jati']);

        $this->getJson('/api/v1/etalase-preloved?kategori=Elektronik')->assertJsonCount(1, 'data')->assertJsonPath('data.0.judul', 'Kipas angin')
            ->assertJsonPath('filter.kategori', ['Elektronik', 'Perabot']);
        $this->getJson('/api/v1/etalase-preloved?kecamatan=Batu%20Putih')->assertJsonCount(1, 'data')->assertJsonPath('data.0.judul', 'Meja belajar');
        $this->getJson('/api/v1/etalase-preloved?q=JATI')->assertJsonCount(1, 'data')->assertJsonPath('data.0.judul', 'Meja belajar');
        $this->getJson('/api/v1/etalase-preloved?q=tidak-ada')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_pagination_dua_puluh_per_halaman_dan_input_tidak_sah_ditolak(): void
    {
        $penjual = User::factory()->warga()->create();
        foreach (range(1, 21) as $no) {
            $this->barang($penjual, ['judul' => "Barang {$no}"]);
        }

        $this->getJson('/api/v1/etalase-preloved')->assertJsonCount(20, 'data')->assertJsonPath('meta.total', 21)->assertJsonPath('meta.last_page', 2);
        $this->getJson('/api/v1/etalase-preloved?page=2')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/etalase-preloved?q='.str_repeat('a', 101))->assertUnprocessable();
    }

    public function test_permintaan_berlebihan_dibatasi(): void
    {
        foreach (range(1, 60) as $_) {
            $this->getJson('/api/v1/etalase-preloved')->assertOk();
        }

        $this->getJson('/api/v1/etalase-preloved')->assertTooManyRequests();
    }

    public function test_seeder_demo_aman_diulang_dan_gagal_jelas_tanpa_data_warga(): void
    {
        try {
            $this->seed(PrelovedDemoSeeder::class);
            $this->fail('Seeder seharusnya gagal tanpa akun warga demo.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('Jalankan DemoSeeder lebih dulu', $e->getMessage());
        }

        $this->seed(DemoSeeder::class);
        $this->seed(PrelovedDemoSeeder::class);
        $this->seed(PrelovedDemoSeeder::class);

        $this->assertSame(12, PrelovedItem::count());
        $this->getJson('/api/v1/etalase-preloved')->assertOk()->assertJsonCount(12, 'data');
    }

    public function test_seeder_demo_memasang_foto_contoh_ke_disk_upload(): void
    {
        $this->seed(DemoSeeder::class);
        $this->seed(PrelovedDemoSeeder::class);

        $path = 'preloved/05cbf214-a757-4d66-9b4e-b81eaf104242.jpg';
        $barang = PrelovedItem::where('judul', 'SD card SanDisk Extreme Pro 64GB')->firstOrFail();

        $this->assertSame([$path], $barang->foto);
        Storage::disk('public')->assertExists($path);
        $this->assertSame(5, PrelovedItem::all()->filter(fn ($b) => count($b->foto) === 1)->count());

        $this->getJson("/api/v1/etalase-preloved?q=SanDisk")
            ->assertOk()
            ->assertJsonPath('data.0.foto.0', Storage::disk('public')->url($path));
    }

    public function test_seeder_demo_ditolak_di_production(): void
    {
        $this->app->detectEnvironment(fn () => 'production');

        $this->expectException(RuntimeException::class);
        $this->app->make(PrelovedDemoSeeder::class)->run();
    }
}
