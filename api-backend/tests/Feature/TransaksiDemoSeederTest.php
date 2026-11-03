<?php

namespace Tests\Feature;

use App\Enums\StatusPenjemputan;
use App\Models\Nasabah;
use App\Models\Penjemputan;
use App\Models\Setoran;
use Database\Seeders\DemoSeeder;
use Database\Seeders\TransaksiDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TransaksiDemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_transaksi_tersebar_ke_berbagai_warga_bank_dan_bentor_serta_saldo_cocok(): void
    {
        $this->seed(DemoSeeder::class);
        $this->seed(TransaksiDemoSeeder::class);

        $setoran = Setoran::all();
        $this->assertGreaterThanOrEqual(10, $setoran->count());
        $this->assertSame(3, $setoran->pluck('bank_sampah_id')->unique()->count());
        $this->assertSame(5, $setoran->pluck('warga_id')->unique()->count());

        // Enam penjemputan selesai, masing-masing ditimbang bentor yang berbeda
        $lewatBentor = $setoran->whereNotNull('penjemputan_id');
        $this->assertSame(6, $lewatBentor->count());
        $this->assertSame(6, $lewatBentor->pluck('dicatat_oleh')->unique()->count());
        $this->assertSame(6, Penjemputan::where('status', StatusPenjemputan::Selesai->value)->count());

        $this->assertGreaterThan(0, $setoran->where('tipe.value', 'donasi')->count());
        $this->assertEquals(0, $setoran->where('tipe.value', 'donasi')->sum('total_nilai'));

        // Saldo nasabah sama dengan jumlah nilai setoran jualnya
        foreach (Nasabah::all() as $nasabah) {
            $this->assertEqualsWithDelta(
                (float) $setoran->where('warga_id', $nasabah->warga_id)->where('bank_sampah_id', $nasabah->bank_sampah_id)->sum('total_nilai'),
                (float) $nasabah->saldo,
                0.001,
            );
        }
    }

    public function test_dijalankan_ulang_tidak_menggandakan_transaksi_dan_saldo(): void
    {
        $this->seed(DemoSeeder::class);
        $this->seed(TransaksiDemoSeeder::class);
        $jumlah = Setoran::count();
        $jemput = Penjemputan::count();
        $saldo = Nasabah::sum('saldo');

        $this->seed(TransaksiDemoSeeder::class);

        $this->assertSame($jumlah, Setoran::count());
        $this->assertSame($jemput, Penjemputan::count());
        $this->assertEquals($saldo, Nasabah::sum('saldo'));
    }
}
