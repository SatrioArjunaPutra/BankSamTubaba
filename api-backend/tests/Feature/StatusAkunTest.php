<?php

namespace Tests\Feature;

use App\Enums\StatusArmada;
use App\Enums\StatusPenjemputan;
use App\Models\Penjemputan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

/**
 * Menonaktifkan akun operator & bentor: DLH untuk keduanya, operator hanya
 * untuk bentor di bank sampahnya.
 */
class StatusAkunTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    public function test_dlh_menonaktifkan_operator_semua_token_langsung_tidak_berlaku(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $operator = $this->operator($bank);
        $tokenHp = $operator->createToken('hp')->plainTextToken;
        $tokenLain = $operator->createToken('tablet')->plainTextToken;

        $this->withToken($tokenHp)->getJson('/api/v1/bs/dashboard')->assertOk();
        $this->app['auth']->forgetGuards();

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson("/api/v1/dlh/bank-sampah/{$bank->id}/akun")
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.is_aktif', true);
        $this->patchJson("/api/v1/dlh/akun/{$operator->id}/status", ['is_aktif' => false])
            ->assertOk()
            ->assertJsonPath('data.is_aktif', false);

        $this->assertSame(0, $operator->tokens()->count());
        $this->app['auth']->forgetGuards();
        foreach ([$tokenHp, $tokenLain] as $token) {
            $this->withToken($token)->postJson('/api/v1/bs/setoran', [])->assertUnauthorized();
            $this->app['auth']->forgetGuards();
        }
        $this->postJson('/api/v1/auth/login', ['email' => $operator->email, 'password' => 'password'])->assertForbidden();

        // Diaktifkan lagi → bisa login
        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->patchJson("/api/v1/dlh/akun/{$operator->id}/status", ['is_aktif' => true])->assertOk();
        $this->postJson('/api/v1/auth/login', ['email' => $operator->email, 'password' => 'password'])->assertOk();
    }

    public function test_dlh_tidak_bisa_menonaktifkan_warga_atau_dlh(): void
    {
        Sanctum::actingAs(User::factory()->dlh()->create());

        foreach ([$this->warga(), User::factory()->dlh()->create()] as $akun) {
            $this->patchJson("/api/v1/dlh/akun/{$akun->id}/status", ['is_aktif' => false])
                ->assertUnprocessable()
                ->assertJsonValidationErrors('is_aktif');
            $this->assertTrue($akun->fresh()->is_aktif);
        }
    }

    public function test_operator_menonaktifkan_bentor_bank_sendiri_dan_armadanya_ikut_nonaktif(): void
    {
        $bank = $this->bank();
        $armada = $this->armada($bank);
        $bentor = $armada->driver;
        $bentor->createToken('hp');
        Sanctum::actingAs($this->operator($bank));

        $this->patchJson("/api/v1/bs/bentor/{$bentor->id}/status", ['is_aktif' => false])
            ->assertOk()
            ->assertJsonPath('data.is_aktif', false);

        $this->assertSame(0, $bentor->tokens()->count());
        $this->assertSame(StatusArmada::Nonaktif, $armada->fresh()->status);
        $this->getJson('/api/v1/bs/armada')->assertJsonPath('data.armada.0.driver.is_aktif', false);
    }

    public function test_bentor_yang_sedang_menjemput_tidak_bisa_dinonaktifkan(): void
    {
        $bank = $this->bank();
        $armada = $this->armada($bank);
        $p = new Penjemputan(['warga_id' => $this->warga()->id, 'bank_sampah_id' => $bank->id, 'alamat' => 'x', 'lat' => -4.5, 'lng' => 105.1]);
        $p->forceFill(['armada_id' => $armada->id, 'status' => StatusPenjemputan::Menuju])->save();
        Sanctum::actingAs($this->operator($bank));

        $this->patchJson("/api/v1/bs/bentor/{$armada->driver_id}/status", ['is_aktif' => false])->assertUnprocessable();

        $this->assertTrue($armada->driver->fresh()->is_aktif);
    }

    public function test_operator_tidak_bisa_mengubah_akun_bank_lain_operator_lain_atau_warga(): void
    {
        $bankA = $this->bank();
        $bankB = $this->bank();
        $bentorB = $this->armada($bankB)->driver;
        $operatorLain = $this->operator($bankA);
        $warga = $this->warga();
        Sanctum::actingAs($this->operator($bankA));

        foreach ([$bentorB, $operatorLain, $warga] as $akun) {
            $this->patchJson("/api/v1/bs/bentor/{$akun->id}/status", ['is_aktif' => false])->assertForbidden();
            $this->assertTrue($akun->fresh()->is_aktif);
        }
    }

    public function test_selain_dlh_tidak_bisa_memakai_endpoint_akun_dlh(): void
    {
        $bank = $this->bank();
        $operator = $this->operator($bank);
        Sanctum::actingAs($operator);

        $this->getJson("/api/v1/dlh/bank-sampah/{$bank->id}/akun")->assertForbidden();
        $this->patchJson("/api/v1/dlh/akun/{$operator->id}/status", ['is_aktif' => false])->assertForbidden();
        $this->assertTrue($operator->fresh()->is_aktif);
    }
}
