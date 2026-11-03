<?php

namespace Tests\Feature;

use App\Enums\StatusBerita;
use App\Models\Berita;
use App\Models\User;
use Database\Seeders\BeritaDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

class BeritaTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    /** @param  array<string, mixed>  $ubah */
    private function artikel(array $ubah = [], StatusBerita $status = StatusBerita::Terbit, ?string $terbit = '2026-11-01 08:00:00'): Berita
    {
        $berita = new Berita($ubah + ['judul' => 'Judul uji', 'ringkasan' => 'Ringkasan uji', 'isi' => 'Isi lengkap uji', 'kategori' => 'berita']);
        $berita->status = $status;
        $berita->diterbitkan_at = $status === StatusBerita::Terbit ? $terbit : null;
        $berita->save();

        return $berita;
    }

    /** @return array<string, mixed> */
    private function isian(array $ubah = []): array
    {
        return $ubah + ['judul' => 'Kerja bakti', 'ringkasan' => 'Ringkas', 'isi' => 'Isi berita', 'kategori' => 'kegiatan', 'status' => 'terbit'];
    }

    private function dlh(): User
    {
        $dlh = User::factory()->dlh()->create();
        Sanctum::actingAs($dlh);

        return $dlh;
    }

    public function test_daftar_publik_tanpa_login_hanya_artikel_terbit_terbaru_dulu(): void
    {
        $this->artikel(['judul' => 'Lama'], terbit: '2026-10-01 08:00:00');
        $this->artikel(['judul' => 'Baru'], terbit: '2026-11-01 08:00:00');
        $this->artikel(['judul' => 'Masih draf'], StatusBerita::Draf);

        $response = $this->getJson('/api/v1/berita')
            ->assertOk()
            ->assertJsonPath('status', 'sukses')
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.judul', 'Baru')
            ->assertJsonPath('data.1.judul', 'Lama');

        $this->assertSame(
            ['id', 'judul', 'ringkasan', 'kategori', 'foto', 'diterbitkan_at', 'dibaca'],
            array_keys($response->json('data.0')),
        );
    }

    public function test_detail_publik_memuat_isi_dan_draf_tidak_bisa_dibuka(): void
    {
        $terbit = $this->artikel();
        $draf = $this->artikel(['judul' => 'Rahasia'], StatusBerita::Draf);

        $this->getJson("/api/v1/berita/{$terbit->id}")->assertOk()->assertJsonPath('data.isi', 'Isi lengkap uji');
        $this->getJson("/api/v1/berita/{$draf->id}")->assertNotFound();
        $this->getJson('/api/v1/berita/9999')->assertNotFound();
        $this->getJson('/api/v1/berita/bukan-angka')->assertNotFound();
    }

    public function test_pencarian_publik_tidak_memuat_draf_dan_input_terlalu_panjang_ditolak(): void
    {
        $this->artikel(['judul' => 'Kerja bakti sungai']);
        $this->artikel(['judul' => 'Rapat warga', 'ringkasan' => 'Membahas kerja bakti']);
        $this->artikel(['judul' => 'Pelatihan']);
        $this->artikel(['judul' => 'Kerja bakti rahasia'], StatusBerita::Draf);

        $this->getJson('/api/v1/berita?q=KERJA')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/v1/berita?q=tidak-ada')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/berita?q='.str_repeat('a', 101))->assertUnprocessable();
    }

    public function test_jumlah_dibaca_hanya_bertambah_saat_detail_terbit_dibuka(): void
    {
        $terbit = $this->artikel();
        $draf = $this->artikel(['judul' => 'Rahasia'], StatusBerita::Draf);
        $diubah = $terbit->refresh()->updated_at->toIso8601String();
        $this->travel(5)->minutes();

        $this->getJson('/api/v1/berita')->assertOk()->assertJsonPath('data.0.dibaca', 0);
        $this->getJson("/api/v1/berita/{$terbit->id}")->assertJsonPath('data.dibaca', 1);
        $this->getJson("/api/v1/berita/{$terbit->id}")->assertJsonPath('data.dibaca', 2);
        $this->getJson("/api/v1/berita/{$draf->id}")->assertNotFound();

        $this->assertSame(2, $terbit->refresh()->dibaca);
        $this->assertSame(0, $draf->refresh()->dibaca);
        $this->assertSame($diubah, $terbit->updated_at->toIso8601String());
    }

    public function test_pagination_dua_puluh_dan_permintaan_berlebihan_dibatasi(): void
    {
        foreach (range(1, 21) as $no) {
            $this->artikel(['judul' => "Berita {$no}"]);
        }

        $this->getJson('/api/v1/berita')->assertJsonCount(20, 'data')->assertJsonPath('meta.total', 21)->assertJsonPath('meta.last_page', 2);

        foreach (range(1, 59) as $_) {
            $this->getJson('/api/v1/berita')->assertOk();
        }

        $this->getJson('/api/v1/berita')->assertTooManyRequests();
    }

    public function test_dlh_menulis_artikel_terbit_dengan_foto(): void
    {
        $dlh = $this->dlh();

        $response = $this->post('/api/v1/dlh/berita', $this->isian(['foto' => UploadedFile::fake()->image('foto.jpg', 400, 300)]), ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('data.status', 'terbit')
            ->assertJsonPath('data.kategori', 'kegiatan');

        $berita = Berita::findOrFail($response->json('data.id'));
        $this->assertSame($dlh->id, $berita->dibuat_oleh);
        $this->assertNotNull($berita->diterbitkan_at);
        Storage::disk('public')->assertExists($berita->foto_path);
        $this->assertStringStartsWith('berita/', $berita->foto_path);
        $this->getJson('/api/v1/berita')->assertJsonPath('data.0.foto', Storage::disk('public')->url($berita->foto_path));
    }

    public function test_artikel_draf_tidak_tayang_dan_tanggal_terbit_dipertahankan(): void
    {
        $this->dlh();
        $id = $this->postJson('/api/v1/dlh/berita', $this->isian(['status' => 'draf']))->assertCreated()->json('data.id');
        $this->assertNull(Berita::findOrFail($id)->diterbitkan_at);
        $this->getJson('/api/v1/berita')->assertJsonCount(0, 'data');

        $this->patchJson("/api/v1/dlh/berita/{$id}", ['status' => 'terbit'])->assertOk();
        $this->getJson('/api/v1/berita')->assertJsonCount(1, 'data');
        Berita::whereKey($id)->update(['diterbitkan_at' => '2026-10-01 08:00:00']);

        $this->patchJson("/api/v1/dlh/berita/{$id}", ['status' => 'draf'])->assertOk();
        $this->getJson('/api/v1/berita')->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/berita/{$id}")->assertNotFound();

        $this->patchJson("/api/v1/dlh/berita/{$id}", ['status' => 'terbit'])->assertOk();
        $this->assertSame('2026-10-01', Berita::findOrFail($id)->diterbitkan_at->toDateString());
    }

    public function test_mengganti_dan_menghapus_foto_membersihkan_file_lama(): void
    {
        $this->dlh();
        $id = $this->post('/api/v1/dlh/berita', $this->isian(['foto' => UploadedFile::fake()->image('a.png')]), ['Accept' => 'application/json'])->json('data.id');
        $lama = Berita::findOrFail($id)->foto_path;

        $this->post("/api/v1/dlh/berita/{$id}", ['_method' => 'PATCH', 'judul' => 'Judul baru', 'foto' => UploadedFile::fake()->image('b.jpg')], ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonPath('data.judul', 'Judul baru');
        $baru = Berita::findOrFail($id)->foto_path;
        $this->assertNotSame($lama, $baru);
        Storage::disk('public')->assertMissing($lama);
        Storage::disk('public')->assertExists($baru);

        // Mengubah teks saja tidak menyentuh foto
        $this->patchJson("/api/v1/dlh/berita/{$id}", ['judul' => 'Judul lain'])->assertOk();
        Storage::disk('public')->assertExists($baru);

        $this->patchJson("/api/v1/dlh/berita/{$id}", ['hapus_foto' => true])->assertOk()->assertJsonPath('data.foto', null);
        Storage::disk('public')->assertMissing($baru);
    }

    public function test_menghapus_artikel_ikut_menghapus_foto(): void
    {
        $this->dlh();
        $id = $this->post('/api/v1/dlh/berita', $this->isian(['foto' => UploadedFile::fake()->image('a.png')]), ['Accept' => 'application/json'])->json('data.id');
        $foto = Berita::findOrFail($id)->foto_path;

        $this->deleteJson("/api/v1/dlh/berita/{$id}")->assertOk();

        $this->assertDatabaseMissing('berita', ['id' => $id]);
        Storage::disk('public')->assertMissing($foto);
    }

    public function test_isian_tidak_sah_ditolak(): void
    {
        $this->dlh();

        $this->postJson('/api/v1/dlh/berita', [])->assertUnprocessable()->assertJsonValidationErrors(['judul', 'ringkasan', 'isi', 'kategori', 'status']);
        $this->postJson('/api/v1/dlh/berita', $this->isian(['kategori' => 'lain']))->assertUnprocessable();
        $this->postJson('/api/v1/dlh/berita', $this->isian(['judul' => str_repeat('a', 151)]))->assertUnprocessable();
        $this->post('/api/v1/dlh/berita', $this->isian(['foto' => UploadedFile::fake()->create('a.pdf', 10, 'application/pdf')]), ['Accept' => 'application/json'])->assertUnprocessable();
        $this->post('/api/v1/dlh/berita', $this->isian(['foto' => UploadedFile::fake()->image('a.jpg')->size(2049)]), ['Accept' => 'application/json'])->assertUnprocessable();
        $this->assertDatabaseCount('berita', 0);
    }

    public function test_peran_selain_dlh_ditolak(): void
    {
        $bank = $this->bank();
        $berita = $this->artikel();

        $this->getJson('/api/v1/dlh/berita')->assertUnauthorized();

        foreach ([$this->warga(), $this->operator($bank), $this->armada($bank)->driver] as $akun) {
            Sanctum::actingAs($akun);
            $this->getJson('/api/v1/dlh/berita')->assertForbidden();
            $this->postJson('/api/v1/dlh/berita', $this->isian())->assertForbidden();
            $this->patchJson("/api/v1/dlh/berita/{$berita->id}", ['judul' => 'Diretas'])->assertForbidden();
            $this->deleteJson("/api/v1/dlh/berita/{$berita->id}")->assertForbidden();
        }

        $this->assertSame('Judul uji', $berita->refresh()->judul);
    }

    public function test_dlh_melihat_draf_dan_bisa_menyaring(): void
    {
        $this->artikel(['judul' => 'Kerja bakti']);
        $this->artikel(['judul' => 'Rapat warga'], StatusBerita::Draf);
        $this->dlh();

        $this->getJson('/api/v1/dlh/berita')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/v1/dlh/berita?status=draf')->assertJsonCount(1, 'data')->assertJsonPath('data.0.judul', 'Rapat warga');
        $this->getJson('/api/v1/dlh/berita?q=KERJA')->assertJsonCount(1, 'data')->assertJsonPath('data.0.judul', 'Kerja bakti');
        $this->getJson('/api/v1/dlh/berita?status=lain')->assertUnprocessable();
    }

    public function test_seeder_contoh_aman_diulang_dan_ditolak_di_production(): void
    {
        $this->seed(BeritaDemoSeeder::class);
        $this->seed(BeritaDemoSeeder::class);

        $this->assertSame(4, Berita::count());
        $this->assertSame(4, Berita::where('judul', 'like', 'Contoh:%')->count());
        $this->getJson('/api/v1/berita')->assertJsonCount(4, 'data');

        $this->app->detectEnvironment(fn () => 'production');
        $this->expectException(RuntimeException::class);
        $this->app->make(BeritaDemoSeeder::class)->run();
    }
}
