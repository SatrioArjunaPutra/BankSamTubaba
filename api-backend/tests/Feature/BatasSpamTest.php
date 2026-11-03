<?php

namespace Tests\Feature;

use App\Models\Penjemputan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\Concerns\MembuatPreloved;
use Tests\TestCase;

class BatasSpamTest extends TestCase
{
    use MembuatDataBankSampah, MembuatPreloved, RefreshDatabase;

    private function ajukanJemput(int $bankId)
    {
        return $this->postJson('/api/v1/warga/penjemputan', ['bank_sampah_id' => $bankId, 'alamat' => 'Jl. Uji', 'lat' => -4.58, 'lng' => 105.13]);
    }

    public function test_maks_tiga_jemput_menunggu_per_warga_per_bank_sampah(): void
    {
        $bankA = $this->bank();
        $bankB = $this->bank();
        Sanctum::actingAs($this->warga());

        $ids = [];
        for ($i = 0; $i < 3; $i++) {
            $ids[] = $this->ajukanJemput($bankA->id)->assertCreated()->json('data.id');
        }
        // Yang sudah dijadwalkan tetap dihitung
        Penjemputan::whereKey($ids[0])->update(['status' => 'dijadwalkan']);

        $this->ajukanJemput($bankA->id)
            ->assertUnprocessable()
            ->assertJsonPath('errors.bank_sampah_id.0', 'Masih ada 3 permintaan jemput yang berjalan di bank sampah ini.');

        // Bank sampah lain tidak terpengaruh
        $this->ajukanJemput($bankB->id)->assertCreated();

        // Setelah satu dibatalkan, boleh mengajukan lagi
        $this->postJson("/api/v1/warga/penjemputan/{$ids[1]}/batal")->assertOk();
        $this->ajukanJemput($bankA->id)->assertCreated();
        $this->assertSame(3, Penjemputan::where('bank_sampah_id', $bankA->id)->whereIn('status', ['diajukan', 'dijadwalkan'])->count());
    }

    public function test_pengajuan_jemput_dibatasi_10_per_jam_per_warga(): void
    {
        $bank = $this->bank();
        Sanctum::actingAs($this->warga());

        for ($i = 0; $i < 10; $i++) {
            $id = $this->ajukanJemput($bank->id)->assertCreated()->json('data.id');
            $this->postJson("/api/v1/warga/penjemputan/{$id}/batal")->assertOk();
        }
        $this->ajukanJemput($bank->id)->assertTooManyRequests()->assertJsonPath('status', 'gagal');

        // Warga lain tidak ikut terkena
        Sanctum::actingAs($this->warga());
        $this->ajukanJemput($bank->id)->assertCreated();
    }

    public function test_pasang_barang_preloved_dibatasi_20_per_hari(): void
    {
        Storage::fake('public');
        Sanctum::actingAs($this->warga());
        $data = fn () => [
            'judul' => 'Barang', 'deskripsi' => 'Deskripsi', 'kategori' => 'Lainnya', 'kondisi' => 'bekas',
            'harga' => 1000, 'kecamatan' => 'Tumijajar', 'foto' => [UploadedFile::fake()->image('a.jpg', 10, 10)],
        ];

        for ($i = 0; $i < 20; $i++) {
            $this->post('/api/v1/preloved', $data(), ['Accept' => 'application/json'])->assertCreated();
        }
        $this->post('/api/v1/preloved', $data(), ['Accept' => 'application/json'])->assertTooManyRequests();
    }

    public function test_laporan_preloved_dibatasi_20_per_hari(): void
    {
        $penjual = $this->warga();
        $barang = array_map(fn () => $this->barang($penjual), range(1, 21));
        Sanctum::actingAs($this->warga());

        foreach (array_slice($barang, 0, 20) as $b) {
            $this->postJson("/api/v1/preloved/{$b->id}/lapor", ['alasan' => 'Mencurigakan'])->assertCreated();
        }
        $this->postJson("/api/v1/preloved/{$barang[20]->id}/lapor", ['alasan' => 'Mencurigakan'])->assertTooManyRequests();
    }

    public function test_cari_nasabah_dibatasi_60_per_menit_per_operator(): void
    {
        $bank = $this->bank();
        Sanctum::actingAs($this->operator($bank));

        for ($i = 0; $i < 60; $i++) {
            $this->getJson('/api/v1/bs/nasabah')->assertOk();
        }
        $this->getJson('/api/v1/bs/nasabah')->assertTooManyRequests();

        Sanctum::actingAs($this->operator($bank));
        $this->getJson('/api/v1/bs/nasabah')->assertOk();
    }

    public function test_batas_tidak_berlaku_untuk_penarikan_dan_daftar(): void
    {
        // Sanity: endpoint baca warga tidak ikut dibatasi limiter baru
        Sanctum::actingAs(User::factory()->warga()->create());
        for ($i = 0; $i < 30; $i++) {
            $this->getJson('/api/v1/warga/penjemputan')->assertOk();
        }
    }
}
