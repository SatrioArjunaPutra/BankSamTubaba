<?php

namespace Tests\Feature;

use App\Models\BankSampah;
use App\Models\HargaSampah;
use App\Models\JenisSampah;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BankSampahUmumTest extends TestCase
{
    use RefreshDatabase;

    public function test_wajib_login(): void
    {
        $this->getJson('/api/v1/bank-sampah')->assertUnauthorized()->assertJsonPath('status', 'gagal');
        $this->getJson('/api/v1/jenis-sampah')->assertUnauthorized();
    }

    public function test_daftar_hanya_yang_aktif_dengan_filter_dan_pagination(): void
    {
        BankSampah::factory()->create(['nama' => 'Bank Sampah Melati', 'kecamatan' => 'Tumijajar']);
        BankSampah::factory()->create(['nama' => 'Bank Sampah Mawar', 'kecamatan' => 'Gunung Agung']);
        BankSampah::factory()->nonaktif()->create(['nama' => 'Bank Sampah Tutup', 'kecamatan' => 'Tumijajar']);
        Sanctum::actingAs(User::factory()->warga()->create());

        $this->getJson('/api/v1/bank-sampah')
            ->assertOk()
            ->assertJsonPath('status', 'sukses')
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.total', 2)
            ->assertJsonStructure(['links', 'meta']);

        $this->getJson('/api/v1/bank-sampah?kecamatan=Tumijajar')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.nama', 'Bank Sampah Melati');

        $this->getJson('/api/v1/bank-sampah?q=mawar')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.nama', 'Bank Sampah Mawar');
    }

    public function test_detail_berisi_harga_jenis_aktif_dan_angka_bertipe_number(): void
    {
        $bank = BankSampah::factory()->create(['lat' => -4.5, 'lng' => 105.1]);
        $plastik = JenisSampah::factory()->create(['nama' => 'Plastik']);
        $lama = JenisSampah::factory()->create(['nama' => 'Lama', 'is_aktif' => false]);
        HargaSampah::create(['bank_sampah_id' => $bank->id, 'jenis_sampah_id' => $plastik->id, 'harga_per_kg' => 3000]);
        HargaSampah::create(['bank_sampah_id' => $bank->id, 'jenis_sampah_id' => $lama->id, 'harga_per_kg' => 100]);
        Sanctum::actingAs(User::factory()->warga()->create());

        $response = $this->getJson("/api/v1/bank-sampah/{$bank->id}")
            ->assertOk()
            ->assertJsonCount(1, 'data.harga')
            ->assertJsonPath('data.harga.0.nama', 'Plastik')
            ->assertJsonPath('data.lat', -4.5);

        // Uang dikirim sebagai number JSON, bukan string
        $this->assertIsNotString($response->json('data.harga.0.harga_per_kg'));
        $this->assertEquals(3000, $response->json('data.harga.0.harga_per_kg'));
    }

    public function test_detail_bank_nonaktif_atau_tidak_ada_404(): void
    {
        $bank = BankSampah::factory()->nonaktif()->create();
        Sanctum::actingAs(User::factory()->warga()->create());

        $this->getJson("/api/v1/bank-sampah/{$bank->id}")->assertNotFound()->assertJsonPath('status', 'gagal');
        $this->getJson('/api/v1/bank-sampah/99999')->assertNotFound();
    }

    public function test_nearby_urut_jarak_dan_dalam_radius(): void
    {
        // Pusat: Panaragan (-4.585, 105.132)
        $dekat = BankSampah::factory()->create(['nama' => 'Dekat', 'lat' => -4.590, 'lng' => 105.135]);
        $sedang = BankSampah::factory()->create(['nama' => 'Sedang', 'lat' => -4.620, 'lng' => 105.160]);
        BankSampah::factory()->create(['nama' => 'Jauh', 'lat' => -4.152, 'lng' => 105.251]);
        BankSampah::factory()->create(['nama' => 'Tanpa Koordinat', 'lat' => null, 'lng' => null]);
        Sanctum::actingAs(User::factory()->warga()->create());

        $response = $this->getJson('/api/v1/bank-sampah/nearby?lat=-4.585&lng=105.132&radius_km=10')
            ->assertOk()
            ->assertJsonCount(2, 'data');

        $this->assertSame([$dekat->id, $sedang->id], array_column($response->json('data'), 'id'));
        $this->assertLessThan(1, $response->json('data.0.jarak_km'));
    }

    public function test_nearby_validasi(): void
    {
        Sanctum::actingAs(User::factory()->warga()->create());

        $this->getJson('/api/v1/bank-sampah/nearby?lat=abc&radius_km=100')
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['lat', 'lng', 'radius_km']);
    }

    public function test_jenis_sampah_hanya_yang_aktif(): void
    {
        JenisSampah::factory()->create(['nama' => 'Kardus']);
        JenisSampah::factory()->create(['nama' => 'Arsip', 'is_aktif' => false]);
        Sanctum::actingAs(User::factory()->bentor()->create());

        $this->getJson('/api/v1/jenis-sampah')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.nama', 'Kardus');
    }
}
