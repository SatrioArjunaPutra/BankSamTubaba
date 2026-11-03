<?php

namespace Tests\Feature;

use App\Enums\StatusPenjemputan;
use App\Enums\TipeSetoran;
use App\Models\BankSampah;
use App\Models\Penjemputan;
use App\Models\Setoran;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\TestCase;

class KinerjaDlhTest extends TestCase
{
    use MembuatDataBankSampah, RefreshDatabase;

    private function setoran(BankSampah $bank, User $warga, string $tipe, float $kg, float $nilai, string $waktu): void
    {
        $s = Setoran::create([
            'bank_sampah_id' => $bank->id,
            'warga_id' => $warga->id,
            'tipe' => TipeSetoran::from($tipe),
            'total_kg' => $kg,
            'total_nilai' => $nilai,
            'dicatat_oleh' => $warga->id,
        ]);
        $s->forceFill(['created_at' => $waktu])->save();
    }

    private function jemputSelesai(BankSampah $bank, User $warga, string $dibuat, string $selesai): void
    {
        $p = new Penjemputan(['warga_id' => $warga->id, 'bank_sampah_id' => $bank->id, 'alamat' => 'x', 'lat' => -4.5, 'lng' => 105.1]);
        $p->forceFill(['status' => StatusPenjemputan::Selesai, 'selesai_at' => $selesai, 'created_at' => $dibuat])->save();
    }

    public function test_kinerja_per_bank_sampah_dengan_query_tetap(): void
    {
        $this->travelTo('2026-10-20 12:00:00');
        $bankA = $this->bank();
        $bankB = $this->bank();
        $wargaA = $this->warga();
        $wargaB = $this->warga();

        $this->setoran($bankA, $wargaA, 'jual', 10, 30000, '2026-10-05 09:00:00');
        $this->setoran($bankA, $wargaB, 'donasi', 4, 0, '2026-10-06 09:00:00');
        $this->setoran($bankA, $wargaA, 'jual', 100, 300000, '2026-09-30 09:00:00'); // di luar periode
        $this->setoran($bankB, $wargaA, 'jual', 2, 6000, '2026-10-07 09:00:00');
        $this->jemputSelesai($bankA, $wargaA, '2026-10-05 08:00:00', '2026-10-05 10:00:00');
        $this->jemputSelesai($bankA, $wargaB, '2026-10-06 08:00:00', '2026-10-06 12:00:00');
        $aktif = new Penjemputan(['warga_id' => $wargaA->id, 'bank_sampah_id' => $bankB->id, 'alamat' => 'x', 'lat' => -4.5, 'lng' => 105.1]);
        $aktif->forceFill(['status' => StatusPenjemputan::Menuju])->save();

        Sanctum::actingAs(User::factory()->dlh()->create());

        DB::enableQueryLog();
        $response = $this->getJson('/api/v1/dlh/kinerja?periode=bulan')->assertOk();
        $jumlahQuery = count(DB::getQueryLog());

        $response->assertJsonCount(2, 'data.daftar')
            ->assertJsonPath('data.daftar.0.bank_sampah.id', $bankA->id)
            ->assertJsonPath('data.daftar.0.total_kg', 14)
            ->assertJsonPath('data.daftar.0.kg_donasi', 4)
            ->assertJsonPath('data.daftar.0.nasabah_aktif', 2)
            ->assertJsonPath('data.daftar.0.nilai_setoran', 30000)
            ->assertJsonPath('data.daftar.0.jemput_selesai', 2)
            ->assertJsonPath('data.daftar.0.rata2_waktu_jemput_jam', 3)
            ->assertJsonPath('data.daftar.0.jemput_aktif', 0)
            ->assertJsonPath('data.daftar.1.jemput_aktif', 1)
            ->assertJsonPath('data.daftar.1.total_kg', 2)
            ->assertJsonPath('data.daftar.1.rata2_waktu_jemput_jam', null);

        // Tambah 5 bank: jumlah query tidak bertambah (tanpa N+1)
        BankSampah::factory()->count(5)->create();
        DB::flushQueryLog();
        $this->getJson('/api/v1/dlh/kinerja?periode=bulan')->assertOk()->assertJsonCount(7, 'data.daftar');
        $this->assertSame($jumlahQuery, count(DB::getQueryLog()));

        $this->getJson('/api/v1/dlh/kinerja?dari=2026-09-01&sampai=2026-09-30')
            ->assertJsonPath('data.daftar.0.total_kg', 100);
    }

    public function test_ringkasan_dan_tren(): void
    {
        $this->travelTo('2026-10-20 12:00:00');
        $bank = $this->bank();
        $warga = $this->warga();
        $this->setoran($bank, $warga, 'jual', 10, 30000, '2026-10-05 09:00:00');
        $this->setoran($bank, $warga, 'donasi', 4, 0, '2026-10-05 15:00:00');
        $this->setoran($bank, $warga, 'jual', 1, 3000, '2026-08-01 09:00:00');

        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->getJson('/api/v1/dlh/ringkasan')
            ->assertOk()
            ->assertJsonPath('data.total_kg', 15)
            ->assertJsonPath('data.kg_donasi', 4)
            ->assertJsonPath('data.nilai_transaksi', 33000)
            ->assertJsonPath('data.nasabah_aktif', 1)
            ->assertJsonPath('data.bank_sampah_aktif', 1);

        $this->getJson('/api/v1/dlh/ringkasan?periode=bulan')->assertJsonPath('data.total_kg', 14);

        $harian = $this->getJson("/api/v1/dlh/kinerja/{$bank->id}/tren?dari=2026-10-04&sampai=2026-10-06")
            ->assertOk()
            ->assertJsonPath('data.interval', 'harian')
            ->assertJsonCount(3, 'data.data')
            ->json('data.data');
        $this->assertSame(['2026-10-04', '2026-10-05', '2026-10-06'], array_column($harian, 'periode'));
        $this->assertEquals([0, 14, 0], array_column($harian, 'total_kg'));
        $this->assertEquals([0, 4, 0], array_column($harian, 'kg_donasi'));

        $bulanan = $this->getJson("/api/v1/dlh/kinerja/{$bank->id}/tren?periode=tahun&interval=bulanan")
            ->assertOk()
            ->assertJsonCount(12, 'data.data')
            ->json('data.data');
        $this->assertEquals(1, $bulanan[7]['total_kg']);
        $this->assertEquals(14, $bulanan[9]['total_kg']);
    }

    public function test_selain_dlh_ditolak(): void
    {
        $bank = $this->bank();

        foreach ([$this->warga(), $this->operator($bank), User::factory()->bentor()->create()] as $user) {
            Sanctum::actingAs($user);
            $this->getJson('/api/v1/dlh/ringkasan')->assertForbidden();
            $this->getJson('/api/v1/dlh/kinerja')->assertForbidden();
            $this->getJson("/api/v1/dlh/kinerja/{$bank->id}/tren")->assertForbidden();
        }
    }

    public function test_validasi_rentang(): void
    {
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->getJson('/api/v1/dlh/kinerja?dari=2026-10-10&sampai=2026-10-01&periode=dekade')
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['sampai', 'periode']);
    }
}
