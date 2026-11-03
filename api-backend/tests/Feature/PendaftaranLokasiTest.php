<?php

namespace Tests\Feature;

use App\Models\BankSampah;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PendaftaranLokasiTest extends TestCase
{
    use RefreshDatabase;

    private function dataDaftar(array $ubah = []): array
    {
        return array_merge([
            'name' => 'Siti Warga',
            'email' => 'siti@example.com',
            'phone' => '081234567890',
            'password' => 'Rahasia123',
            'password_confirmation' => 'Rahasia123',
            'alamat' => 'Jl. Melati 1, Panaragan',
            'lat' => -4.495,
            'lng' => 105.075,
        ], $ubah);
    }

    public function test_pendaftaran_menyimpan_alamat_dan_titik_rumah(): void
    {
        $this->postJson('/api/v1/auth/register', $this->dataDaftar())->assertCreated()
            ->assertJsonPath('data.user.alamat', 'Jl. Melati 1, Panaragan')
            ->assertJsonPath('data.user.lat', -4.495)
            ->assertJsonPath('data.user.lng', 105.075);

        $warga = User::where('email', 'siti@example.com')->firstOrFail();
        $this->assertSame('Jl. Melati 1, Panaragan', $warga->alamat);
        $this->assertEqualsWithDelta(-4.495, (float) $warga->lat, 0.00001);
    }

    public function test_pendaftaran_ditolak_tanpa_alamat_atau_titik_rumah(): void
    {
        foreach (['alamat', 'lat', 'lng'] as $kolom) {
            $this->postJson('/api/v1/auth/register', $this->dataDaftar([$kolom => null]))
                ->assertUnprocessable()
                ->assertJsonValidationErrors($kolom);
        }

        $this->postJson('/api/v1/auth/register', $this->dataDaftar(['lat' => 200]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('lat');
        $this->assertSame(0, User::count());
    }

    public function test_calon_warga_melihat_tiga_bank_terdekat_tanpa_login(): void
    {
        foreach ([0.20, 0.01, 0.05, 0.10] as $i => $selisih) {
            BankSampah::factory()->create(['kode' => 'BS-UJI-'.$i, 'lat' => -4.495 + $selisih, 'lng' => 105.075, 'is_aktif' => true]);
        }
        $nonaktif = BankSampah::factory()->create(['kode' => 'BS-UJI-MATI', 'lat' => -4.495, 'lng' => 105.075, 'is_aktif' => false]);
        BankSampah::factory()->create(['kode' => 'BS-UJI-JAUH', 'lat' => -3.0, 'lng' => 105.075, 'is_aktif' => true]);

        $hasil = $this->getJson('/api/v1/pendaftaran/bank-terdekat?lat=-4.495&lng=105.075&radius_km=1')->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.kode', 'BS-UJI-1')
            ->assertJsonPath('data.1.kode', 'BS-UJI-2')
            ->assertJsonPath('data.2.kode', 'BS-UJI-3');

        $this->assertIsNumeric($hasil->json('data.0.jarak_km'));
        $this->assertNotContains($nonaktif->kode, collect($hasil->json('data'))->pluck('kode'));
    }

    public function test_pencarian_tanpa_titik_ditolak(): void
    {
        $this->getJson('/api/v1/pendaftaran/bank-terdekat?lng=105.075')->assertUnprocessable()->assertJsonValidationErrors('lat');
    }

    public function test_warga_lama_bisa_melengkapi_titik_lewat_profil(): void
    {
        $warga = User::factory()->create(['role' => 'warga', 'lat' => null, 'lng' => null]);

        $this->actingAs($warga, 'sanctum')
            ->patchJson('/api/v1/me', ['alamat' => 'Jl. Baru', 'lat' => -4.5, 'lng' => 105.08])
            ->assertOk()
            ->assertJsonPath('data.lat', -4.5);
    }
}
