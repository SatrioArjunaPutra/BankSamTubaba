<?php

namespace Tests\Feature;

use App\Models\Pemberitahuan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\Concerns\MembuatPreloved;
use Tests\TestCase;

class PemberitahuanTest extends TestCase
{
    use MembuatDataBankSampah, MembuatPreloved, RefreshDatabase;

    /**
     * @return array<int, string>
     */
    private function jenisUntuk(User $user): array
    {
        return Pemberitahuan::where('user_id', $user->id)->orderBy('id')->pluck('jenis')->all();
    }

    public function test_alur_jemput_mengabari_warga_pengelola_dan_bentor_yang_tepat(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $armada = $this->armada($bank);
        $bentor = $armada->driver;
        $pengelola = $this->operator($bank);
        $pengelolaLain = $this->operator($this->bank());
        $warga = User::factory()->warga()->create(['name' => 'Siti']);

        Sanctum::actingAs($warga);
        $id = $this->postJson('/api/v1/warga/penjemputan', [
            'bank_sampah_id' => $bank->id, 'alamat' => 'Jl. Melati 1', 'lat' => -4.58, 'lng' => 105.13,
        ])->assertCreated()->json('data.id');

        $baru = Pemberitahuan::where('user_id', $pengelola->id)->sole();
        $this->assertSame('Siti minta dijemput di Jl. Melati 1.', $baru->isi);
        $this->assertSame(['penjemputan' => $id], $baru->tujuan);
        $this->assertSame([], $this->jenisUntuk($pengelolaLain));

        Sanctum::actingAs($pengelola);
        $this->patchJson("/api/v1/bs/penjemputan/{$id}", [
            'aksi' => 'jadwalkan', 'armada_id' => $armada->id, 'jadwal_at' => '2026-11-20T02:30:00Z',
        ])->assertOk();

        $jadwal = Pemberitahuan::where('user_id', $warga->id)->sole();
        $this->assertStringContainsString('20 November 2026, 09.30 WIB', $jadwal->isi);
        $this->assertStringContainsString($armada->plat_nomor, $jadwal->isi);
        $this->assertSame(['tugas_baru'], $this->jenisUntuk($bentor));

        Sanctum::actingAs($bentor);
        $this->patchJson("/api/v1/bentor/tugas/{$id}/status", ['status' => 'menuju'])->assertOk();
        $this->patchJson("/api/v1/bentor/tugas/{$id}/status", ['status' => 'diambil'])->assertOk();
        $this->postJson("/api/v1/bentor/tugas/{$id}/setoran", [
            'tipe' => 'jual', 'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2.5]],
        ])->assertCreated();

        $this->assertSame(
            ['jemput_dijadwalkan', 'jemput_menuju', 'jemput_diambil', 'setoran_tercatat'],
            $this->jenisUntuk($warga),
        );
        $tercatat = Pemberitahuan::where('user_id', $warga->id)->where('jenis', 'setoran_tercatat')->sole();
        $this->assertStringStartsWith('+Rp 7.500 dari 2,5 kg sampah', $tercatat->isi);
        $this->assertStringEndsWith('Saldomu kini Rp 7.500.', $tercatat->isi);
        $this->assertSame(['jemput_baru', 'timbang_bentor'], $this->jenisUntuk($pengelola));
        $this->assertSame([], $this->jenisUntuk($pengelolaLain));
    }

    public function test_penolakan_jemput_menyertakan_alasan(): void
    {
        $bank = $this->bank();
        $warga = $this->warga();
        Sanctum::actingAs($warga);
        $id = $this->postJson('/api/v1/warga/penjemputan', [
            'bank_sampah_id' => $bank->id, 'alamat' => 'Jl. Melati 1', 'lat' => -4.58, 'lng' => 105.13,
        ])->json('data.id');

        Sanctum::actingAs($this->operator($bank));
        $this->patchJson("/api/v1/bs/penjemputan/{$id}", ['aksi' => 'tolak', 'alasan' => 'Di luar wilayah layanan'])->assertOk();

        $this->assertSame('Alasan: Di luar wilayah layanan', Pemberitahuan::where('user_id', $warga->id)->sole()->isi);
    }

