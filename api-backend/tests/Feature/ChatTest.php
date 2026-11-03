<?php

namespace Tests\Feature;

use App\Enums\StatusPreloved;
use App\Models\Percakapan;
use App\Models\Pesan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatPreloved;
use Tests\TestCase;

class ChatTest extends TestCase
{
    use MembuatPreloved, RefreshDatabase;

    private function bukaChat(User $pembeli, int $barangId): int
    {
        Sanctum::actingAs($pembeli);

        return $this->postJson("/api/v1/preloved/{$barangId}/chat")->assertSuccessful()->json('data.id');
    }

    public function test_buka_chat_idempoten(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual);
        $pembeli = User::factory()->warga()->create();
        Sanctum::actingAs($pembeli);

        $id = $this->postJson("/api/v1/preloved/{$barang->id}/chat")
            ->assertCreated()
            ->assertJsonPath('data.peran_saya', 'pembeli')
            ->assertJsonPath('data.lawan_bicara.id', $penjual->id)
            ->json('data.id');

        $this->postJson("/api/v1/preloved/{$barang->id}/chat")->assertOk()->assertJsonPath('data.id', $id);
        $this->assertSame(1, Percakapan::count());
    }

    public function test_penjual_tidak_bisa_chat_barangnya_sendiri(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual);
        Sanctum::actingAs($penjual);

        $this->postJson("/api/v1/preloved/{$barang->id}/chat")
            ->assertUnprocessable()
            ->assertJsonPath('errors.preloved_item_id.0', 'Anda tidak bisa chat dengan barang sendiri.');
        $this->assertSame(0, Percakapan::count());
    }

    public function test_barang_disembunyikan_atau_terjual_tidak_bisa_dibuka_chat_baru(): void
    {
        $penjual = User::factory()->warga()->create();
        $tersembunyi = $this->barang($penjual, [], StatusPreloved::Disembunyikan);
        $terjual = $this->barang($penjual, [], StatusPreloved::Terjual);
        Sanctum::actingAs(User::factory()->warga()->create());

        $this->postJson("/api/v1/preloved/{$tersembunyi->id}/chat")->assertNotFound();
        $this->postJson("/api/v1/preloved/{$terjual->id}/chat")->assertUnprocessable();
        $this->assertSame(0, Percakapan::count());
    }

    public function test_orang_ketiga_tidak_bisa_membaca_atau_mengirim_pesan(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual);
        $pembeli = User::factory()->warga()->create();
        $id = $this->bukaChat($pembeli, $barang->id);
        $this->postJson("/api/v1/chat/{$id}/pesan", ['isi' => 'Rahasia'])->assertCreated();

        Sanctum::actingAs(User::factory()->warga()->create());
        $this->getJson("/api/v1/chat/{$id}/pesan")->assertForbidden();
        $this->postJson("/api/v1/chat/{$id}/pesan", ['isi' => 'Menyusup'])->assertForbidden();
        $this->postJson("/api/v1/chat/{$id}/baca")->assertForbidden();
        $this->getJson('/api/v1/chat')->assertOk()->assertJsonCount(0, 'data');

        $this->assertSame(1, Pesan::count());
    }

    public function test_after_id_hanya_mengembalikan_pesan_baru_urut_naik(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual);
        $pembeli = User::factory()->warga()->create();
        $id = $this->bukaChat($pembeli, $barang->id);

        $p1 = $this->postJson("/api/v1/chat/{$id}/pesan", ['isi' => 'Halo, masih ada?'])->json('data.id');

        Sanctum::actingAs($penjual);
        $p2 = $this->postJson("/api/v1/chat/{$id}/pesan", ['isi' => 'Masih'])->json('data.id');
        $p3 = $this->postJson("/api/v1/chat/{$id}/pesan", ['tawaran_harga' => 140000])
            ->assertCreated()
            ->assertJsonPath('data.isi', null)
            ->assertJsonPath('data.tawaran_harga', 140000)
            ->assertJsonPath('data.milik_saya', true)
            ->json('data.id');

        $this->getJson("/api/v1/chat/{$id}/pesan?after_id={$p1}")
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $p2)
            ->assertJsonPath('data.1.id', $p3);

        $this->getJson("/api/v1/chat/{$id}/pesan?after_id={$p3}")->assertOk()->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/chat/{$id}/pesan")->assertJsonCount(3, 'data')->assertJsonPath('data.0.id', $p1);
    }

    public function test_maksimal_50_pesan_per_ambil(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual);
        $pembeli = User::factory()->warga()->create();
        $id = $this->bukaChat($pembeli, $barang->id);
        Pesan::insert(array_map(fn ($i) => ['percakapan_id' => $id, 'pengirim_id' => $pembeli->id, 'isi' => "p{$i}", 'created_at' => now(), 'updated_at' => now()], range(1, 60)));

        $this->getJson("/api/v1/chat/{$id}/pesan?after_id=0")->assertJsonCount(50, 'data')->assertJsonPath('data.0.isi', 'p1');
        $this->getJson("/api/v1/chat/{$id}/pesan")->assertJsonCount(50, 'data')->assertJsonPath('data.49.isi', 'p60');
    }

    public function test_validasi_pesan(): void
    {
        $barang = $this->barang(User::factory()->warga()->create());
        $id = $this->bukaChat(User::factory()->warga()->create(), $barang->id);

        $this->postJson("/api/v1/chat/{$id}/pesan", [])
            ->assertUnprocessable()
            ->assertJsonPath('errors.isi.0', 'Isi pesan atau tawaran harga wajib diisi.');
        $this->postJson("/api/v1/chat/{$id}/pesan", ['isi' => str_repeat('a', 1001), 'tawaran_harga' => -5])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['isi', 'tawaran_harga']);
    }

    public function test_daftar_chat_dengan_pesan_terakhir_unread_dan_tanpa_n_plus_1(): void
    {
        $penjual = User::factory()->warga()->create();
        $pembeliA = User::factory()->warga()->create();
        $pembeliB = User::factory()->warga()->create();
        $barang1 = $this->barang($penjual, ['judul' => 'Barang 1']);
        $barang2 = $this->barang($penjual, ['judul' => 'Barang 2']);

        $c1 = $this->bukaChat($pembeliA, $barang1->id);
        $this->postJson("/api/v1/chat/{$c1}/pesan", ['isi' => 'A1']);
        $this->postJson("/api/v1/chat/{$c1}/pesan", ['isi' => 'A2']);
        $c2 = $this->bukaChat($pembeliB, $barang2->id);
        $this->travel(1)->minutes();
        $this->postJson("/api/v1/chat/{$c2}/pesan", ['tawaran_harga' => 100000]);
        $this->bukaChat($pembeliB, $barang1->id); // dibuka tanpa pesan → tidak tampil

        Sanctum::actingAs($penjual);
        DB::enableQueryLog();
        $this->getJson('/api/v1/chat')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $c2)
            ->assertJsonPath('data.0.peran_saya', 'penjual')
            ->assertJsonPath('data.0.lawan_bicara.id', $pembeliB->id)
            ->assertJsonPath('data.0.pesan_terakhir.tawaran_harga', 100000)
            ->assertJsonPath('data.0.unread_count', 1)
            ->assertJsonPath('data.1.pesan_terakhir.isi', 'A2')
            ->assertJsonPath('data.1.unread_count', 2)
            ->assertJsonPath('data.1.barang.judul', 'Barang 1');
        $queryDuaChat = count(DB::getQueryLog());

        // Tambah 3 percakapan lagi: jumlah query tetap
        foreach (range(1, 3) as $i) {
            $c = $this->bukaChat(User::factory()->warga()->create(), $this->barang($penjual)->id);
            $this->postJson("/api/v1/chat/{$c}/pesan", ['isi' => "x{$i}"]);
        }
        Sanctum::actingAs($penjual);
        DB::flushQueryLog();
        $this->getJson('/api/v1/chat')->assertJsonCount(5, 'data');
        $this->assertSame($queryDuaChat, count(DB::getQueryLog()));

        // Tandai dibaca: unread penjual di c1 jadi 0, pesan pembeli punya dibaca_at
        $this->postJson("/api/v1/chat/{$c1}/baca")->assertOk()->assertJsonPath('data.jumlah', 2);
        $this->assertSame(0, Pesan::where('percakapan_id', $c1)->whereNull('dibaca_at')->count());

        Sanctum::actingAs($pembeliA);
        $this->getJson('/api/v1/chat')->assertJsonCount(1, 'data')->assertJsonPath('data.0.unread_count', 0);
    }

    public function test_kirim_pesan_dibatasi_30_per_menit(): void
    {
        $barang = $this->barang(User::factory()->warga()->create());
        $id = $this->bukaChat(User::factory()->warga()->create(), $barang->id);

        for ($i = 1; $i <= 30; $i++) {
            $this->postJson("/api/v1/chat/{$id}/pesan", ['isi' => "pesan {$i}"])->assertCreated();
        }

        $this->postJson("/api/v1/chat/{$id}/pesan", ['isi' => 'ke-31'])->assertTooManyRequests();
        $this->assertSame(30, Pesan::count());
    }

    public function test_tidak_bisa_kirim_pesan_ke_barang_disembunyikan(): void
    {
        $barang = $this->barang(User::factory()->warga()->create());
        $id = $this->bukaChat(User::factory()->warga()->create(), $barang->id);
        $barang->forceFill(['status' => StatusPreloved::Disembunyikan])->save();

        $this->postJson("/api/v1/chat/{$id}/pesan", ['isi' => 'Halo'])->assertUnprocessable();
    }
}
