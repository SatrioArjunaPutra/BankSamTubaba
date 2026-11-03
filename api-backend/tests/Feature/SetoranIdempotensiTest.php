<?php

namespace Tests\Feature;

use App\Enums\StatusPenjemputan;
use App\Models\HargaSampah;
use App\Models\Penjemputan;
use App\Models\Setoran;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

class SetoranIdempotensiTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    private const ID = '94dc7ac7-a3fa-4d20-aacb-2825ec10b1d3';

    public function test_retry_mengembalikan_hasil_asli_walau_saldo_dan_harga_sudah_berubah(): void
    {
        $bank = $this->bank(['Plastik' => 3000, 'Kardus' => 2000]);
        $warga = $this->warga();
        Sanctum::actingAs($this->operator($bank));
        $data = [
            'request_id' => self::ID, 'warga_id' => $warga->id, 'tipe' => 'jual',
            'items' => [
                ['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2],
                ['jenis_sampah_id' => $this->jenis('Kardus')->id, 'berat_kg' => 1],
            ],
            'saldo_setelah' => 999999, 'request_hash' => 'nilai dari klien tidak boleh dipercaya',
        ];
        $awal = $this->postJson('/api/v1/bs/setoran', $data)->assertCreated()
            ->assertJsonPath('data.saldo_sekarang', 8000);
        $lain = [...$data, 'request_id' => '94dc7ac7-a3fa-4d20-aacb-2825ec10b1d4'];
        $this->postJson('/api/v1/bs/setoran', $lain)->assertCreated();
        HargaSampah::where('bank_sampah_id', $bank->id)->update(['harga_per_kg' => 9000]);
        $this->jenis('Plastik')->update(['is_aktif' => false]);
        $warga->update(['is_aktif' => false]);
        $data['items'] = array_reverse($data['items']);
        $data['items'][0]['berat_kg'] = '1.00';
        $data['request_id'] = strtoupper(self::ID);

        $this->postJson('/api/v1/bs/setoran', $data)->assertCreated()
            ->assertJsonPath('data', $awal->json('data'));

        $this->assertDatabaseCount('setoran', 2);
        $this->assertSame(16000.0, $this->saldo($warga, $bank));
    }

    public static function rincianBerubah(): array
    {
        return ['berat' => ['berat'], 'warga' => ['warga'], 'tipe' => ['tipe'], 'catatan' => ['catatan'], 'jemput' => ['jemput']];
    }

    #[DataProvider('rincianBerubah')]
    public function test_id_lama_dengan_rincian_berbeda_ditolak_422_tanpa_mutasi_saldo(string $ubah): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        Sanctum::actingAs($this->operator($bank));
        $data = ['request_id' => self::ID, 'warga_id' => $warga->id, 'tipe' => 'jual',
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2]]];
        $this->postJson('/api/v1/bs/setoran', $data)->assertCreated();
        match ($ubah) {
            'berat' => $data['items'][0]['berat_kg'] = 3,
            'warga' => $data['warga_id'] = $this->warga()->id,
            'tipe' => $data['tipe'] = 'donasi',
            'catatan' => $data['catatan'] = 'Rincian baru',
            'jemput' => $data['penjemputan_id'] = 9999,
        };

        $this->postJson('/api/v1/bs/setoran', $data)->assertUnprocessable()
            ->assertJsonValidationErrors('request_id');

        $this->assertDatabaseCount('setoran', 1);
        $this->assertSame(6000.0, $this->saldo($warga, $bank));
    }

    public function test_id_yang_sama_terisolasi_antaroperator_dan_bank(): void
    {
        $warga = $this->warga();
        $bankA = $this->bank(['Plastik' => 3000]);
        $bankB = $this->bank(['Plastik' => 5000]);
        $data = ['request_id' => self::ID, 'warga_id' => $warga->id, 'tipe' => 'jual',
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2]]];
        Sanctum::actingAs($this->operator($bankA));
        $id = $this->postJson('/api/v1/bs/setoran', $data)->assertCreated()->json('data.setoran.id');

        Sanctum::actingAs($this->operator($bankB));
        $this->postJson('/api/v1/bs/setoran', $data)->assertCreated()
            ->assertJsonPath('data.setoran.bank_sampah_id', $bankB->id)
            ->assertJsonPath('data.saldo_sekarang', 10000);

        $this->assertDatabaseCount('setoran', 2);
        $this->assertSame(6000.0, $this->saldo($warga, $bankA));
        $this->assertSame($bankA->id, Setoran::findOrFail($id)->bank_sampah_id);
    }

    public function test_retry_setoran_jemput_yang_sudah_selesai_tetap_mengembalikan_setoran_lama(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $armada = $this->armada($bank);
        $jemput = new Penjemputan(['bank_sampah_id' => $bank->id, 'warga_id' => $warga->id,
            'alamat' => 'Alamat uji', 'lat' => -4.58, 'lng' => 105.13]);
        $jemput->forceFill(['armada_id' => $armada->id, 'status' => StatusPenjemputan::Diambil])->save();
        Sanctum::actingAs($this->operator($bank));
        $data = ['request_id' => self::ID, 'warga_id' => $warga->id, 'tipe' => 'jual', 'penjemputan_id' => $jemput->id,
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2]]];
        $id = $this->postJson('/api/v1/bs/setoran', $data)->assertCreated()->json('data.setoran.id');

        $this->postJson('/api/v1/bs/setoran', $data)->assertCreated()->assertJsonPath('data.setoran.id', $id);

        $this->assertSame(StatusPenjemputan::Selesai, $jemput->refresh()->status);
        $this->assertDatabaseCount('setoran', 1);
        $this->assertSame(6000.0, $this->saldo($warga, $bank));
    }

    public function test_uuid_tidak_valid_dan_request_tanpa_autentikasi_ditolak(): void
    {
        $this->postJson('/api/v1/bs/setoran', ['request_id' => self::ID])->assertUnauthorized();
        $bank = $this->bank(['Plastik' => 3000]);
        Sanctum::actingAs($this->operator($bank));

        $this->postJson('/api/v1/bs/setoran', ['request_id' => 'bukan-uuid'])->assertUnprocessable()
            ->assertJsonValidationErrors('request_id');

        $this->assertDatabaseCount('setoran', 0);
    }
}
