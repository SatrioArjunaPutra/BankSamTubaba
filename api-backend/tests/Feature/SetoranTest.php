<?php

namespace Tests\Feature;

use App\Models\HargaSampah;
use App\Models\Nasabah;
use App\Models\Setoran;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

class SetoranTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    public function test_setoran_jual_menambah_saldo_sesuai_harga_bank_itu(): void
    {
        $bankA = $this->bank(['Plastik' => 3000, 'Kardus' => 2000]);
        $bankB = $this->bank(['Plastik' => 5000]);
        $warga = $this->warga();

        Sanctum::actingAs($this->operator($bankA));
        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id,
            'tipe' => 'jual',
            'items' => [
                ['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2.5],
                ['jenis_sampah_id' => $this->jenis('Kardus')->id, 'berat_kg' => 1.25],
            ],
        ])
            ->assertCreated()
            ->assertJsonPath('data.setoran.total_kg', 3.75)
            ->assertJsonPath('data.setoran.total_nilai', 10000)
            ->assertJsonPath('data.setoran.items.0.harga_per_kg', 3000)
            ->assertJsonPath('data.setoran.items.0.subtotal', 7500)
            ->assertJsonPath('data.saldo_sekarang', 10000);

        Sanctum::actingAs($this->operator($bankB));
        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id,
            'tipe' => 'jual',
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2.5]],
        ])->assertCreated()->assertJsonPath('data.saldo_sekarang', 12500);

        // Saldo terpisah per bank sampah
        $this->assertSame(10000.0, $this->saldo($warga, $bankA));
        $this->assertSame(12500.0, $this->saldo($warga, $bankB));

        Sanctum::actingAs($warga);
        $this->getJson('/api/v1/warga/saldo')
            ->assertOk()
            ->assertJsonPath('data.total_saldo', 22500)
            ->assertJsonCount(2, 'data.daftar');
    }

    public function test_donasi_tercatat_tapi_tidak_menambah_saldo(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        Sanctum::actingAs($this->operator($bank));

        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id,
            'tipe' => 'donasi',
            'items' => [
                ['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 4],
                // Jenis tanpa harga di bank ini tetap boleh untuk donasi
                ['jenis_sampah_id' => $this->jenis('Minyak Jelantah')->id, 'berat_kg' => 1],
            ],
        ])
            ->assertCreated()
            ->assertJsonPath('pesan', 'Donasi sampah berhasil dicatat.')
            ->assertJsonPath('data.setoran.tipe', 'donasi')
            ->assertJsonPath('data.setoran.total_kg', 5)
            ->assertJsonPath('data.setoran.total_nilai', 0)
            ->assertJsonPath('data.saldo_sekarang', 0);

        // Rekening nasabah tetap dibuat (dihitung sebagai nasabah bank ini)
        $this->assertSame(1, Nasabah::count());
        $this->assertSame(0.0, $this->saldo($warga, $bank));
    }

    public function test_harga_berubah_tidak_mengubah_setoran_lama(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        Sanctum::actingAs($this->operator($bank));

        $id = $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id,
            'tipe' => 'jual',
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2]],
        ])->json('data.setoran.id');

        $this->putJson('/api/v1/bs/harga', ['harga' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'harga_per_kg' => 9000]]])
            ->assertOk();

        $lama = Setoran::with('items')->find($id);
        $this->assertSame(6000.0, (float) $lama->total_nilai);
        $this->assertSame(3000.0, (float) $lama->items[0]->harga_per_kg);
        $this->assertSame(6000.0, $this->saldo($warga, $bank));

        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id,
            'tipe' => 'jual',
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2]],
        ])->assertJsonPath('data.setoran.total_nilai', 18000);
    }

    public function test_jual_jenis_tanpa_harga_ditolak(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        Sanctum::actingAs($this->operator($bank));

        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $this->warga()->id,
            'tipe' => 'jual',
            'items' => [['jenis_sampah_id' => $this->jenis('Logam')->id, 'berat_kg' => 1]],
        ])
            ->assertUnprocessable()
            ->assertJsonPath('errors', ['items.0.jenis_sampah_id' => ['Harga Logam belum diatur di bank sampah ini.']]);

        $this->assertSame(0, Setoran::count());
    }

    public function test_validasi_setoran(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $operator = $this->operator($bank);
        Sanctum::actingAs($operator);
        $plastik = $this->jenis('Plastik')->id;

        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $operator->id,
            'tipe' => 'hibah',
            'items' => [
                ['jenis_sampah_id' => $plastik, 'berat_kg' => 1.005],
                ['jenis_sampah_id' => $plastik, 'berat_kg' => 0],
            ],
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['warga_id', 'tipe', 'items.0.berat_kg', 'items.1.berat_kg', 'items.0.jenis_sampah_id'])
            ->assertJsonPath('errors.warga_id.0', 'Warga tidak ditemukan.');
    }

    public function test_operator_hanya_melihat_setoran_bank_sendiri(): void
    {
        $bankA = $this->bank(['Plastik' => 3000]);
        $bankB = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();

        foreach ([$bankA, $bankB] as $bank) {
            Sanctum::actingAs($this->operator($bank));
            $this->postJson('/api/v1/bs/setoran', [
                'warga_id' => $warga->id,
                'tipe' => 'jual',
                'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 1]],
            ])->assertCreated();
        }

        $response = $this->getJson('/api/v1/bs/setoran')->assertOk()->assertJsonCount(1, 'data');
        $this->assertSame($bankB->id, $response->json('data.0.bank_sampah_id'));

        Sanctum::actingAs($warga);
        $this->getJson('/api/v1/warga/setoran')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson("/api/v1/warga/setoran?bank_sampah_id={$bankA->id}")->assertJsonCount(1, 'data');
    }

    public function test_buka_rekening_saat_sudah_dibuat_setoran_bersamaan_tidak_merusak_transaksi(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $service = app(\App\Services\SetoranService::class);

        \Illuminate\Support\Facades\DB::transaction(function () use ($service, $warga, $bank) {
            // Setoran lain (pemenang balapan) sudah membuat rekening ini lebih dulu
            Nasabah::create(['warga_id' => $warga->id, 'bank_sampah_id' => $bank->id]);

            // Yang kalah mencoba INSERT yang sama: harus diam, bukan 500
            $service->bukaRekening($warga->id, $bank->id);

            // Transaksi luar masih bisa dipakai (di PostgreSQL ini gagal tanpa savepoint)
            $this->assertSame(1, Nasabah::where('warga_id', $warga->id)->count());
        });

        // Setoran berikutnya memakai rekening yang sama
        Sanctum::actingAs($this->operator($bank));
        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id,
            'tipe' => 'jual',
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 1]],
        ])->assertCreated()->assertJsonPath('data.saldo_sekarang', 3000);
        $this->assertSame(1, Nasabah::count());
    }

    public function test_warga_tidak_boleh_mencatat_setoran(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        Sanctum::actingAs($warga);

        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id,
            'tipe' => 'jual',
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 100]],
        ])->assertForbidden();

        $this->assertSame(0, Setoran::count());
        $this->assertSame(0, HargaSampah::where('bank_sampah_id', '!=', $bank->id)->count());
    }
}
