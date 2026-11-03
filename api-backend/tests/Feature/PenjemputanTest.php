<?php

namespace Tests\Feature;

use App\Enums\StatusArmada;
use App\Models\Armada;
use App\Models\Penjemputan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

class PenjemputanTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    private function ajukan(User $warga, int $bankId, array $ubah = []): int
    {
        Sanctum::actingAs($warga);

        return $this->postJson('/api/v1/warga/penjemputan', $ubah + [
            'bank_sampah_id' => $bankId,
            'alamat' => 'Jl. Melati 1',
            'lat' => -4.58,
            'lng' => 105.13,
            'perkiraan_kg' => 5,
        ])->assertCreated()->json('data.id');
    }

    private function bentorDari(Armada $armada): User
    {
        return $armada->driver;
    }

    public function test_alur_lengkap_sampai_setoran_selesai(): void
    {
        Storage::fake('public');
        $bank = $this->bank(['Plastik' => 3000]);
        $armada = $this->armada($bank);
        $warga = $this->warga();

        Sanctum::actingAs($warga);
        $id = $this->postJson('/api/v1/warga/penjemputan', [
            'bank_sampah_id' => $bank->id,
            'alamat' => 'Jl. Melati 1',
            'lat' => -4.58,
            'lng' => 105.13,
            'foto' => UploadedFile::fake()->image('sampah.jpg'),
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'diajukan')
            ->json('data.id');

        $foto = Penjemputan::find($id)->foto_path;
        Storage::disk('public')->assertExists($foto);
        $this->assertStringStartsWith('penjemputan/', $foto);

        Sanctum::actingAs($this->operator($bank));
        $this->patchJson("/api/v1/bs/penjemputan/{$id}", [
            'aksi' => 'jadwalkan',
            'armada_id' => $armada->id,
            'jadwal_at' => now()->addHour()->toIso8601String(),
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'dijadwalkan')
            ->assertJsonPath('data.armada.plat_nomor', $armada->plat_nomor);

        Sanctum::actingAs($this->bentorDari($armada));
        $this->getJson('/api/v1/bentor/tugas')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.warga.phone', $warga->phone);
        $this->patchJson("/api/v1/bentor/tugas/{$id}/status", ['status' => 'menuju'])->assertOk()->assertJsonPath('data.status', 'menuju');
        $this->assertSame(StatusArmada::Bertugas, $armada->fresh()->status);
        $this->patchJson("/api/v1/bentor/tugas/{$id}/status", ['status' => 'diambil'])->assertOk()->assertJsonPath('data.status', 'diambil');

        Sanctum::actingAs($this->operator($bank));
        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id,
            'tipe' => 'jual',
            'penjemputan_id' => $id,
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 4]],
        ])->assertCreated()->assertJsonPath('data.setoran.penjemputan_id', $id);

        $selesai = Penjemputan::find($id);
        $this->assertSame('selesai', $selesai->status->value);
        $this->assertNotNull($selesai->selesai_at);
        $this->assertSame(StatusArmada::Siaga, $armada->fresh()->status);
        $this->assertSame(12000.0, $this->saldo($warga, $bank));

        // Satu penjemputan hanya menghasilkan satu setoran
        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id,
            'tipe' => 'jual',
            'penjemputan_id' => $id,
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 4]],
        ])->assertUnprocessable()->assertJsonValidationErrors('penjemputan_id');
        $this->assertSame(12000.0, $this->saldo($warga, $bank));
    }

    public function test_transisi_status_tidak_sah_ditolak_422(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $armada = $this->armada($bank);
        $warga = $this->warga();
        $id = $this->ajukan($warga, $bank->id);
        $bentor = $this->bentorDari($armada);
        $operator = $this->operator($bank);

        // Setoran belum boleh dicatat saat masih diajukan
        Sanctum::actingAs($operator);
        $this->postJson('/api/v1/bs/setoran', [
            'warga_id' => $warga->id, 'tipe' => 'jual', 'penjemputan_id' => $id,
            'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 1]],
        ])->assertUnprocessable();

        $this->patchJson("/api/v1/bs/penjemputan/{$id}", ['aksi' => 'jadwalkan', 'armada_id' => $armada->id, 'jadwal_at' => now()->toIso8601String()])->assertOk();
        $this->patchJson("/api/v1/bs/penjemputan/{$id}", ['aksi' => 'jadwalkan', 'armada_id' => $armada->id, 'jadwal_at' => now()->toIso8601String()])
            ->assertUnprocessable()
            ->assertJsonPath('errors.status.0', 'Penjemputan berstatus dijadwalkan tidak bisa diubah menjadi dijadwalkan.');
        $this->patchJson("/api/v1/bs/penjemputan/{$id}", ['aksi' => 'tolak', 'alasan' => 'x'])->assertUnprocessable();

        // Bentor tidak bisa melompat ke diambil
        Sanctum::actingAs($bentor);
        $this->patchJson("/api/v1/bentor/tugas/{$id}/status", ['status' => 'diambil'])->assertUnprocessable();

        // Warga tidak bisa membatalkan setelah dijadwalkan
        Sanctum::actingAs($warga);
        $this->postJson("/api/v1/warga/penjemputan/{$id}/batal")->assertUnprocessable();

        // Status di luar pilihan bentor
        Sanctum::actingAs($bentor);
        $this->patchJson("/api/v1/bentor/tugas/{$id}/status", ['status' => 'selesai'])->assertUnprocessable()->assertJsonValidationErrors('status');

        $this->assertSame('dijadwalkan', Penjemputan::find($id)->status->value);
    }

    public function test_warga_batal_dan_operator_tolak(): void
    {
        $bank = $this->bank();
        $warga = $this->warga();
        $id1 = $this->ajukan($warga, $bank->id);
        $id2 = $this->ajukan($warga, $bank->id);

        $this->postJson("/api/v1/warga/penjemputan/{$id1}/batal")->assertOk()->assertJsonPath('data.status', 'dibatalkan');

        Sanctum::actingAs($this->operator($bank));
        $this->patchJson("/api/v1/bs/penjemputan/{$id2}", ['aksi' => 'tolak'])->assertUnprocessable()->assertJsonValidationErrors('alasan');
        $this->patchJson("/api/v1/bs/penjemputan/{$id2}", ['aksi' => 'tolak', 'alasan' => 'Di luar jangkauan'])
            ->assertOk()
            ->assertJsonPath('data.status', 'ditolak')
            ->assertJsonPath('data.alasan_tolak', 'Di luar jangkauan');

        Sanctum::actingAs($warga);
        $this->getJson('/api/v1/warga/penjemputan?status=ditolak')->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_warga_tidak_bisa_membatalkan_milik_orang_lain(): void
    {
        $bank = $this->bank();
        $id = $this->ajukan($this->warga(), $bank->id);

        Sanctum::actingAs($this->warga());
        $this->postJson("/api/v1/warga/penjemputan/{$id}/batal")->assertForbidden();
        $this->assertSame('diajukan', Penjemputan::find($id)->status->value);
    }

    public function test_operator_bank_lain_tidak_bisa_melihat_atau_menjadwalkan(): void
    {
        $bankA = $this->bank();
        $bankB = $this->bank();
        $armadaB = $this->armada($bankB);
        $id = $this->ajukan($this->warga(), $bankA->id);

        Sanctum::actingAs($this->operator($bankB));
        $this->getJson('/api/v1/bs/penjemputan')->assertOk()->assertJsonCount(0, 'data');
        $this->patchJson("/api/v1/bs/penjemputan/{$id}", ['aksi' => 'jadwalkan', 'armada_id' => $armadaB->id, 'jadwal_at' => now()->toIso8601String()])
            ->assertForbidden();

        $this->assertSame('diajukan', Penjemputan::find($id)->status->value);
    }

    public function test_tidak_bisa_menugaskan_armada_bank_lain_atau_nonaktif(): void
    {
        $bankA = $this->bank();
        $armadaB = $this->armada($this->bank());
        $armadaNonaktif = $this->armada($bankA, StatusArmada::Nonaktif);
        $id = $this->ajukan($this->warga(), $bankA->id);

        Sanctum::actingAs($this->operator($bankA));
        $this->patchJson("/api/v1/bs/penjemputan/{$id}", ['aksi' => 'jadwalkan', 'armada_id' => $armadaB->id, 'jadwal_at' => now()->toIso8601String()])
            ->assertUnprocessable()
            ->assertJsonPath('errors.armada_id.0', 'Armada tidak ditemukan di bank sampah ini.');
        $this->patchJson("/api/v1/bs/penjemputan/{$id}", ['aksi' => 'jadwalkan', 'armada_id' => $armadaNonaktif->id, 'jadwal_at' => now()->toIso8601String()])
            ->assertUnprocessable()
            ->assertJsonPath('errors.armada_id.0', 'Armada sedang nonaktif.');
    }

    public function test_bentor_tidak_bisa_mengubah_tugas_armada_lain(): void
    {
        $bank = $this->bank();
        $armadaSaya = $this->armada($bank);
        $armadaLain = $this->armada($bank);
        $id = $this->ajukan($this->warga(), $bank->id);

        Sanctum::actingAs($this->operator($bank));
        $this->patchJson("/api/v1/bs/penjemputan/{$id}", ['aksi' => 'jadwalkan', 'armada_id' => $armadaLain->id, 'jadwal_at' => now()->toIso8601String()])->assertOk();

        Sanctum::actingAs($this->bentorDari($armadaSaya));
        $this->getJson('/api/v1/bentor/tugas')->assertOk()->assertJsonCount(0, 'data');
        $this->patchJson("/api/v1/bentor/tugas/{$id}/status", ['status' => 'menuju'])->assertForbidden();

        $this->assertSame('dijadwalkan', Penjemputan::find($id)->status->value);
    }

    public function test_validasi_pengajuan(): void
    {
        Storage::fake('public');
        $bankNonaktif = $this->bank();
        $bankNonaktif->update(['is_aktif' => false]);
        Sanctum::actingAs($this->warga());

        $this->postJson('/api/v1/warga/penjemputan', [
            'bank_sampah_id' => $bankNonaktif->id,
            'lat' => 'x',
            'foto' => UploadedFile::fake()->create('virus.pdf', 10, 'application/pdf'),
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['bank_sampah_id', 'alamat', 'lat', 'lng', 'foto']);
    }

    public function test_bentor_dan_operator_tidak_bisa_mengajukan_jemput(): void
    {
        $bank = $this->bank();
        Sanctum::actingAs($this->operator($bank));

        $this->postJson('/api/v1/warga/penjemputan', ['bank_sampah_id' => $bank->id, 'alamat' => 'x', 'lat' => -4.5, 'lng' => 105.1])
            ->assertForbidden();
    }
}
