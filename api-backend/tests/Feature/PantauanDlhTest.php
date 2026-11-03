<?php

namespace Tests\Feature;

use App\Enums\StatusArmada;
use App\Enums\StatusLaporan;
use App\Models\Armada;
use App\Models\LaporanPreloved;
use App\Models\Penjemputan;
use App\Models\User;
use App\Services\SetoranService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Concerns\MembuatDataBankSampah;
use Tests\Concerns\MembuatPreloved;
use Tests\TestCase;

class PantauanDlhTest extends TestCase
{
    use MembuatDataBankSampah, MembuatPreloved, RefreshDatabase;

    public static function endpoints(): array
    {
        return array_map(fn (string $path): array => [$path], ['dashboard', 'warga', 'bentor', 'transaksi', 'donasi']);
    }

    #[DataProvider('endpoints')]
    public function test_pantauan_hanya_dapat_diakses_dlh(string $path): void
    {
        $this->getJson('/api/v1/dlh/'.$path)->assertUnauthorized();
        Sanctum::actingAs($this->warga());
        $this->getJson('/api/v1/dlh/'.$path)->assertForbidden();
        Sanctum::actingAs($this->operator($this->bank()));
        $this->getJson('/api/v1/dlh/'.$path)->assertForbidden();
        Sanctum::actingAs(User::factory()->bentor()->create());
        $this->getJson('/api/v1/dlh/'.$path)->assertForbidden();
    }

