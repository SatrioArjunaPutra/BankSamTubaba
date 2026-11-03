<?php

namespace Tests\Feature;

use App\Models\BankSampah;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ImportBankSampahTest extends TestCase
{
    use RefreshDatabase;

    private string $csv;

    protected function setUp(): void
    {
        parent::setUp();

        // Data fiktif; susunan kolom sama dengan formulir DLH (55 kolom)
        $header = array_merge(
            ['Timestamp', 'NAMA BANK SAMPAH', 'TIYUH', 'KECAMATAN', 'TAHUN TERBENTUK', 'NO HP KETUA BANK SAMPAH',
                'JUMLAH PENGURUS', 'JUMLAH NASABAH', 'ALAMAT LOKASI', 'TITIK KOORDINAT LOKASI'],
            array_map(fn ($i) => "KOLOM {$i}", range(11, 55)),
        );
        $baris = fn (array $isi) => implode(';', array_pad($isi, 55, 'https://drive.google.com/rahasia'));

        $this->csv = tempnam(sys_get_temp_dir(), 'bs').'.csv';
        file_put_contents($this->csv, "\u{FEFF}".implode("\n", [
            implode(';', $header),
            $baris(['1/1/2026', 'Bank Sampah Melati', 'Panaragan', 'TULANG BAWANG TENGAH', '2020', '081299998888', '5', '30', 'Jl. Melati 1', '-4,5762732, 105,1234567']),
            $baris(['1/1/2026', '', '', '', '', '081277776666']),
            $baris(['1/1/2026', 'Bank Sampah Mawar', 'Daya Murni', 'TUMIJAJAR', '2021', '081255554444', '3', '12', '', 'belum tahu']),
            $baris(['1/1/2026', '"Bank Sampah ""Kenanga"""', 'Entah', 'KECAMATAN LAIN', '2022', '081233332222', '2', '8', '', '']),
        ]));
    }

    protected function tearDown(): void
    {
        @unlink($this->csv);
        parent::tearDown();
    }

    public function test_import_membaca_kolom_yang_diizinkan_dan_kode_ikut_nomor_baris(): void
    {
        $this->artisan('banksampah:import', ['csv' => $this->csv])->assertSuccessful();

        $this->assertSame(3, BankSampah::count());

        $melati = BankSampah::where('kode', 'BS-TUBABA-01')->first();
        $this->assertSame('Bank Sampah Melati', $melati->nama);
        $this->assertSame('Tulang Bawang Tengah', $melati->kecamatan);
        $this->assertSame('Jl. Melati 1', $melati->alamat);
        $this->assertEqualsWithDelta(-4.576273, $melati->lat, 0.000001);
        $this->assertEqualsWithDelta(105.123457, $melati->lng, 0.000001);
        $this->assertFalse($melati->koordinat_estimasi);
        $this->assertNull($melati->no_hp_publik);

        // Baris 2 kosong dilewati, tapi tetap menghabiskan nomor
        $mawar = BankSampah::where('kode', 'BS-TUBABA-03')->first();
        $this->assertTrue($mawar->koordinat_estimasi);
        $this->assertEqualsWithDelta(-4.5120, $mawar->lat, 0.011);
        $this->assertSame('Daya Murni, Kec. Tumijajar', $mawar->alamat);

        $kenanga = BankSampah::where('kode', 'BS-TUBABA-04')->first();
        $this->assertSame('Bank Sampah "Kenanga"', $kenanga->nama);
        $this->assertNull($kenanga->lat);

        // Data pribadi & link Drive tidak tersimpan di kolom mana pun
        $semua = BankSampah::all()->toJson();
        $this->assertStringNotContainsString('0812', $semua);
        $this->assertStringNotContainsString('drive.google', $semua);
    }

    public function test_import_ulang_idempoten_dan_tidak_menimpa_status_aktif(): void
    {
        $this->artisan('banksampah:import', ['csv' => $this->csv])->assertSuccessful();
        $sebelum = BankSampah::orderBy('kode')->get(['kode', 'lat', 'lng'])->toArray();

        BankSampah::where('kode', 'BS-TUBABA-01')->update(['is_aktif' => false, 'no_hp_publik' => '081211112222']);

        $this->artisan('banksampah:import', ['csv' => $this->csv])->assertSuccessful();

        $this->assertSame(3, BankSampah::count());
        $this->assertSame($sebelum, BankSampah::orderBy('kode')->get(['kode', 'lat', 'lng'])->toArray());
        $melati = BankSampah::where('kode', 'BS-TUBABA-01')->first();
        $this->assertFalse($melati->is_aktif);
        $this->assertSame('081211112222', $melati->no_hp_publik);
    }

    public function test_titik_yang_sudah_dikoreksi_tidak_kembali_saat_import_ulang(): void
    {
        $baris = fn (string $nama) => implode(';', array_pad(['1/1/2026', $nama, 'Tiyuh', 'PAGAR DEWA', '2020', '081200000000', '1', '1', 'Alamat', '-4.113400, 105.364800'], 55, ''));
        file_put_contents($this->csv, implode("\n", ['kepala', $baris('Bang sampah  ANGGREK Tiyuh jaya murni')]));

        $this->artisan('banksampah:import', ['csv' => $this->csv])->assertSuccessful();
        $anggrek = BankSampah::where('kode', 'BS-TUBABA-01')->first();
        $this->assertEqualsWithDelta(-4.2044374, $anggrek->lat, 0.0000001);
        $this->assertEqualsWithDelta(105.2030875, $anggrek->lng, 0.0000001);
        $this->assertFalse($anggrek->koordinat_estimasi);

        // Nomor baris sama tetapi nama lain: titik dari CSV tetap dipakai
        file_put_contents($this->csv, implode("\n", ['kepala', $baris('Bank Sampah Lain')]));
        $this->artisan('banksampah:import', ['csv' => $this->csv])->assertSuccessful();
        $this->assertEqualsWithDelta(-4.1134, $anggrek->fresh()->lat, 0.0000001);
    }

    public function test_file_tidak_ada_gagal(): void
    {
        $this->artisan('banksampah:import', ['csv' => '/tidak/ada.csv'])->assertFailed();
    }
}
