<?php

namespace Tests\Feature;

use App\Models\BankSampah;
use App\Models\HargaSampah;
use App\Models\JenisSampah;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Trait BelongsToBankSampah: scope milik() & dimilikiOleh().
 */
class TenancyScopeTest extends TestCase
{
    use RefreshDatabase;

    public function test_operator_hanya_melihat_data_bank_sendiri(): void
    {
        [$bankA, $bankB] = BankSampah::factory()->count(2)->create();
        $jenis = JenisSampah::factory()->create();
        $hargaA = HargaSampah::create(['bank_sampah_id' => $bankA->id, 'jenis_sampah_id' => $jenis->id, 'harga_per_kg' => 1000]);
        $hargaB = HargaSampah::create(['bank_sampah_id' => $bankB->id, 'jenis_sampah_id' => $jenis->id, 'harga_per_kg' => 2000]);

        $operatorA = User::factory()->bankSampah()->create(['bank_sampah_id' => $bankA->id]);
        $bentorA = User::factory()->bentor()->create(['bank_sampah_id' => $bankA->id]);
        $dlh = User::factory()->dlh()->create();

        $this->assertSame([$hargaA->id], HargaSampah::milik($operatorA)->pluck('id')->all());
        $this->assertSame([$hargaA->id], HargaSampah::milik($bentorA)->pluck('id')->all());
        $this->assertCount(2, HargaSampah::milik($dlh)->get());

        $this->assertTrue($hargaA->dimilikiOleh($operatorA));
        $this->assertFalse($hargaB->dimilikiOleh($operatorA));
        $this->assertFalse($hargaA->dimilikiOleh($dlh));
    }

    public function test_operator_tanpa_bank_sampah_tidak_melihat_apa_pun(): void
    {
        $bank = BankSampah::factory()->create();
        $jenis = JenisSampah::factory()->create();
        HargaSampah::create(['bank_sampah_id' => $bank->id, 'jenis_sampah_id' => $jenis->id, 'harga_per_kg' => 1000]);

        $yatim = User::factory()->bankSampah()->create(['bank_sampah_id' => null]);

        $this->assertCount(0, HargaSampah::milik($yatim)->get());
    }
}
