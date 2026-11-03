<?php

namespace Tests\Feature;

use App\Models\Penarikan;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

class PenarikanTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    public function test_penarikan_melebihi_saldo_ditolak(): void
    {
        $bank = $this->bank();
        $warga = $this->warga();
        $this->beriSaldo($warga, $bank, 10000);
        Sanctum::actingAs($warga);

        $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bank->id, 'jumlah' => 10000.01])
            ->assertUnprocessable()
            ->assertJsonPath('errors.jumlah.0', 'Saldo tidak mencukupi. Saldo Anda di bank sampah ini Rp 10.000.');

        // Saldo di bank lain tidak bisa dipakai
        $bankLain = $this->bank();
        $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bankLain->id, 'jumlah' => 5000])
            ->assertUnprocessable();

        $this->assertSame(0, Penarikan::count());
    }

    public function test_pengajuan_tidak_mengurangi_saldo_dan_dua_diajukan_ditolak(): void
    {
        $bank = $this->bank();
        $warga = $this->warga();
        $this->beriSaldo($warga, $bank, 10000);
        Sanctum::actingAs($warga);

        $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bank->id, 'jumlah' => 4000])
            ->assertCreated()
            ->assertJsonPath('data.status', 'diajukan')
            ->assertJsonPath('data.jumlah', 4000);

        $this->assertSame(10000.0, $this->saldo($warga, $bank));

        $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bank->id, 'jumlah' => 1000])
            ->assertUnprocessable()
            ->assertJsonPath('errors.jumlah.0', 'Masih ada penarikan yang menunggu persetujuan di bank sampah ini.');

        $this->getJson('/api/v1/warga/penarikan')->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_disetujui_mengurangi_saldo_dan_tidak_bisa_diproses_ulang(): void
    {
        $bank = $this->bank();
        $warga = $this->warga();
        $this->beriSaldo($warga, $bank, 10000);
        Sanctum::actingAs($warga);
        $id = $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bank->id, 'jumlah' => 4000.5])->json('data.id');

        $operator = $this->operator($bank);
        Sanctum::actingAs($operator);
        $this->patchJson("/api/v1/bs/penarikan/{$id}", ['aksi' => 'setujui', 'catatan' => 'Tunai'])
            ->assertOk()
            ->assertJsonPath('data.status', 'disetujui')
            ->assertJsonPath('data.diproses_oleh', $operator->id);

        $this->assertSame(5999.5, $this->saldo($warga, $bank));

        $this->patchJson("/api/v1/bs/penarikan/{$id}", ['aksi' => 'setujui'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.aksi.0', 'Penarikan ini sudah disetujui.');
        $this->assertSame(5999.5, $this->saldo($warga, $bank));
    }

    public function test_saldo_dicek_ulang_saat_disetujui(): void
    {
        $bank = $this->bank();
        $warga = $this->warga();
        $nasabah = $this->beriSaldo($warga, $bank, 10000);
        Sanctum::actingAs($warga);
        $id = $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bank->id, 'jumlah' => 8000])->json('data.id');

        // Saldo turun setelah pengajuan (mis. koreksi), persetujuan harus gagal
        $nasabah->forceFill(['saldo' => 5000])->save();

        Sanctum::actingAs($this->operator($bank));
        $this->patchJson("/api/v1/bs/penarikan/{$id}", ['aksi' => 'setujui'])->assertUnprocessable();

        $this->assertSame(5000.0, $this->saldo($warga, $bank));
        $this->assertSame('diajukan', Penarikan::find($id)->status->value);
    }

    public function test_ditolak_tidak_mengubah_saldo_dan_warga_boleh_mengajukan_lagi(): void
    {
        $bank = $this->bank();
        $warga = $this->warga();
        $this->beriSaldo($warga, $bank, 10000);
        Sanctum::actingAs($warga);
        $id = $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bank->id, 'jumlah' => 3000])->json('data.id');

        Sanctum::actingAs($this->operator($bank));
        $this->patchJson("/api/v1/bs/penarikan/{$id}", ['aksi' => 'tolak', 'catatan' => 'Kas kosong'])
            ->assertOk()
            ->assertJsonPath('data.status', 'ditolak');
        $this->assertSame(10000.0, $this->saldo($warga, $bank));

        Sanctum::actingAs($warga);
        $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bank->id, 'jumlah' => 3000])->assertCreated();
    }

    public function test_operator_bank_lain_tidak_bisa_melihat_atau_memproses(): void
    {
        $bankA = $this->bank();
        $bankB = $this->bank();
        $warga = $this->warga();
        $this->beriSaldo($warga, $bankA, 10000);
        Sanctum::actingAs($warga);
        $id = $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bankA->id, 'jumlah' => 3000])->json('data.id');

        Sanctum::actingAs($this->operator($bankB));
        $this->getJson('/api/v1/bs/penarikan')->assertOk()->assertJsonCount(0, 'data');
        $this->patchJson("/api/v1/bs/penarikan/{$id}", ['aksi' => 'setujui'])->assertForbidden();

        $this->assertSame(10000.0, $this->saldo($warga, $bankA));
        $this->assertSame('diajukan', Penarikan::find($id)->status->value);

        Sanctum::actingAs($this->operator($bankA));
        $this->getJson('/api/v1/bs/penarikan?status=diajukan')->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_tidak_bisa_mengajukan_ke_bank_sampah_nonaktif(): void
    {
        $bank = $this->bank();
        $warga = $this->warga();
        $this->beriSaldo($warga, $bank, 10000);
        $bank->update(['is_aktif' => false]);
        Sanctum::actingAs($warga);

        $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bank->id, 'jumlah' => 1000])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('bank_sampah_id');
        $this->assertSame(0, Penarikan::count());
    }

    public function test_bukan_warga_tidak_bisa_mengajukan(): void
    {
        $bank = $this->bank();
        Sanctum::actingAs($this->operator($bank));

        $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bank->id, 'jumlah' => 1000])->assertForbidden();
    }
}
