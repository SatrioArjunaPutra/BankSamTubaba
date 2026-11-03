<?php

namespace Tests\Feature;

use App\Models\BankSampah;
use App\Models\Nasabah;
use App\Models\Setoran;
use App\Models\User;
use Database\Seeders\AktivitasPetaDemoSeeder;
use Database\Seeders\DemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\TestCase;

class AktivitasPetaDemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_setoran_demo_memberi_tiap_bank_tingkat_berbeda_dan_tidak_menyentuh_registri(): void
    {
        $this->seed(DemoSeeder::class);
        $registri = BankSampah::factory()->create(['kode' => 'BS-TUBABA-01']);

        $this->seed(AktivitasPetaDemoSeeder::class);

        Sanctum::actingAs(User::where('email', 'dlh@banksampah.test')->firstOrFail());
        $bank = collect($this->getJson('/api/v1/dlh/peta?sumber=demo')->assertOk()->json('data.bank_sampah'))->keyBy('kode');
        $this->assertEquals(640, $bank['BS-DEMO-01']['total_kg']);
        $this->assertEquals(240, $bank['BS-DEMO-02']['total_kg']);
        $this->assertEquals(45, $bank['BS-DEMO-03']['total_kg']);
        $this->assertEquals(160, $bank['BS-DEMO-01']['kg_donasi']);
        $this->assertSame(0, Setoran::where('bank_sampah_id', $registri->id)->count());
    }

    public function test_dijalankan_ulang_tidak_menggandakan_setoran_dan_saldo(): void
    {
        $this->seed(DemoSeeder::class);
        $this->seed(AktivitasPetaDemoSeeder::class);
        $jumlah = Setoran::count();
        $saldo = Nasabah::sum('saldo');

        $this->seed(AktivitasPetaDemoSeeder::class);

        $this->assertSame(12, $jumlah);
        $this->assertSame($jumlah, Setoran::count());
        $this->assertEquals($saldo, Nasabah::sum('saldo'));
        $this->assertEquals(Setoran::sum('total_nilai'), $saldo);
    }

    public function test_ditolak_di_production(): void
    {
        $this->app->detectEnvironment(fn () => 'production');

        $this->expectException(RuntimeException::class);
        $this->app->call([$this->app->make(AktivitasPetaDemoSeeder::class), 'run']);
    }

    public function test_gagal_jelas_bila_data_demo_belum_ada(): void
    {
        $this->expectExceptionMessage('Jalankan DemoSeeder lebih dulu');
        $this->seed(AktivitasPetaDemoSeeder::class);
    }
}
