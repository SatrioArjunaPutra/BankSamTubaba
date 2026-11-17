<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PerangkatTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Kirim permintaan dengan token tertentu; guard dilupakan agar token lama tidak terbawa.
     */
    private function denganToken(string $token): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($token);
    }

    public function test_daftar_hanya_perangkat_sendiri_dan_menandai_perangkat_ini(): void
    {
        $warga = User::factory()->warga()->create();
        $hp = $warga->createToken('HP Android')->plainTextToken;
        $warga->createToken('Laptop');
        User::factory()->warga()->create()->createToken('Perangkat orang lain');

        $jawaban = $this->denganToken($hp)->getJson('/api/v1/me/perangkat')
            ->assertOk()
            ->assertJsonCount(2, 'data');

        $perangkat = collect($jawaban->json('data'))->keyBy('nama');
        $this->assertTrue($perangkat['HP Android']['saat_ini']);
        $this->assertFalse($perangkat['Laptop']['saat_ini']);
        $this->assertArrayNotHasKey('token', $perangkat['Laptop']);
    }

    public function test_tidak_bisa_mengeluarkan_perangkat_orang_lain(): void
    {
        $warga = User::factory()->warga()->create();
        $hp = $warga->createToken('HP')->plainTextToken;
        $laptop = $warga->createToken('Laptop')->accessToken;
        $milikLain = User::factory()->warga()->create()->createToken('Lain')->accessToken;

        $this->denganToken($hp)->deleteJson("/api/v1/me/perangkat/{$milikLain->id}")->assertNotFound();
        $this->assertDatabaseHas('personal_access_tokens', ['id' => $milikLain->id]);

        $this->denganToken($hp)->deleteJson("/api/v1/me/perangkat/{$laptop->id}")->assertOk();
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $laptop->id]);
    }

    public function test_keluar_dari_perangkat_lain_menyisakan_perangkat_ini(): void
    {
        $warga = User::factory()->warga()->create();
        $hp = $warga->createToken('HP')->plainTextToken;
        $laptop = $warga->createToken('Laptop')->plainTextToken;
        $warga->createToken('Tablet');
        $tokenOrangLain = User::factory()->warga()->create()->createToken('Lain')->accessToken;

        $this->denganToken($hp)->postJson('/api/v1/me/perangkat/keluar-lainnya')
            ->assertOk()
            ->assertJsonPath('data.jumlah', 2);

        $this->assertSame(1, $warga->tokens()->count());
        $this->assertDatabaseHas('personal_access_tokens', ['id' => $tokenOrangLain->id]);
        $this->denganToken($laptop)->getJson('/api/v1/me')->assertUnauthorized();
        $this->denganToken($hp)->getJson('/api/v1/me')->assertOk();
    }

    public function test_tamu_tidak_bisa_melihat_perangkat(): void
    {
        $this->getJson('/api/v1/me/perangkat')->assertUnauthorized();
    }
}
