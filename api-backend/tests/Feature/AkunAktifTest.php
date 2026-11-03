<?php

namespace Tests\Feature;

use App\Models\BankSampah;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Middleware akun.aktif: akun nonaktif & tenancy bank_sampah/bentor.
 */
class AkunAktifTest extends TestCase
{
    use RefreshDatabase;

    public function test_token_akun_yang_dinonaktifkan_langsung_ditolak(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('hp')->plainTextToken;

        $this->withToken($token)->getJson('/api/v1/me')->assertOk();

        $user->forceFill(['is_aktif' => false])->save();
        $this->app['auth']->forgetGuards();

        $this->withToken($token)->getJson('/api/v1/me')
            ->assertForbidden()
            ->assertJsonPath('pesan', 'Akun Anda dinonaktifkan. Hubungi pengelola.');
    }

    public function test_operator_dan_bentor_tanpa_bank_sampah_ditolak(): void
    {
        foreach (['bankSampah', 'bentor'] as $state) {
            Sanctum::actingAs(User::factory()->{$state}()->create(['bank_sampah_id' => null]));

            $this->getJson('/api/v1/me')
                ->assertForbidden()
                ->assertJsonPath('pesan', 'Akun belum terhubung ke bank sampah. Hubungi DLH.');
        }
    }

    public function test_operator_bank_sampah_nonaktif_ditolak(): void
    {
        $bank = BankSampah::factory()->nonaktif()->create();
        Sanctum::actingAs(User::factory()->bankSampah()->create(['bank_sampah_id' => $bank->id]));

        $this->getJson('/api/v1/me')->assertForbidden();
    }

    public function test_dlh_dan_warga_tidak_perlu_bank_sampah(): void
    {
        foreach (['dlh', 'warga'] as $state) {
            Sanctum::actingAs(User::factory()->{$state}()->create());
            $this->getJson('/api/v1/me')->assertOk()->assertJsonPath('data.bank_sampah_id', null);
        }
    }

    public function test_operator_terikat_bank_aktif_lolos(): void
    {
        Sanctum::actingAs(User::factory()->bankSampah()->create());

        $this->getJson('/api/v1/me')->assertOk()->assertJsonPath('data.role', 'bank_sampah');
    }
}
