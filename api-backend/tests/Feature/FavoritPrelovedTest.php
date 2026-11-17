<?php

namespace Tests\Feature;

use App\Enums\StatusPreloved;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatPreloved;
use Tests\TestCase;

class FavoritPrelovedTest extends TestCase
{
    use MembuatPreloved, RefreshDatabase;

    public function test_simpan_dan_hapus_favorit_tidak_menggandakan_baris(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual);
        Sanctum::actingAs(User::factory()->warga()->create());

        $this->postJson("/api/v1/preloved/{$barang->id}/favorit")->assertOk()
            ->assertJsonPath('data.difavoritkan', true)
            ->assertJsonPath('data.jumlah_favorit', 1);
        $this->postJson("/api/v1/preloved/{$barang->id}/favorit")->assertOk()
            ->assertJsonPath('data.jumlah_favorit', 1);
        $this->assertDatabaseCount('preloved_favorit', 1);

        $this->deleteJson("/api/v1/preloved/{$barang->id}/favorit")->assertOk()
            ->assertJsonPath('data.difavoritkan', false)
            ->assertJsonPath('data.jumlah_favorit', 0);
        $this->deleteJson("/api/v1/preloved/{$barang->id}/favorit")->assertOk();
        $this->assertDatabaseCount('preloved_favorit', 0);
    }

    public function test_tanda_favorit_mengikuti_warga_yang_login(): void
    {
        $barang = $this->barang(User::factory()->warga()->create());
        $penyimpan = User::factory()->warga()->create();
        $barang->favoritOleh()->attach([$penyimpan->id, User::factory()->warga()->create()->id]);

        Sanctum::actingAs($penyimpan);
        $this->getJson('/api/v1/preloved')->assertOk()
            ->assertJsonPath('data.0.difavoritkan', true)
            ->assertJsonPath('data.0.jumlah_favorit', 2);

        Sanctum::actingAs(User::factory()->warga()->create());
        $this->getJson("/api/v1/preloved/{$barang->id}")->assertOk()
            ->assertJsonPath('data.difavoritkan', false)
            ->assertJsonPath('data.jumlah_favorit', 2);
    }

    public function test_daftar_favorit_hanya_milik_sendiri_terbaru_di_atas_tanpa_barang_disembunyikan(): void
    {
        $penjual = User::factory()->warga()->create();
        [$lama, $baru, $disembunyikan] = [$this->barang($penjual, ['judul' => 'Lama']), $this->barang($penjual, ['judul' => 'Baru']), $this->barang($penjual, ['judul' => 'Tersembunyi'])];
        $warga = User::factory()->warga()->create();
        $this->travelTo(now()->subDay());
        $lama->favoritOleh()->attach($warga->id);
        $this->travelBack();
        $baru->favoritOleh()->attach($warga->id);
        $disembunyikan->favoritOleh()->attach($warga->id);
        $disembunyikan->status = StatusPreloved::Disembunyikan;
        $disembunyikan->save();
        $this->barang($penjual, ['judul' => 'Milik orang lain'])->favoritOleh()->attach(User::factory()->warga()->create()->id);

        Sanctum::actingAs($warga);
        $this->getJson('/api/v1/preloved/favorit')->assertOk()
            ->assertJsonPath('meta.total', 2)
            ->assertJsonPath('data.0.judul', 'Baru')
            ->assertJsonPath('data.1.judul', 'Lama')
            ->assertJsonPath('data.0.difavoritkan', true);
    }

    public function test_barang_sendiri_terjual_atau_disembunyikan_ditolak(): void
    {
        $penjual = User::factory()->warga()->create();
        Sanctum::actingAs($penjual);
        $this->postJson('/api/v1/preloved/'.$this->barang($penjual)->id.'/favorit')
            ->assertUnprocessable()->assertJsonValidationErrors('barang');

        Sanctum::actingAs(User::factory()->warga()->create());
        $this->postJson('/api/v1/preloved/'.$this->barang($penjual, [], StatusPreloved::Terjual)->id.'/favorit')
            ->assertUnprocessable()->assertJsonValidationErrors('barang');
        $this->postJson('/api/v1/preloved/'.$this->barang($penjual, [], StatusPreloved::Disembunyikan)->id.'/favorit')
            ->assertNotFound();
        $this->assertDatabaseCount('preloved_favorit', 0);
    }

    public function test_hanya_warga_yang_login_yang_bisa_memakai_favorit(): void
    {
        $barang = $this->barang(User::factory()->warga()->create());

        $this->postJson("/api/v1/preloved/{$barang->id}/favorit")->assertUnauthorized();

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->postJson("/api/v1/preloved/{$barang->id}/favorit")->assertForbidden();
        $this->getJson('/api/v1/preloved/favorit')->assertForbidden();
    }

    public function test_daftar_barang_bisa_disaring_kondisi_dan_diurutkan_harga(): void
    {
        $penjual = User::factory()->warga()->create();
        $this->barang($penjual, ['judul' => 'Sedang', 'harga' => 50000, 'kondisi' => 'bekas']);
        $this->barang($penjual, ['judul' => 'Murah', 'harga' => 10000, 'kondisi' => 'bekas']);
        $this->barang($penjual, ['judul' => 'Mahal', 'harga' => 90000, 'kondisi' => 'baru']);
        Sanctum::actingAs(User::factory()->warga()->create());

        $this->getJson('/api/v1/preloved?urut=termurah')->assertOk()
            ->assertJsonPath('data.0.judul', 'Murah')->assertJsonPath('data.2.judul', 'Mahal');
        $this->getJson('/api/v1/preloved?urut=termahal&kondisi=bekas')->assertOk()
            ->assertJsonPath('meta.total', 2)->assertJsonPath('data.0.judul', 'Sedang');
        $this->getJson('/api/v1/preloved?urut=acak')->assertUnprocessable()->assertJsonValidationErrors('urut');
        $this->getJson('/api/v1/preloved?kondisi=rusak')->assertUnprocessable()->assertJsonValidationErrors('kondisi');
    }
}
