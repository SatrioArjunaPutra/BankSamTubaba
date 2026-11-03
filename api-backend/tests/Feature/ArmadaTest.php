<?php

namespace Tests\Feature;

use App\Enums\StatusPenjemputan;
use App\Models\Armada;
use App\Models\Penjemputan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

class ArmadaTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    public function test_operator_buat_bentor_sekaligus_armada(): void
    {
        $bank = $this->bank();
        Sanctum::actingAs($this->operator($bank));

        $this->postJson('/api/v1/bs/bentor', [
            'name' => 'Pak Bentor',
            'email' => 'bentor@example.com',
            'phone' => '081233334444',
            'password' => 'Rahasia123',
            'password_confirmation' => 'Rahasia123',
            'plat_nomor' => 'BE 1234 AB',
            'kapasitas_kg' => 150,
        ])
            ->assertCreated()
            ->assertJsonPath('data.bentor.role', 'bentor')
            ->assertJsonPath('data.bentor.bank_sampah_id', $bank->id)
            ->assertJsonPath('data.armada.plat_nomor', 'BE 1234 AB')
            ->assertJsonPath('data.armada.status', 'siaga');

        $this->postJson('/api/v1/auth/login', ['email' => 'bentor@example.com', 'password' => 'Rahasia123'])->assertOk();
    }

    public function test_tambah_armada_untuk_bentor_tanpa_armada(): void
    {
        $bank = $this->bank();
        $bentor = User::factory()->bentor()->create(['bank_sampah_id' => $bank->id]);
        $bentorBankLain = User::factory()->bentor()->create();
        Sanctum::actingAs($this->operator($bank));

        $this->getJson('/api/v1/bs/armada')->assertOk()->assertJsonCount(1, 'data.bentor_tanpa_armada');

        $this->postJson('/api/v1/bs/armada', ['driver_id' => $bentorBankLain->id, 'plat_nomor' => 'BE 1 X'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.driver_id.0', 'Driver harus akun bentor di bank sampah ini.');

        $this->postJson('/api/v1/bs/armada', ['driver_id' => $bentor->id, 'plat_nomor' => 'BE 2 X'])->assertCreated();
        $this->postJson('/api/v1/bs/armada', ['driver_id' => $bentor->id, 'plat_nomor' => 'BE 3 X'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.driver_id.0', 'Driver ini sudah memiliki armada.');

        $this->getJson('/api/v1/bs/armada')
            ->assertJsonCount(1, 'data.armada')
            ->assertJsonPath('data.armada.0.tugas_aktif', 0)
            ->assertJsonCount(0, 'data.bentor_tanpa_armada');
    }

    public function test_operator_bank_lain_tidak_bisa_melihat_atau_mengubah_armada(): void
    {
        $bankA = $this->bank();
        $armadaA = $this->armada($bankA);

        Sanctum::actingAs($this->operator($this->bank()));
        $this->getJson('/api/v1/bs/armada')->assertOk()->assertJsonCount(0, 'data.armada');
        $this->patchJson("/api/v1/bs/armada/{$armadaA->id}", ['plat_nomor' => 'DICURI'])->assertForbidden();

        $this->assertNotSame('DICURI', $armadaA->fresh()->plat_nomor);
    }

    public function test_armada_yang_sedang_menjemput_tidak_bisa_dinonaktifkan(): void
    {
        $bank = $this->bank();
        $armada = $this->armada($bank);
        $p = new Penjemputan(['warga_id' => $this->warga()->id, 'bank_sampah_id' => $bank->id, 'alamat' => 'x', 'lat' => -4.5, 'lng' => 105.1]);
        $p->forceFill(['armada_id' => $armada->id, 'status' => StatusPenjemputan::Menuju])->save();

        Sanctum::actingAs($this->operator($bank));
        $this->patchJson("/api/v1/bs/armada/{$armada->id}", ['status' => 'nonaktif'])->assertUnprocessable();

        Sanctum::actingAs($armada->driver);
        $this->getJson('/api/v1/bentor/armada')
            ->assertOk()
            ->assertJsonPath('data.id', $armada->id)
            ->assertJsonPath('data.tugas_aktif', 1);
        $this->patchJson('/api/v1/bentor/armada/status', ['status' => 'nonaktif'])->assertUnprocessable();
        $this->patchJson('/api/v1/bentor/armada/status', ['status' => 'bertugas'])->assertUnprocessable()->assertJsonValidationErrors('status');

        $p->forceFill(['status' => StatusPenjemputan::Selesai])->save();
        $this->patchJson('/api/v1/bentor/armada/status', ['status' => 'nonaktif'])->assertOk()->assertJsonPath('data.status', 'nonaktif');
    }

    public function test_bentor_tanpa_armada_dapat_404_dan_bukan_bentor_ditolak(): void
    {
        $bank = $this->bank();
        Sanctum::actingAs(User::factory()->bentor()->create(['bank_sampah_id' => $bank->id]));
        $this->patchJson('/api/v1/bentor/armada/status', ['status' => 'siaga'])->assertNotFound();
        $this->getJson('/api/v1/bentor/armada')->assertNotFound();
        $this->getJson('/api/v1/bentor/tugas')->assertOk()->assertJsonCount(0, 'data');

        Sanctum::actingAs($this->operator($bank));
        $this->getJson('/api/v1/bentor/tugas')->assertForbidden();
        $this->assertSame(0, Armada::count());
    }
}