    public function test_dashboard_menghitung_komposisi_dan_duabelas_bulan_dari_setoran_asli(): void
    {
        $this->travelTo('2026-10-31 12:00:00');
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        $operator = $this->operator($bank);
        $service = app(SetoranService::class);
        $service->catat($operator, ['warga_id' => $warga->id, 'tipe' => 'jual', 'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 2]]]);
        $service->catat($operator, ['warga_id' => $warga->id, 'tipe' => 'donasi', 'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 1]]]);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->getJson('/api/v1/dlh/dashboard?periode=bulan')->assertOk()
            ->assertJsonCount(12, 'data.tren')
            ->assertJsonPath('data.tren.1.periode', '2026-02')
            ->assertJsonPath('data.tren.10.periode', '2026-11')
            ->assertJsonPath('data.tren.9.total_kg', 3)
            ->assertJsonPath('data.tren.0.total_kg', 0)
            ->assertJsonPath('data.ringkasan.total_kg', 3)
            ->assertJsonPath('data.ringkasan.kg_periode_lalu', 0)
            ->assertJsonPath('data.komposisi.0.nama', 'Plastik')
            ->assertJsonPath('data.komposisi.0.total_kg', 3);
        $this->assertSame(6000.0, $this->saldo($warga, $bank));
    }

    public function test_dashboard_menghitung_bank_tanpa_setoran_dan_barang_dilaporkan(): void
    {
        $this->travelTo('2026-10-31 12:00:00');
        $bank = $this->bank(['Plastik' => 3000]);
        $this->bank(['Plastik' => 3000]);
        $bankLama = $this->bank(['Plastik' => 3000]);
        $bankBatal = $this->bank(['Plastik' => 3000]);
        $bankMati = $this->bank(['Plastik' => 3000]);
        $bankMati->update(['is_aktif' => false]);
        $warga = $this->warga();
        $service = app(SetoranService::class);
        $item = ['warga_id' => $warga->id, 'tipe' => 'jual', 'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 1]]];

        // Setoran lama di luar rentang dan setoran batal tidak dihitung
        $this->travelTo('2026-08-01 12:00:00');
        $service->catat($this->operator($bankLama), $item);
        $this->travelTo('2026-10-31 12:00:00');
        $service->catat($this->operator($bank), $item);
        $operatorBatal = $this->operator($bankBatal);
        $service->batalkan($service->catat($operatorBatal, $item), $operatorBatal, 'Salah catat');

        // Dua laporan baru pada satu barang dihitung satu; yang sudah ditinjau tidak dihitung
        $barang = $this->barang(User::factory()->warga()->create());
        $barangLama = $this->barang(User::factory()->warga()->create());
        foreach ([[$barang, StatusLaporan::Baru], [$barang, StatusLaporan::Baru], [$barangLama, StatusLaporan::Ditindak]] as [$b, $status]) {
            $laporan = new LaporanPreloved(['preloved_item_id' => $b->id, 'pelapor_id' => User::factory()->warga()->create()->id, 'alasan' => 'Mencurigakan']);
            $laporan->status = $status;
            $laporan->save();
        }

        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/v1/dlh/dashboard?periode=bulan')->assertOk()
            ->assertJsonPath('data.ringkasan.bank_tanpa_setoran', 3)
            ->assertJsonPath('data.ringkasan.barang_dilaporkan', 1);
    }

    public function test_armada_siaga_yang_punya_tugas_tampil_terjadwal_bukan_tersedia(): void
    {
        $bank = $this->bank();
        $terjadwal = $this->armada($bank);
        $tersedia = $this->armada($bank);
        $selesai = $this->armada($bank);
        $bertugas = $this->armada($bank, StatusArmada::Bertugas);
        $jemput = fn (Armada $a, string $status) => Penjemputan::forceCreate([
            'warga_id' => $this->warga()->id, 'bank_sampah_id' => $bank->id, 'armada_id' => $a->id,
            'alamat' => 'Jalan Uji', 'lat' => -4.5, 'lng' => 105.1, 'status' => $status, 'jadwal_at' => '2026-11-01 09:00:00',
        ]);
        $jemput($terjadwal, 'dijadwalkan');
        $jemput($selesai, 'selesai');
        $jemput($bertugas, 'menuju');
        Sanctum::actingAs(User::factory()->dlh()->create());

        $ids = fn (string $status) => collect($this->getJson('/api/v1/dlh/bentor?status='.$status)->assertOk()->json('data'))->pluck('id')->sort()->values()->all();
        $this->assertSame([$terjadwal->id], $ids('terjadwal'));
        $this->assertSame([$tersedia->id, $selesai->id], $ids('siaga'));
        $this->assertSame([$bertugas->id], $ids('bertugas'));

        $tampil = collect($this->getJson('/api/v1/dlh/bentor')->json('data'))->pluck('status_tampil', 'id');
        $this->assertSame('terjadwal', $tampil[$terjadwal->id]);
        $this->assertSame('siaga', $tampil[$tersedia->id]);
        $this->assertSame('bertugas', $tampil[$bertugas->id]);
        // Status armada di database tidak berubah, jadi aturan bentor tetap sama
        $this->assertSame('siaga', $terjadwal->fresh()->status->value);

        $dashboard = $this->getJson('/api/v1/dlh/dashboard')->assertOk()
            ->assertJsonPath('data.ringkasan.bentor_terjadwal', 1)
            ->assertJsonPath('data.ringkasan.bentor_siaga', 2)
            ->assertJsonPath('data.ringkasan.bentor_bertugas', 1);
        $this->assertNotNull(collect($dashboard->json('data.penjemputan'))->firstWhere('status', 'dijadwalkan')['jadwal_at']);
    }

    public function test_daftar_berhalaman_dapat_difilter_tanpa_mengirim_password(): void
    {
        $this->travelTo('2026-10-20 12:00:00');
        $bank = $this->bank(['Plastik' => 3000]);
        $operator = $this->operator($bank);
        $warga = User::factory()->warga()->create(['name' => 'Warga Uji', 'phone' => '081234567890', 'alamat' => 'Alamat pribadi warga']);
        $armada = $this->armada($bank);
        app(SetoranService::class)->catat($operator, ['warga_id' => $warga->id, 'tipe' => 'donasi', 'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 1]]]);
        Sanctum::actingAs(User::factory()->dlh()->create());

        $this->getJson('/api/v1/dlh/warga?q=Uji')->assertOk()->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.saldo', 0)->assertJsonPath('data.0.phone', '08••••7890')
            ->assertJsonMissingPath('data.0.alamat')->assertJsonMissingPath('data.0.password');
        $this->getJson('/api/v1/dlh/bentor?bank_sampah_id='.$bank->id)->assertOk()
            ->assertJsonPath('data.0.id', $armada->id)->assertJsonMissingPath('data.0.password');
        $this->getJson('/api/v1/dlh/bank-sampah?q='.$bank->kode)->assertOk()
            ->assertJsonPath('data.0.sampah_bulan_ini_kg', 1)
            ->assertJsonPath('data.0.jumlah_nasabah', 1)
            ->assertJsonPath('data.0.jumlah_bentor', 1);
        $this->getJson('/api/v1/dlh/transaksi?tipe=jual')->assertOk()->assertJsonPath('meta.total', 0);
        $this->getJson('/api/v1/dlh/donasi?q=Uji')->assertOk()->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.tipe', 'donasi');
        $this->getJson('/api/v1/dlh/warga?per_page=10000')->assertUnprocessable();
        $this->getJson('/api/v1/dlh/dashboard?dari=2026-10-10&sampai=2026-10-01')->assertUnprocessable();
    }

    public function test_transaksi_mencakup_penarikan_tanpa_mengubah_saldo(): void
    {
        $bank = $this->bank(['Plastik' => 3000]);
        $warga = $this->warga();
        app(SetoranService::class)->catat($this->operator($bank), ['warga_id' => $warga->id, 'tipe' => 'jual', 'items' => [['jenis_sampah_id' => $this->jenis('Plastik')->id, 'berat_kg' => 20]]]);
        Sanctum::actingAs($warga);
        $this->postJson('/api/v1/warga/penarikan', ['bank_sampah_id' => $bank->id, 'jumlah' => 1000])->assertCreated();
        Sanctum::actingAs(User::factory()->dlh()->create());
        $this->getJson('/api/v1/dlh/transaksi')->assertOk()->assertJsonPath('meta.total', 2);
        $this->getJson('/api/v1/dlh/transaksi?tipe=penarikan')->assertOk()->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.tipe', 'penarikan')->assertJsonPath('data.0.total_nilai', 1000)
            ->assertJsonPath('data.0.status', 'diajukan');
        $this->assertSame(60000.0, $this->saldo($warga, $bank));
    }
}
