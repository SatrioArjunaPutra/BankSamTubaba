<?php

namespace Tests\Feature;

use App\Models\HargaSampah;
use App\Models\PenjualanPengepul;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

/**
 * Harga, cari nasabah, dashboard, penjualan pengepul.
 */
class OperasionalBankSampahTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    public function test_atur_harga_hanya_untuk_bank_sendiri(): void
    {
        $bankA = $this->bank(['Plastik' => 3000]);
        $bankB = $this->bank(['Plastik' => 4000]);
        $kardus = $this->jenis('Kardus');
        Sanctum::actingAs($this->operator($bankA));

        $this->getJson('/api/v1/bs/harga')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.nama', 'Kardus')
            ->assertJsonPath('data.0.harga_per_kg', null)
            ->assertJsonPath('data.1.harga_per_kg', 3000);

        $this->putJson('/api/v1/bs/harga', ['harga' => [
            ['jenis_sampah_id' => $kardus->id, 'harga_per_kg' => 1500],
            ['jenis_sampah_id' => $this->jenis('Plastik')->id, 'harga_per_kg' => 3500.5],
        ]])
            ->assertOk()
            ->assertJsonPath('data.0.harga_per_kg', 1500)
            ->assertJsonPath('data.1.harga_per_kg', 3500.5);

        $this->assertSame(4000.0, (float) HargaSampah::where('bank_sampah_id', $bankB->id)->value('harga_per_kg'));

        $this->putJson('/api/v1/bs/harga', ['harga' => [['jenis_sampah_id' => $kardus->id, 'harga_per_kg' => -1]]])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('harga.0.harga_per_kg');
    }

    public function test_warga_tidak_bisa_mengatur_harga(): void
    {
        $this->bank(['Plastik' => 3000]);
        Sanctum::actingAs($this->warga());

        $this->putJson('/api/v1/bs/harga', ['harga' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'harga_per_kg' => 1]]])
            ->assertForbidden();
    }

    public function test_cari_nasabah_dengan_saldo_di_bank_operator(): void
    {
        $bankA = $this->bank();
        $bankB = $this->bank();
        $siti = User::factory()->warga()->create(['name' => 'Siti Aminah', 'phone' => '081211110000', 'alamat' => 'Jl. Siti']);
        $budi = User::factory()->warga()->create(['name' => 'Budi', 'email' => 'budi@contoh.id', 'phone' => '+6281299990000', 'alamat' => 'Jl. Budi']);
        User::factory()->warga()->create(['name' => 'Siti Nonaktif', 'is_aktif' => false]);
        User::factory()->bentor()->create(['name' => 'Siti Bentor', 'bank_sampah_id' => $bankA->id]);
        $this->beriSaldo($siti, $bankA, 7000);
        $this->beriSaldo($budi, $bankB, 9000);

        Sanctum::actingAs($this->operator($bankA));

        // Tanpa q: hanya nasabah bank ini
        $this->getJson('/api/v1/bs/nasabah')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $siti->id)
            ->assertJsonPath('data.0.saldo', 7000);

        // Nasabah bank ini: cocok sebagian, alamat ikut
        $this->getJson('/api/v1/bs/nasabah?q=siti')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.alamat', 'Jl. Siti');

        // Warga lain TIDAK bisa ditemukan dengan pencarian sebagian (cegah penelusuran data pribadi)
        foreach (['budi', '9999', 'contoh.id', '@contoh'] as $sebagian) {
            $this->getJson('/api/v1/bs/nasabah?q='.urlencode($sebagian))->assertOk()->assertJsonCount(0, 'data');
        }

        // ...hanya dengan nomor HP (format apa pun) atau email persis; alamat tidak dikirim
        foreach (['081299990000', '6281299990000', '+6281299990000', '0812-9999-0000', 'BUDI@contoh.id'] as $persis) {
            $this->getJson('/api/v1/bs/nasabah?q='.urlencode($persis))
                ->assertJsonCount(1, 'data')
                ->assertJsonPath('data.0.id', $budi->id)
                ->assertJsonPath('data.0.saldo', 0)
                ->assertJsonPath('data.0.sudah_nasabah', false)
                ->assertJsonPath('data.0.alamat', null);
        }

        $this->getJson('/api/v1/bs/nasabah?q=si')->assertUnprocessable()->assertJsonValidationErrors('q');
    }

    public function test_dashboard_menghitung_data_bank_sendiri(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $bankLain = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();

        foreach ([[$bank, 'jual', 2], [$bank, 'donasi', 3], [$bankLain, 'jual', 10]] as [$b, $tipe, $kg]) {
            Sanctum::actingAs($this->operator($b));
            $this->postJson('/api/v1/bs/setoran', [
                'warga_id' => $warga->id, 'tipe' => $tipe,
                'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => $kg]],
            ])->assertCreated();
        }

        Sanctum::actingAs($this->operator($bank));
        $this->getJson('/api/v1/bs/dashboard')
            ->assertOk()
            ->assertJsonPath('data.hari_ini.jumlah_setoran', 2)
            ->assertJsonPath('data.hari_ini.total_kg', 5)
            ->assertJsonPath('data.hari_ini.kg_donasi', 3)
            ->assertJsonPath('data.hari_ini.total_nilai', 6000)
            ->assertJsonPath('data.bulan_ini.total_kg', 5)
            ->assertJsonPath('data.nasabah.jumlah', 1)
            ->assertJsonPath('data.nasabah.total_saldo', 6000)
            ->assertJsonPath('data.penjemputan.diajukan', 0);

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/v1/bs/dashboard')->assertForbidden();
    }

    public function test_penjualan_pengepul_total_dihitung_dan_terisolasi(): void
    {
        $bankA = $this->bank();
        $bankB = $this->bank();
        Sanctum::actingAs($this->operator($bankA));

        $this->postJson('/api/v1/bs/penjualan-pengepul', [
            'nama_pengepul' => 'CV Daya Murni',
            'jenis_sampah_id' => $this->jenis('Plastik')->id,
            'berat_kg' => 120.5,
            'harga_per_kg' => 3500,
        ])
            ->assertCreated()
            ->assertJsonPath('data.total', 421750)
            ->assertJsonPath('data.tanggal', now()->toDateString());

        $this->postJson('/api/v1/bs/penjualan-pengepul', ['nama_pengepul' => 'X', 'jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 1, 'harga_per_kg' => 1, 'tanggal' => now()->addDay()->toDateString()])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('tanggal');

        Sanctum::actingAs($this->operator($bankB));
        $this->getJson('/api/v1/bs/penjualan-pengepul')->assertOk()->assertJsonCount(0, 'data');

        Sanctum::actingAs($this->warga());
        $this->getJson('/api/v1/bs/penjualan-pengepul')->assertForbidden();
        $this->assertSame(1, PenjualanPengepul::count());
    }
}
