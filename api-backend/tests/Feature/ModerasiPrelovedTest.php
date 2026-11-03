<?php

namespace Tests\Feature;

use App\Enums\StatusLaporan;
use App\Models\LaporanPreloved;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatPreloved;
use Tests\TestCase;

class ModerasiPrelovedTest extends TestCase
{
    use MembuatPreloved, RefreshDatabase;

    public function test_dlh_melihat_laporan_dan_menyembunyikan_barang(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual, ['judul' => 'Barang mencurigakan']);
        $pelapor = User::factory()->warga()->create();
        Sanctum::actingAs($pelapor);
        $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => 'Penipuan'])->assertCreated();

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/v1/dlh/laporan-preloved')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.jumlah_laporan', 1)
            ->assertJsonPath('data.0.barang.judul', 'Barang mencurigakan')
            ->assertJsonPath('data.0.laporan.0.alasan', 'Penipuan')
            ->assertJsonPath('data.0.laporan.0.pelapor.id', $pelapor->id);

        $this->patchJson("/api/v1/dlh/preloved/{$barang->id}", ['status' => 'disembunyikan'])
            ->assertOk()
            ->assertJsonPath('data.status', 'disembunyikan');
        $this->assertSame(StatusLaporan::Ditindak, LaporanPreloved::first()->status);
        $this->getJson('/api/v1/dlh/laporan-preloved')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/dlh/laporan-preloved?status=ditindak')->assertJsonCount(1, 'data');

        // Barang hilang dari daftar warga
        Sanctum::actingAs($pelapor);
        $this->getJson('/api/v1/preloved')->assertJsonCount(0, 'data');

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->patchJson("/api/v1/dlh/preloved/{$barang->id}", ['status' => 'tersedia'])->assertOk();
        Sanctum::actingAs($pelapor);
        $this->getJson('/api/v1/preloved')->assertJsonCount(1, 'data');
    }

    public function test_satu_barang_dilaporkan_banyak_warga_tampil_dalam_satu_baris(): void
    {
        $barang = $this->barang(User::factory()->warga()->create(), ['judul' => 'Banyak laporan']);
        $lain = $this->barang(User::factory()->warga()->create(), ['judul' => 'Satu laporan']);
        $warga = User::factory()->warga()->count(3)->create();

        foreach ($warga as $i => $pelapor) {
            Sanctum::actingAs($pelapor);
            $this->travel(1)->minutes();
            $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => "Alasan warga {$i}"])->assertCreated();
        }
        $this->travel(1)->minutes();
        $this->postJson("/api/v1/preloved/{$lain->id}/lapor", ['alasan' => 'Alasan terakhir'])->assertCreated();

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/v1/dlh/laporan-preloved')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.total', 2)
            ->assertJsonPath('data.0.barang.judul', 'Satu laporan')
            ->assertJsonPath('data.1.barang.judul', 'Banyak laporan')
            ->assertJsonPath('data.1.jumlah_laporan', 3)
            ->assertJsonCount(3, 'data.1.laporan')
            ->assertJsonPath('data.1.laporan.0.alasan', 'Alasan warga 2')
            ->assertJsonPath('data.1.laporan.2.alasan', 'Alasan warga 0')
            ->assertJsonPath('data.1.laporan.0.pelapor.id', $warga[2]->id);
    }

    public function test_akun_yang_sama_hanya_sekali_dan_warga_lain_tetap_bisa_melapor(): void
    {
        $barang = $this->barang(User::factory()->warga()->create());
        $pertama = User::factory()->warga()->create();

        Sanctum::actingAs($pertama);
        $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => 'Laporan pertama'])->assertCreated();
        $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => 'Laporan kedua'])->assertUnprocessable();

        Sanctum::actingAs(User::factory()->warga()->create());
        $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => 'Warga lain'])->assertCreated();

        $this->assertSame(2, LaporanPreloved::count());
        $this->assertSame(['Laporan pertama', 'Warga lain'], LaporanPreloved::orderBy('id')->pluck('alasan')->all());
    }

    public function test_akun_yang_sudah_melapor_tidak_bisa_mengulang_setelah_ditinjau(): void
    {
        $barang = $this->barang(User::factory()->warga()->create());
        $pelapor = User::factory()->warga()->create();
        Sanctum::actingAs($pelapor);
        $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => 'Laporan pertama'])->assertCreated();
        LaporanPreloved::query()->update(['status' => StatusLaporan::Diabaikan->value]);

        $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => 'Laporan lagi'])->assertUnprocessable();

        $this->assertSame(StatusLaporan::Diabaikan, LaporanPreloved::first()->status);
    }

    public function test_tindakan_dlh_berlaku_untuk_semua_laporan_baru_dan_saringan_memisahkan_status(): void
    {
        $barang = $this->barang(User::factory()->warga()->create());
        foreach (['Laporan satu', 'Laporan dua'] as $alasan) {
            Sanctum::actingAs(User::factory()->warga()->create());
            $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => $alasan])->assertCreated();
        }
        LaporanPreloved::where('alasan', 'Laporan satu')->update(['status' => StatusLaporan::Diabaikan->value]);

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/v1/dlh/laporan-preloved')->assertJsonPath('data.0.jumlah_laporan', 1)->assertJsonPath('data.0.laporan.0.alasan', 'Laporan dua');
        $this->getJson('/api/v1/dlh/laporan-preloved?status=diabaikan')->assertJsonPath('data.0.jumlah_laporan', 1)->assertJsonPath('data.0.laporan.0.alasan', 'Laporan satu');

        $this->patchJson("/api/v1/dlh/preloved/{$barang->id}", ['status' => 'disembunyikan'])->assertOk();

        $this->getJson('/api/v1/dlh/laporan-preloved')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/dlh/laporan-preloved?status=ditindak')->assertJsonPath('data.0.laporan.0.alasan', 'Laporan dua');
        $this->getJson('/api/v1/dlh/laporan-preloved?status=diabaikan')->assertJsonPath('data.0.laporan.0.alasan', 'Laporan satu');
    }

    public function test_jumlah_laporan_di_katalog_sama_dengan_daftar_laporan_baru(): void
    {
        $barang = $this->barang(User::factory()->warga()->create());
        foreach (['Laporan lama', 'Laporan baru'] as $alasan) {
            Sanctum::actingAs(User::factory()->warga()->create());
            $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => $alasan])->assertCreated();
        }
        LaporanPreloved::where('alasan', 'Laporan lama')->update(['status' => StatusLaporan::Ditindak->value]);

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/v1/dlh/preloved?status=semua')->assertOk()->assertJsonPath('data.0.jumlah_laporan', 1);
        $this->getJson('/api/v1/dlh/laporan-preloved')->assertOk()->assertJsonCount(1, 'data');

        // Setelah semua ditinjau, kartu tidak lagi menampilkan laporan
        LaporanPreloved::where('alasan', 'Laporan baru')->update(['status' => StatusLaporan::Diabaikan->value]);
        $this->getJson('/api/v1/dlh/preloved?status=semua')->assertOk()->assertJsonPath('data.0.jumlah_laporan', 0);
    }

    public function test_selain_dlh_tidak_bisa_moderasi(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual);

        foreach ([$penjual, User::factory()->bankSampah()->create()] as $user) {
            Sanctum::actingAs($user);
            $this->getJson('/api/v1/dlh/laporan-preloved')->assertForbidden();
            $this->patchJson("/api/v1/dlh/preloved/{$barang->id}", ['status' => 'disembunyikan'])->assertForbidden();
        }

        $this->assertSame('tersedia', $barang->fresh()->status->value);
    }

    public function test_barang_terjual_tidak_bisa_dijadikan_tersedia_lagi(): void
    {
        $barang = $this->barang(User::factory()->warga()->create(), [], \App\Enums\StatusPreloved::Terjual);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->patchJson("/api/v1/dlh/preloved/{$barang->id}", ['status' => 'tersedia'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('status');
        $this->assertSame('terjual', $barang->fresh()->status->value);

        // Tetap boleh disembunyikan
        $this->patchJson("/api/v1/dlh/preloved/{$barang->id}", ['status' => 'disembunyikan'])->assertOk();
    }

    public function test_validasi_status_moderasi(): void
    {
        $barang = $this->barang(User::factory()->warga()->create());
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->patchJson("/api/v1/dlh/preloved/{$barang->id}", ['status' => 'terjual'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('status');
    }

    public function test_dlh_melihat_seluruh_katalog_preloved_dan_dapat_menghapus(): void
    {
        $penjual = User::factory()->warga()->create(['name' => 'Warga Penjual']);
        $barang1 = $this->barang($penjual, ['judul' => 'Kipas Angin']);
        $barang2 = $this->barang($penjual, ['judul' => 'Sepeda Bekas'], \App\Enums\StatusPreloved::Disembunyikan);

        // DLH bisa melihat semua barang
        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/v1/dlh/preloved')
            ->assertOk()
            ->assertJsonCount(2, 'data');

        // Filter pencarian
        $this->getJson('/api/v1/dlh/preloved?q=Kipas')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.judul', 'Kipas Angin');

        // DLH bisa menghapus barang
        $this->deleteJson("/api/v1/dlh/preloved/{$barang1->id}")
            ->assertOk();
        $this->assertDatabaseMissing('preloved_items', ['id' => $barang1->id]);

        // Role selain DLH dilarang
        Sanctum::actingAs($penjual);
        $this->getJson('/api/v1/dlh/preloved')->assertForbidden();
        $this->deleteJson("/api/v1/dlh/preloved/{$barang2->id}")->assertForbidden();
    }
}
