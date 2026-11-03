<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\BankSampah;
use App\Models\User;
use App\Services\SetoranService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

class PetaDlhTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    public function test_peta_hanya_dapat_diakses_dlh(): void
    {
        $this->getJson('/api/v1/dlh/peta')->assertUnauthorized();
        foreach ([UserRole::Warga, UserRole::BankSampah, UserRole::Bentor] as $role) {
            Sanctum::actingAs(User::factory()->create(['role' => $role, 'bank_sampah_id' => $role === UserRole::Warga ? null : $this->bank()->id]));
            $this->getJson('/api/v1/dlh/peta')->assertForbidden();
        }
    }

    public function test_peta_memuat_semua_titik_termasuk_bank_nonaktif_dan_membedakan_estimasi(): void
    {
        $this->travelTo('2026-10-31 12:00:00');
        $bank = $this->bank(['Plastik' => 3000]);
        $bank->update(['kode' => 'BS-TUBABA-01', 'nama' => 'Bank Melati', 'kecamatan' => 'Tumijajar', 'tiyuh' => 'Daya Murni', 'lat' => -4.512, 'lng' => 105.152, 'koordinat_estimasi' => false]);
        $warga = $this->warga();
        app(SetoranService::class)->catat($this->operator($bank), [
            'warga_id' => $warga->id, 'tipe' => 'jual',
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2]],
        ]);
        BankSampah::factory()->create(['kode' => 'BS-TUBABA-02', 'kecamatan' => 'Tumijajar', 'tiyuh' => 'Daya Murni', 'lat' => -4.51, 'lng' => 105.15, 'koordinat_estimasi' => true, 'is_aktif' => false]);
        BankSampah::factory()->create(['kode' => 'BS-TUBABA-03', 'kecamatan' => 'Batu Putih', 'tiyuh' => 'Tiyuh Uji', 'lat' => null, 'lng' => null, 'koordinat_estimasi' => false]);
        BankSampah::factory()->create(['kode' => 'BS-DEMO-01']);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $response = $this->getJson('/api/v1/dlh/peta')->assertOk()
            ->assertJsonCount(3, 'data.bank_sampah')
            ->assertJsonPath('data.ringkasan.jumlah', 3)
            ->assertJsonPath('data.ringkasan.koordinat_terisi', 1)
            ->assertJsonPath('data.ringkasan.koordinat_estimasi', 1)
            ->assertJsonPath('data.ringkasan.tanpa_koordinat', 1)
            ->assertJsonCount(2, 'data.wilayah');
        $melati = collect($response->json('data.bank_sampah'))->firstWhere('kode', 'BS-TUBABA-01');
        $this->assertSame(-4.512, $melati['lat']);
        $this->assertSame(2, $melati['total_kg']);
        $this->assertSame(6000, $melati['nilai_setoran']);
        $this->assertSame('registri', $melati['sumber']);
        $this->assertSame(6000.0, $this->saldo($warga, $bank));
        $this->assertStringNotContainsString($warga->email, $response->getContent());
        $this->assertArrayNotHasKey('password', $melati);

        $this->getJson('/api/v1/dlh/peta?koordinat=estimasi')->assertOk()->assertJsonCount(1, 'data.bank_sampah')->assertJsonPath('data.bank_sampah.0.is_aktif', false);
        $this->getJson('/api/v1/dlh/peta?koordinat=terisi')->assertOk()->assertJsonCount(1, 'data.bank_sampah');
        $this->getJson('/api/v1/dlh/peta?koordinat=kosong')->assertOk()->assertJsonCount(1, 'data.bank_sampah');
        $this->getJson('/api/v1/dlh/peta?sumber=demo')->assertOk()->assertJsonCount(1, 'data.bank_sampah')->assertJsonPath('data.bank_sampah.0.sumber', 'demo');
        $this->getJson('/api/v1/dlh/peta?sumber=semua')->assertOk()->assertJsonCount(4, 'data.bank_sampah');
        $this->getJson('/api/v1/dlh/peta?kecamatan=Tumijajar&tiyuh=Daya%20Murni&q=Melati')->assertOk()->assertJsonCount(1, 'data.bank_sampah');
        $this->getJson('/api/v1/dlh/peta?is_aktif=0')->assertOk()->assertJsonCount(1, 'data.bank_sampah');
        $this->getJson('/api/v1/dlh/peta?sumber=tidak-sah')->assertUnprocessable();
    }

    public function test_peta_tidak_terpotong_batas_paginasi_daftar_dua_puluh_bank(): void
    {
        BankSampah::factory()->count(27)->create();
        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/v1/dlh/peta')->assertOk()
            ->assertJsonCount(27, 'data.bank_sampah')
            ->assertJsonPath('data.ringkasan.jumlah', 27);
    }
}