    public function test_setoran_donasi_dan_pembatalan_dikabarkan_ke_warga(): void
    {
        $bank = $this->bank(['Plastik' => 2000]);
        $warga = $this->warga();
        Sanctum::actingAs($this->operator($bank));

        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id, 'tipe' => 'donasi',
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 3]],
        ])->assertCreated();
        $setoranId = $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id, 'tipe' => 'jual',
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2]],
        ])->assertCreated()->json('data.setoran.id');
        $this->postJson("/api/v1/bs/setoran/{$setoranId}/batal", ['alasan' => 'Salah timbang'])->assertOk();

        $this->assertSame(['donasi_diterima', 'setoran_tercatat', 'setoran_dibatalkan'], $this->jenisUntuk($warga));
        $batal = Pemberitahuan::where('user_id', $warga->id)->where('jenis', 'setoran_dibatalkan')->sole();
        $this->assertSame('Setoran 2 kg dibatalkan petugas. Alasan: Salah timbang Saldo dikurangi Rp 4.000.', $batal->isi);
    }

    public function test_penarikan_dikabarkan_dan_gagal_tidak_meninggalkan_pemberitahuan(): void
    {
        $bank = $this->bank();
        $warga = $this->warga();
        $this->beriSaldo($warga, $bank, 10000);
        $pengelola = $this->operator($bank);

        Sanctum::actingAs($warga);
        $id = $this->postJson('/api/v1/warga/penarikan', ['password' => 'password', 'bank_sampah_id' => $bank->id, 'jumlah' => 4000])
            ->assertCreated()->json('data.id');
        $this->assertSame(['penarikan_baru'], $this->jenisUntuk($pengelola));

        // Saldo habis sebelum disetujui: transaksi gagal, warga tidak menerima kabar
        $this->beriSaldo($warga, $bank, 1000);
        Sanctum::actingAs($pengelola);
        $this->patchJson("/api/v1/bs/penarikan/{$id}", ['aksi' => 'setujui'])->assertUnprocessable();
        $this->assertSame([], $this->jenisUntuk($warga));

        $this->patchJson("/api/v1/bs/penarikan/{$id}", ['aksi' => 'tolak', 'catatan' => 'Saldo tidak cukup'])->assertOk();
        $tolak = Pemberitahuan::where('user_id', $warga->id)->sole();
        $this->assertSame('penarikan_ditolak', $tolak->jenis);
        $this->assertSame('Penarikan Rp 4.000 ditolak. Saldo tidak cukup', $tolak->isi);
    }

    public function test_barang_disembunyikan_dlh_dikabarkan_ke_penjual(): void
    {
        $penjual = $this->warga();
        $barang = $this->barang($penjual);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->patchJson("/api/v1/dlh/preloved/{$barang->id}", ['status' => 'disembunyikan'])->assertOk();

        $this->assertSame(['barang_disembunyikan'], $this->jenisUntuk($penjual));
    }

    public function test_pengguna_hanya_melihat_dan_menandai_pemberitahuan_sendiri(): void
    {
        $saya = $this->warga();
        $lain = $this->warga();
        $punyaSaya = Pemberitahuan::create(['user_id' => $saya->id, 'jenis' => 'uji', 'judul' => 'A', 'isi' => 'a']);
        Pemberitahuan::create(['user_id' => $saya->id, 'jenis' => 'uji', 'judul' => 'B', 'isi' => 'b']);
        $punyaLain = Pemberitahuan::create(['user_id' => $lain->id, 'jenis' => 'uji', 'judul' => 'C', 'isi' => 'c']);
        Sanctum::actingAs($saya);

        $this->getJson('/api/v1/pemberitahuan')->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.judul', 'B')
            ->assertJsonPath('data.0.dibaca', false);
        $this->getJson('/api/v1/pemberitahuan/belum-dibaca')->assertOk()->assertJsonPath('data.jumlah', 2);

        $this->postJson("/api/v1/pemberitahuan/{$punyaLain->id}/baca")->assertNotFound();
        $this->assertNull($punyaLain->refresh()->dibaca_at);

        $this->postJson("/api/v1/pemberitahuan/{$punyaSaya->id}/baca")->assertOk()->assertJsonPath('data.dibaca', true);
        $this->getJson('/api/v1/pemberitahuan/belum-dibaca')->assertJsonPath('data.jumlah', 1);

        $this->postJson('/api/v1/pemberitahuan/baca-semua')->assertOk()->assertJsonPath('data.jumlah', 1);
        $this->getJson('/api/v1/pemberitahuan/belum-dibaca')->assertJsonPath('data.jumlah', 0);
        $this->assertNull($punyaLain->refresh()->dibaca_at);
    }

    public function test_pemberitahuan_lama_dihapus_otomatis(): void
    {
        $warga = $this->warga();
        $lama = Pemberitahuan::create(['user_id' => $warga->id, 'jenis' => 'uji', 'judul' => 'Lama', 'isi' => 'x']);
        $lama->forceFill(['created_at' => now()->subDays(91)])->save();
        $baru = Pemberitahuan::create(['user_id' => $warga->id, 'jenis' => 'uji', 'judul' => 'Baru', 'isi' => 'y']);

        $this->artisan('model:prune', ['--model' => [Pemberitahuan::class]])->assertSuccessful();

        $this->assertModelMissing($lama);
        $this->assertModelExists($baru);
    }

    public function test_tamu_tidak_bisa_membaca_pemberitahuan(): void
    {
        $this->getJson('/api/v1/pemberitahuan')->assertUnauthorized();
        $this->getJson('/api/v1/pemberitahuan/belum-dibaca')->assertUnauthorized();
    }
}
