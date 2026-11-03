<?php

namespace Tests\Feature;

use App\Models\TeksBerjalan;
use App\Models\User;
use Database\Seeders\TeksBerjalanDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\TestCase;

class TeksBerjalanTest extends TestCase
{
    use RefreshDatabase;

    public function test_publik_hanya_melihat_teks_aktif_sesuai_urutan_tanpa_login(): void
    {
        TeksBerjalan::create(['teks' => 'Kedua', 'urutan' => 2]);
        TeksBerjalan::create(['teks' => 'Pertama', 'urutan' => 1]);
        TeksBerjalan::create(['teks' => 'Dimatikan', 'urutan' => 0, 'is_aktif' => false]);

        $respons = $this->getJson('/api/v1/teks-berjalan')
            ->assertOk()
            ->assertJsonPath('status', 'sukses')
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.teks', 'Pertama')
            ->assertJsonPath('data.1.teks', 'Kedua');

        $this->assertSame(['id', 'teks'], array_keys($respons->json('data.0')));
    }

    public function test_publik_mendapat_daftar_kosong_bila_tidak_ada_teks_aktif(): void
    {
        TeksBerjalan::create(['teks' => 'Dimatikan', 'is_aktif' => false]);

        $this->getJson('/api/v1/teks-berjalan')->assertOk()->assertExactJson([
            'status' => 'sukses',
            'pesan' => 'Teks berjalan berhasil dimuat.',
            'data' => [],
        ]);
    }

    public function test_dlh_menambah_mengubah_mematikan_dan_menghapus_teks(): void
    {
        Sanctum::actingAs(User::factory()->dlh()->create());

        $id = $this->postJson('/api/v1/dlh/teks-berjalan', ['teks' => 'Pengumuman baru'])
            ->assertCreated()
            ->assertJsonPath('data.teks', 'Pengumuman baru')
            ->assertJsonPath('data.urutan', 1)
            ->assertJsonPath('data.is_aktif', true)
            ->json('data.id');

        // Teks berikutnya otomatis di belakang, kecuali urutannya ditentukan
        $this->postJson('/api/v1/dlh/teks-berjalan', ['teks' => 'Teks kedua'])->assertJsonPath('data.urutan', 2);
        $this->postJson('/api/v1/dlh/teks-berjalan', ['teks' => 'Teks ketiga', 'urutan' => 0])->assertJsonPath('data.urutan', 0);

        $this->getJson('/api/v1/dlh/teks-berjalan')
            ->assertOk()
            ->assertJsonPath('meta.total', 3)
            ->assertJsonPath('data.0.teks', 'Teks ketiga');

        $this->patchJson("/api/v1/dlh/teks-berjalan/{$id}", ['teks' => 'Pengumuman diubah'])
            ->assertOk()
            ->assertJsonPath('data.teks', 'Pengumuman diubah')
            ->assertJsonPath('data.urutan', 1);

        // Mematikan saja tidak mengubah teks dan langsung hilang dari web publik
        $this->patchJson("/api/v1/dlh/teks-berjalan/{$id}", ['is_aktif' => false])
            ->assertOk()
            ->assertJsonPath('data.teks', 'Pengumuman diubah')
            ->assertJsonPath('data.is_aktif', false);
        $this->assertNotContains('Pengumuman diubah', $this->getJson('/api/v1/teks-berjalan')->json('data.*.teks'));

        $this->deleteJson("/api/v1/dlh/teks-berjalan/{$id}")->assertOk();
        $this->assertDatabaseMissing('teks_berjalan', ['id' => $id]);
    }

    public function test_validasi_teks(): void
    {
        Sanctum::actingAs(User::factory()->dlh()->create());
        $teks = TeksBerjalan::create(['teks' => 'Teks awal']);

        $this->postJson('/api/v1/dlh/teks-berjalan', [])->assertUnprocessable()->assertJsonValidationErrors('teks');
        $this->postJson('/api/v1/dlh/teks-berjalan', ['teks' => '   '])->assertUnprocessable()->assertJsonValidationErrors('teks');
        $this->postJson('/api/v1/dlh/teks-berjalan', ['teks' => str_repeat('a', 201)])->assertUnprocessable()->assertJsonValidationErrors('teks');
        $this->postJson('/api/v1/dlh/teks-berjalan', ['teks' => 'Valid', 'urutan' => -1])->assertUnprocessable()->assertJsonValidationErrors('urutan');
        $this->patchJson("/api/v1/dlh/teks-berjalan/{$teks->id}", ['teks' => ''])->assertUnprocessable()->assertJsonValidationErrors('teks');
        $this->patchJson("/api/v1/dlh/teks-berjalan/{$teks->id}", ['is_aktif' => 'mungkin'])->assertUnprocessable()->assertJsonValidationErrors('is_aktif');

        $this->assertSame(1, TeksBerjalan::count());
        $this->assertSame('Teks awal', $teks->fresh()->teks);
    }

    public function test_selain_dlh_tidak_bisa_mengelola_teks(): void
    {
        $teks = TeksBerjalan::create(['teks' => 'Teks awal']);

        $this->getJson('/api/v1/dlh/teks-berjalan')->assertUnauthorized();
        $this->postJson('/api/v1/dlh/teks-berjalan', ['teks' => 'Tanpa login'])->assertUnauthorized();

        foreach ([
            User::factory()->warga()->create(),
            User::factory()->bankSampah()->create(),
            User::factory()->bentor()->create(),
        ] as $user) {
            Sanctum::actingAs($user);
            $this->getJson('/api/v1/dlh/teks-berjalan')->assertForbidden();
            $this->postJson('/api/v1/dlh/teks-berjalan', ['teks' => 'Disusupkan'])->assertForbidden();
            $this->patchJson("/api/v1/dlh/teks-berjalan/{$teks->id}", ['teks' => 'Diubah'])->assertForbidden();
            $this->deleteJson("/api/v1/dlh/teks-berjalan/{$teks->id}")->assertForbidden();
        }

        $this->assertSame(1, TeksBerjalan::count());
        $this->assertSame('Teks awal', $teks->fresh()->teks);
    }

    public function test_teks_contoh_ditolak_di_production(): void
    {
        $this->app->detectEnvironment(fn () => 'production');

        $this->expectException(RuntimeException::class);
        (new TeksBerjalanDemoSeeder)->run();
    }

    public function test_teks_contoh_aman_dijalankan_ulang(): void
    {
        (new TeksBerjalanDemoSeeder)->run();
        (new TeksBerjalanDemoSeeder)->run();

        $this->assertSame(3, TeksBerjalan::count());
    }
}
