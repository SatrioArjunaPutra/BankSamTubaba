<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

class ResetPasswordPetugasTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    public function test_pengelola_mereset_password_nasabahnya(): void
    {
        $bank = $this->bank();
        $warga = User::factory()->warga()->create(['email' => 'siti@example.com']);
        $this->beriSaldo($warga, $bank, 2000);
        $warga->createToken('HP hilang');
        Sanctum::actingAs($this->operator($bank));

        $sandi = $this->postJson("/api/v1/bs/nasabah/{$warga->id}/reset-password")
            ->assertOk()
            ->assertHeader('Cache-Control', 'no-store, private')
            ->assertJsonPath('data.user.id', $warga->id)
            ->json('data.password_sementara');

        $this->assertMatchesRegularExpression('/^[a-z2-9]{8}$/', $sandi);
        $warga->refresh();
        $this->assertTrue($warga->harus_ganti_password);
        $this->assertTrue(Hash::check($sandi, $warga->password));
        $this->assertSame(0, $warga->tokens()->count());
    }

    public function test_warga_bukan_nasabah_bank_ini_tidak_bisa_direset(): void
    {
        $bank = $this->bank();
        $nasabahBankLain = User::factory()->warga()->create();
        $this->beriSaldo($nasabahBankLain, $this->bank(), 1000);
        $bukanNasabah = User::factory()->warga()->create();
        Sanctum::actingAs($this->operator($bank));

        $this->postJson("/api/v1/bs/nasabah/{$nasabahBankLain->id}/reset-password")->assertNotFound();
        $this->postJson("/api/v1/bs/nasabah/{$bukanNasabah->id}/reset-password")->assertNotFound();

        $this->assertTrue(Hash::check('password', $nasabahBankLain->refresh()->password));
        $this->assertFalse($nasabahBankLain->harus_ganti_password);
    }

    public function test_pengelola_hanya_mereset_bentor_di_banknya(): void
    {
        $bank = $this->bank();
        $bentor = $this->armada($bank)->driver;
        $bentorLain = $this->armada($this->bank())->driver;
        Sanctum::actingAs($this->operator($bank));

        $this->postJson("/api/v1/bs/bentor/{$bentor->id}/reset-password")->assertOk();
        $this->assertTrue($bentor->refresh()->harus_ganti_password);

        $this->postJson("/api/v1/bs/bentor/{$bentorLain->id}/reset-password")->assertForbidden();
        $this->assertTrue(Hash::check('password', $bentorLain->refresh()->password));
    }

    public function test_hanya_pengelola_yang_bisa_mereset(): void
    {
        $bank = $this->bank();
        $warga = User::factory()->warga()->create();
        $this->beriSaldo($warga, $bank, 0);

        Sanctum::actingAs($this->armada($bank)->driver);
        $this->postJson("/api/v1/bs/nasabah/{$warga->id}/reset-password")->assertForbidden();

        Sanctum::actingAs(User::factory()->warga()->create());
        $this->postJson("/api/v1/bs/nasabah/{$warga->id}/reset-password")->assertForbidden();

        $this->assertFalse($warga->refresh()->harus_ganti_password);
    }

    public function test_password_sementara_wajib_diganti_sebelum_memakai_fitur_lain(): void
    {
        $bank = $this->bank();
        $warga = User::factory()->warga()->create(['email' => 'siti@example.com']);
        $this->beriSaldo($warga, $bank, 0);
        Sanctum::actingAs($this->operator($bank));
        $sandi = $this->postJson("/api/v1/bs/nasabah/{$warga->id}/reset-password")->json('data.password_sementara');

        $this->app['auth']->forgetGuards();
        $token = $this->postJson('/api/v1/auth/login', ['email' => 'siti@example.com', 'password' => $sandi, 'role' => 'warga'])
            ->assertOk()
            ->assertJsonPath('data.user.harus_ganti_password', true)
            ->json('data.token');

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/warga/saldo')
            ->assertForbidden()
            ->assertJsonPath('kode', 'wajib_ganti_password');
        $this->withToken($token)->getJson('/api/v1/me')->assertOk();

        $this->withToken($token)->putJson('/api/v1/me/password', [
            'password_lama' => $sandi,
            'password' => 'sandi-baru-siti',
            'password_confirmation' => 'sandi-baru-siti',
        ])->assertOk();

        $this->assertFalse($warga->refresh()->harus_ganti_password);
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/warga/saldo')->assertOk();
    }
}
