<?php

namespace Tests\Feature;

use App\Enums\StatusPreloved;
use App\Models\LaporanPreloved;
use App\Models\PrelovedItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatPreloved;
use Tests\TestCase;

class PrelovedTest extends TestCase
{
    use MembuatPreloved, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    private function dataBarang(array $ubah = []): array
    {
        return $ubah + [
            'judul' => 'Sepeda anak',
            'deskripsi' => 'Ban baru diganti, rem pakem.',
            'kategori' => 'Mainan',
            'kondisi' => 'seperti_baru',
            'harga' => 250000,
            'kecamatan' => 'Tulang Bawang Tengah',
            'foto' => [UploadedFile::fake()->image('a.jpg'), UploadedFile::fake()->image('b.png')],
        ];
    }

    public function test_pasang_barang_dengan_foto_nama_acak_dan_url_lengkap(): void
    {
        $penjual = User::factory()->warga()->create();
        Sanctum::actingAs($penjual);

        $response = $this->postJson('/api/v1/preloved', $this->dataBarang())
            ->assertCreated()
            ->assertJsonPath('data.status', 'tersedia')
            ->assertJsonPath('data.harga', 250000)
            ->assertJsonPath('data.milik_saya', true)
            ->assertJsonCount(2, 'data.foto');

        $barang = PrelovedItem::first();
        $this->assertCount(2, $barang->foto);
        foreach ($barang->foto as $path) {
            $this->assertMatchesRegularExpression('#^preloved/[0-9a-f-]{36}\.(jpg|png)$#', $path);
            Storage::disk('public')->assertExists($path);
        }
        // URL dari Storage::url() disk upload (di production: URL publik Supabase)
        $this->assertSame(Storage::disk('public')->url($barang->foto[0]), $response->json('data.foto.0'));
    }

    public function test_upload_bukan_gambar_atau_terlalu_besar_ditolak(): void
    {
        Sanctum::actingAs(User::factory()->warga()->create());

        $this->postJson('/api/v1/preloved', $this->dataBarang([
            'foto' => [
                UploadedFile::fake()->create('virus.php', 10, 'application/x-php'),
                UploadedFile::fake()->image('besar.jpg')->size(3000),
            ],
        ]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['foto.0', 'foto.1']);

        $this->postJson('/api/v1/preloved', $this->dataBarang([
            'foto' => array_fill(0, 6, UploadedFile::fake()->image('x.jpg')),
            'kondisi' => 'rusak',
            'harga' => 0,
        ]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['foto', 'kondisi', 'harga']);

        $this->assertSame(0, PrelovedItem::count());
        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_daftar_hanya_barang_tersedia_dengan_filter(): void
    {
        $penjual = User::factory()->warga()->create();
        $this->barang($penjual, ['judul' => 'Kursi rotan', 'kategori' => 'Perabot']);
        $this->barang($penjual, ['judul' => 'Meja belajar', 'kategori' => 'Perabot', 'kecamatan' => 'Gunung Agung']);
        $this->barang($penjual, ['judul' => 'Laku', 'kategori' => 'Perabot'], StatusPreloved::Terjual);
        $this->barang($penjual, ['judul' => 'Disembunyikan', 'kategori' => 'Perabot'], StatusPreloved::Disembunyikan);
        Sanctum::actingAs(User::factory()->warga()->create());

        $this->getJson('/api/v1/preloved')->assertOk()->assertJsonCount(2, 'data')->assertJsonPath('meta.total', 2);
        $this->getJson('/api/v1/preloved?q=meja')->assertJsonCount(1, 'data')->assertJsonPath('data.0.judul', 'Meja belajar');
        $this->getJson('/api/v1/preloved?kecamatan=Tumijajar&kategori=Perabot')->assertJsonCount(1, 'data');

        Sanctum::actingAs($penjual);
        $this->getJson('/api/v1/preloved/saya')->assertOk()->assertJsonCount(4, 'data');
    }

    public function test_detail_barang_disembunyikan_404_kecuali_pemilik(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual, [], StatusPreloved::Disembunyikan);

        Sanctum::actingAs(User::factory()->warga()->create());
        $this->getJson("/api/v1/preloved/{$barang->id}")->assertNotFound();

        Sanctum::actingAs($penjual);
        $this->getJson("/api/v1/preloved/{$barang->id}")->assertOk()->assertJsonPath('data.status', 'disembunyikan');
    }

    public function test_hanya_pemilik_yang_bisa_ubah_hapus_tandai_terjual(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual);
        Sanctum::actingAs(User::factory()->warga()->create());

        $this->patchJson("/api/v1/preloved/{$barang->id}", ['harga' => 1])->assertForbidden();
        $this->postJson("/api/v1/preloved/{$barang->id}/terjual")->assertForbidden();
        $this->deleteJson("/api/v1/preloved/{$barang->id}")->assertForbidden();

        $this->assertSame(150000.0, (float) $barang->fresh()->harga);
        $this->assertSame(StatusPreloved::Tersedia, $barang->fresh()->status);
    }

    public function test_pemilik_ubah_ganti_foto_tandai_terjual_dan_hapus(): void
    {
        $penjual = User::factory()->warga()->create();
        Sanctum::actingAs($penjual);
        $id = $this->postJson('/api/v1/preloved', $this->dataBarang())->json('data.id');
        $fotoLama = PrelovedItem::find($id)->foto;

        // Multipart lewat POST + _method=PATCH
        $this->post("/api/v1/preloved/{$id}", [
            '_method' => 'PATCH',
            'harga' => 200000,
            'foto' => [UploadedFile::fake()->image('baru.webp')],
        ], ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonPath('data.harga', 200000)
            ->assertJsonPath('data.judul', 'Sepeda anak')
            ->assertJsonCount(1, 'data.foto');

        foreach ($fotoLama as $path) {
            Storage::disk('public')->assertMissing($path);
        }

        $this->postJson("/api/v1/preloved/{$id}/terjual")->assertOk()->assertJsonPath('data.status', 'terjual');
        $this->postJson("/api/v1/preloved/{$id}/terjual")->assertUnprocessable();

        $fotoBaru = PrelovedItem::find($id)->foto;
        $this->deleteJson("/api/v1/preloved/{$id}")->assertOk();
        $this->assertNull(PrelovedItem::find($id));
        Storage::disk('public')->assertMissing($fotoBaru[0]);
    }

    public function test_lapor_barang(): void
    {
        $penjual = User::factory()->warga()->create();
        $barang = $this->barang($penjual);
        $pelapor = User::factory()->warga()->create();
        Sanctum::actingAs($pelapor);

        $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => 'Barang palsu'])->assertCreated();
        $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => 'Barang palsu dan menipu'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.alasan.0', 'Anda sudah melaporkan barang ini.');
        $this->assertSame(1, LaporanPreloved::count());
        $this->assertSame('Barang palsu', LaporanPreloved::first()->alasan);

        Sanctum::actingAs($penjual);
        $this->postJson("/api/v1/preloved/{$barang->id}/lapor", ['alasan' => 'Laporan diri sendiri'])->assertUnprocessable();
    }

    public function test_selain_warga_tidak_bisa_memakai_preloved(): void
    {
        Sanctum::actingAs(User::factory()->bankSampah()->create());

        $this->getJson('/api/v1/preloved')->assertForbidden();
        $this->postJson('/api/v1/preloved', $this->dataBarang())->assertForbidden();
        $this->getJson('/api/v1/chat')->assertForbidden();
    }
}
