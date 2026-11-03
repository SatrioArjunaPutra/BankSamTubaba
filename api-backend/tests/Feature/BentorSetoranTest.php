<?php

namespace Tests\Feature;

use App\Enums\StatusArmada;
use App\Enums\StatusPenjemputan;
use App\Models\Armada;
use App\Models\BankSampah;
use App\Models\Nasabah;
use App\Models\Penarikan;
use App\Models\Penjemputan;
use App\Models\Setoran;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

class BentorSetoranTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    private const ID = '11111111-1111-4111-8111-111111111111';

    private function tugas(BankSampah $bank, User $warga, Armada $armada, StatusPenjemputan $status = StatusPenjemputan::Diambil): Penjemputan
    {
        $jemput = new Penjemputan(['bank_sampah_id' => $bank->id, 'warga_id' => $warga->id,
            'alamat' => 'Alamat uji', 'lat' => -4.58, 'lng' => 105.13]);
        $jemput->forceFill(['armada_id' => $armada->id, 'status' => $status])->save();

        return $jemput;
    }

    /** @return array<string, mixed> */
    private function isian(float $berat = 2, string $tipe = 'jual'): array
    {
        return ['tipe' => $tipe, 'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => $berat]]];
    }

    public function test_timbangan_bentor_menambah_saldo_dan_menyelesaikan_tugas(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $armada = $this->armada($bank, StatusArmada::Bertugas);
        $tugas = $this->tugas($bank, $warga, $armada);
        Sanctum::actingAs($armada->driver);

        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian(2.5))
            ->assertCreated()
            ->assertJsonPath('status', 'sukses')
            ->assertJsonPath('data.setoran.total_kg', 2.5)
            ->assertJsonPath('data.setoran.total_nilai', 7500)
            ->assertJsonPath('data.setoran.warga_id', $warga->id)
            ->assertJsonPath('data.setoran.penjemputan_id', $tugas->id)
            ->assertJsonPath('data.setoran.dicatat_oleh', $armada->driver_id)
            ->assertJsonPath('data.saldo_sekarang', 7500);

        $this->assertSame(7500.0, $this->saldo($warga, $bank));
        $this->assertSame(StatusPenjemputan::Selesai, $tugas->refresh()->status);
        $this->assertSame(StatusArmada::Siaga, $armada->refresh()->status);
    }

    public function test_isian_warga_dan_harga_dari_aplikasi_diabaikan(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $lain = $this->warga();
        $armada = $this->armada($bank);
        $tugas = $this->tugas($bank, $warga, $armada);
        Sanctum::actingAs($armada->driver);

        $isian = $this->isian();
        $isian['warga_id'] = $lain->id;
        $isian['items'][0]['harga_per_kg'] = 999999;
        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $isian)
            ->assertCreated()
            ->assertJsonPath('data.setoran.warga_id', $warga->id)
            ->assertJsonPath('data.setoran.total_nilai', 6000);

        $this->assertSame(6000.0, $this->saldo($warga, $bank));
        $this->assertDatabaseMissing('nasabah', ['warga_id' => $lain->id]);
    }

    public function test_donasi_oleh_bentor_tidak_menambah_saldo(): void
    {
        $bank = $this->bank();
        $warga = $this->warga();
        $armada = $this->armada($bank);
        $tugas = $this->tugas($bank, $warga, $armada);
        Sanctum::actingAs($armada->driver);

        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian(4, 'donasi'))
            ->assertCreated()
            ->assertJsonPath('data.setoran.total_nilai', 0)
            ->assertJsonPath('data.saldo_sekarang', 0);

        $this->assertSame(0.0, $this->saldo($warga, $bank));
        $this->assertSame(StatusPenjemputan::Selesai, $tugas->refresh()->status);
    }

    public function test_kirim_ulang_tidak_menambah_saldo_dua_kali(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $armada = $this->armada($bank);
        $tugas = $this->tugas($bank, $warga, $armada);
        Sanctum::actingAs($armada->driver);
        $isian = ['request_id' => self::ID, ...$this->isian()];

        $id = $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $isian)->assertCreated()->json('data.setoran.id');
        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $isian)->assertCreated()->assertJsonPath('data.setoran.id', $id);

        $this->assertDatabaseCount('setoran', 1);
        $this->assertSame(6000.0, $this->saldo($warga, $bank));
    }

    public function test_tugas_yang_belum_diambil_atau_sudah_selesai_ditolak(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $armada = $this->armada($bank);
        Sanctum::actingAs($armada->driver);

        foreach ([StatusPenjemputan::Dijadwalkan, StatusPenjemputan::Menuju, StatusPenjemputan::Selesai] as $status) {
            $tugas = $this->tugas($bank, $warga, $armada, $status);
            $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian())->assertUnprocessable();
        }

        $this->assertDatabaseCount('setoran', 0);
        $this->assertSame(0.0, $this->saldo($warga, $bank));
    }

    public function test_bentor_lain_dan_bank_lain_tidak_bisa_mencatat(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $tugas = $this->tugas($bank, $warga, $this->armada($bank));

        Sanctum::actingAs($this->armada($bank)->driver);
        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian())->assertForbidden();

        Sanctum::actingAs($this->armada($this->bank(['Plastik' => 3000]))->driver);
        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian())->assertForbidden();

        $this->assertDatabaseCount('setoran', 0);
    }

    public function test_peran_selain_bentor_ditolak_dan_bentor_tidak_bisa_memakai_rute_operator(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $armada = $this->armada($bank);
        $tugas = $this->tugas($bank, $warga, $armada);

        foreach ([$this->operator($bank), $warga, User::factory()->dlh()->create()] as $akun) {
            Sanctum::actingAs($akun);
            $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian())->assertForbidden();
        }

        Sanctum::actingAs($armada->driver);
        $this->postJson('/api/v1/bs/setoran', ['warga_id' => $warga->id, ...$this->isian()])->assertForbidden();

        $this->assertDatabaseCount('setoran', 0);
    }

    public function test_tanpa_login_ditolak_dan_isian_tidak_sah_ditolak(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $armada = $this->armada($bank);
        $tugas = $this->tugas($bank, $this->warga(), $armada);

        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian())->assertUnauthorized();

        Sanctum::actingAs($armada->driver);
        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian(0))->assertUnprocessable();
        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", ['tipe' => 'jual', 'items' => []])->assertUnprocessable();
        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian(2, 'lain'))->assertUnprocessable();
        $this->assertSame(StatusPenjemputan::Diambil, $tugas->refresh()->status);
    }

    public function test_harga_belum_diatur_ditolak_tanpa_mengubah_tugas(): void
    {
        $bank = $this->bank();
        $armada = $this->armada($bank);
        $tugas = $this->tugas($bank, $this->warga(), $armada);
        Sanctum::actingAs($armada->driver);

        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian())->assertUnprocessable();

        $this->assertSame(StatusPenjemputan::Diambil, $tugas->refresh()->status);
    }

    public function test_bentor_dan_operator_mencatat_tugas_sama_hanya_satu_berlaku(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $armada = $this->armada($bank);
        $tugas = $this->tugas($bank, $warga, $armada);

        Sanctum::actingAs($armada->driver);
        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian())->assertCreated();

        Sanctum::actingAs($this->operator($bank));
        $this->postJson('/api/v1/bs/setoran', ['warga_id' => $warga->id, 'penjemputan_id' => $tugas->id, ...$this->isian()])
            ->assertUnprocessable();

        $this->assertDatabaseCount('setoran', 1);
        $this->assertSame(6000.0, $this->saldo($warga, $bank));
    }

    public function test_operator_lebih_dulu_lalu_bentor_ditolak(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $armada = $this->armada($bank);
        $tugas = $this->tugas($bank, $warga, $armada);

        Sanctum::actingAs($this->operator($bank));
        $this->postJson('/api/v1/bs/setoran', ['warga_id' => $warga->id, 'penjemputan_id' => $tugas->id, ...$this->isian()])
            ->assertCreated();

        Sanctum::actingAs($armada->driver);
        $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian())->assertUnprocessable();

        $this->assertDatabaseCount('setoran', 1);
        $this->assertSame(6000.0, $this->saldo($warga, $bank));
    }

    /** @return array{0: BankSampah, 1: User, 2: int} */
    private function setoranBentor(): array
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $armada = $this->armada($bank);
        $tugas = $this->tugas($bank, $warga, $armada);
        Sanctum::actingAs($armada->driver);
        $id = $this->postJson("/api/v1/bentor/tugas/{$tugas->id}/setoran", $this->isian())->assertCreated()->json('data.setoran.id');

        return [$bank, $warga, $id];
    }

    public function test_operator_membatalkan_setoran_saldo_kembali_dan_bisa_dicatat_ulang(): void
    {
        [$bank, $warga, $id] = $this->setoranBentor();
        $operator = $this->operator($bank);
        Sanctum::actingAs($operator);

        $this->postJson("/api/v1/bs/setoran/{$id}/batal", ['alasan' => 'Salah timbang'])
            ->assertOk()
            ->assertJsonPath('status', 'sukses')
            ->assertJsonPath('data.alasan_batal', 'Salah timbang');

        $this->assertSame(0.0, $this->saldo($warga, $bank));
        $baris = Setoran::denganBatal()->findOrFail($id);
        $this->assertNotNull($baris->dibatalkan_at);
        $this->assertSame($operator->id, $baris->dibatalkan_oleh);

        // Riwayat tetap menampilkan setoran batal dengan alasannya
        $this->getJson('/api/v1/bs/setoran')->assertOk()->assertJsonPath('data.0.alasan_batal', 'Salah timbang');

        $this->postJson('/api/v1/bs/setoran', ['warga_id' => $warga->id, ...$this->isian(1)])->assertCreated();
        $this->assertSame(3000.0, $this->saldo($warga, $bank));
    }

    public function test_pembatalan_dua_kali_tidak_mengurangi_saldo_dua_kali(): void
    {
        [$bank, $warga, $id] = $this->setoranBentor();
        $this->beriSaldo($warga, $bank, 10000);
        Sanctum::actingAs($this->operator($bank));

        $this->postJson("/api/v1/bs/setoran/{$id}/batal", ['alasan' => 'Salah timbang'])->assertOk();
        $this->postJson("/api/v1/bs/setoran/{$id}/batal", ['alasan' => 'Salah timbang'])->assertUnprocessable();

        $this->assertSame(4000.0, $this->saldo($warga, $bank));
    }

    public function test_pembatalan_ditolak_bila_saldo_sudah_ditarik(): void
    {
        [$bank, $warga, $id] = $this->setoranBentor();
        Nasabah::where('warga_id', $warga->id)->where('bank_sampah_id', $bank->id)->update(['saldo' => 1000]);
        Sanctum::actingAs($this->operator($bank));

        $this->postJson("/api/v1/bs/setoran/{$id}/batal", ['alasan' => 'Salah timbang'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('alasan');

        $this->assertSame(1000.0, $this->saldo($warga, $bank));
        $this->assertNull(Setoran::denganBatal()->findOrFail($id)->dibatalkan_at);
    }

    public function test_penarikan_tidak_bisa_memakai_saldo_setoran_batal(): void
    {
        [$bank, $warga, $id] = $this->setoranBentor();
        $penarikan = new Penarikan(['warga_id' => $warga->id, 'bank_sampah_id' => $bank->id, 'jumlah' => 6000]);
        $penarikan->forceFill(['status' => 'diajukan'])->save();
        Sanctum::actingAs($this->operator($bank));

        $this->postJson("/api/v1/bs/setoran/{$id}/batal", ['alasan' => 'Salah timbang'])->assertOk();
        $this->patchJson("/api/v1/bs/penarikan/{$penarikan->id}", ['aksi' => 'setujui'])->assertUnprocessable();

        $this->assertSame(0.0, $this->saldo($warga, $bank));
    }

    public function test_hanya_operator_bank_itu_yang_bisa_membatalkan(): void
    {
        [$bank, $warga, $id] = $this->setoranBentor();

        Sanctum::actingAs($this->operator($this->bank()));
        $this->postJson("/api/v1/bs/setoran/{$id}/batal", ['alasan' => 'Salah timbang'])->assertNotFound();

        foreach ([$warga, $this->armada($bank)->driver, User::factory()->dlh()->create()] as $akun) {
            Sanctum::actingAs($akun);
            $this->postJson("/api/v1/bs/setoran/{$id}/batal", ['alasan' => 'Salah timbang'])->assertForbidden();
        }

        Sanctum::actingAs($this->operator($bank));
        $this->postJson("/api/v1/bs/setoran/{$id}/batal", ['alasan' => ''])->assertUnprocessable();

        $this->assertSame(6000.0, $this->saldo($warga, $bank));
    }

    public function test_setoran_batal_keluar_dari_semua_hitungan_dan_riwayat_warga_tetap_ada(): void
    {
        [$bank, $warga, $id] = $this->setoranBentor();
        $dlh = User::factory()->dlh()->create();

        Sanctum::actingAs($dlh);
        $this->getJson('/api/v1/dlh/transaksi')->assertOk()->assertJsonCount(1, 'data');
        $this->assertEquals(2, collect($this->getJson('/api/v1/dlh/kinerja')->assertOk()->json('data.daftar'))->sum('total_kg'));
        $this->assertEquals(2, $this->getJson('/api/v1/dlh/ringkasan')->assertOk()->json('data.total_kg'));
        $this->assertNotEmpty($this->getJson('/api/v1/dlh/dashboard')->assertOk()->json('data.komposisi'));

        Sanctum::actingAs($this->operator($bank));
        $this->postJson("/api/v1/bs/setoran/{$id}/batal", ['alasan' => 'Salah timbang'])->assertOk();

        Sanctum::actingAs($dlh);
        $this->getJson('/api/v1/dlh/transaksi')->assertOk()->assertJsonCount(0, 'data');
        $this->assertEquals(0, collect($this->getJson('/api/v1/dlh/kinerja')->assertOk()->json('data.daftar'))->sum('total_kg'));
        $this->assertEquals(0, $this->getJson('/api/v1/dlh/ringkasan')->assertOk()->json('data.total_kg'));
        $this->assertEmpty($this->getJson('/api/v1/dlh/dashboard')->assertOk()->json('data.komposisi'));
        $this->getJson('/api/v1/dlh/peta')->assertOk();

        Sanctum::actingAs($this->operator($bank));
        $this->assertEquals(0, $this->getJson('/api/v1/bs/dashboard')->assertOk()->json('data.hari_ini.total_kg'));

        Sanctum::actingAs($warga);
        $this->getJson('/api/v1/warga/setoran')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.alasan_batal', 'Salah timbang');
    }
}
