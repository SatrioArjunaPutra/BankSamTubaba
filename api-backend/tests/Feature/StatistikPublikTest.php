<?php

namespace Tests\Feature;

use App\Enums\StatusPreloved;
use App\Models\BankSampah;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\MembuatPreloved;
use Tests\TestCase;

class StatistikPublikTest extends TestCase
{
    use MembuatPreloved, RefreshDatabase;

    public function test_statistik_menghitung_bank_aktif_per_kecamatan(): void
    {
        BankSampah::factory()->count(2)->create(['kecamatan' => 'Tumijajar', 'is_aktif' => true]);
        BankSampah::factory()->create(['kecamatan' => 'Tumijajar', 'is_aktif' => false]);
        BankSampah::factory()->create(['kecamatan' => 'Way Kenanga', 'is_aktif' => true]);

        $this->getJson('/api/v1/statistik-publik')->assertOk()
            ->assertJsonPath('data.bank_per_kecamatan.Tumijajar', 2)
            ->assertJsonPath('data.bank_per_kecamatan.Way Kenanga', 1);
    }

    public function test_tanpa_login_hanya_menghitung_data_aktif_dan_tayang(): void
    {
        BankSampah::factory()->create(['kecamatan' => 'Tumijajar']);
        BankSampah::factory()->create(['kecamatan' => 'Tumijajar']);
        BankSampah::factory()->create(['kecamatan' => 'Batu Putih']);
        BankSampah::factory()->create(['kecamatan' => 'Kecamatan Nonaktif', 'is_aktif' => false]);

        $penjual = User::factory()->warga()->create();
        $this->barang($penjual);
        $this->barang($penjual, [], StatusPreloved::Terjual);
        $this->barang($penjual, [], StatusPreloved::Disembunyikan);
        $this->barang(User::factory()->warga()->create(['is_aktif' => false]));

        $this->getJson('/api/v1/statistik-publik')
            ->assertOk()
            ->assertJsonPath('status', 'sukses')
            ->assertExactJson([
                'status' => 'sukses',
                'pesan' => 'Statistik berhasil dimuat.',
                'data' => [
                    'bank_sampah' => 3,
                    'kecamatan' => 2,
                    'barang_preloved' => 1,
                    'bank_per_kecamatan' => ['Batu Putih' => 1, 'Tumijajar' => 2],
                ],
            ]);
    }

    public function test_permintaan_berlebihan_dibatasi(): void
    {
        foreach (range(1, 60) as $_) {
            $this->getJson('/api/v1/statistik-publik')->assertOk();
        }

        $this->getJson('/api/v1/statistik-publik')->assertTooManyRequests();
    }
}
