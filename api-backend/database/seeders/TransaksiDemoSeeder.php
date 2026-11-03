<?php

namespace Database\Seeders;

use App\Enums\StatusPenjemputan;
use App\Models\Armada;
use App\Models\BankSampah;
use App\Models\JenisSampah;
use App\Models\Penjemputan;
use App\Models\Setoran;
use App\Models\User;
use App\Services\PenjemputanService;
use App\Services\SetoranService;
use Illuminate\Database\Seeder;
use Ramsey\Uuid\Uuid;
use RuntimeException;

/**
 * Transaksi contoh dari berbagai warga, bank sampah, dan bentor: setoran yang
 * dicatat operator, serta penjemputan yang ditimbang bentor di lokasi. Semua
 * lewat layanan aslinya, sehingga saldo dan status tetap konsisten.
 *
 * Tidak dipanggil otomatis; jalankan setelah DemoSeeder:
 *   php artisan db:seed --class=TransaksiDemoSeeder
 *
 * Aman dijalankan ulang: transaksi yang sudah ada tidak digandakan.
 */
class TransaksiDemoSeeder extends Seeder
{
    /** [operator, warga, tipe, [jenis => kg], hari lalu] */
    private const LEWAT_OPERATOR = [
        [1, 2, 'jual', ['Plastik' => 12.5, 'Kardus' => 8], 0],
        [1, 3, 'jual', ['Botol Kaca' => 6], 1],
        [1, 1, 'donasi', ['Kertas' => 4], 2],
        [2, 4, 'jual', ['Logam' => 3.5, 'Plastik' => 5], 0],
        [2, 5, 'jual', ['Kardus' => 10], 2],
        [2, 1, 'donasi', ['Plastik' => 7], 5],
        [3, 2, 'jual', ['Kertas' => 9], 1],
        [3, 5, 'jual', ['Minyak Jelantah' => 4], 4],
        [3, 3, 'donasi', ['Kardus' => 6], 6],
    ];

    /** [bank, huruf bentor, warga, tipe, [jenis => kg], hari lalu] */
    private const LEWAT_BENTOR = [
        [1, 'a', 4, 'jual', ['Plastik' => 6.5], 0],
        [1, 'b', 5, 'jual', ['Kardus' => 9], 1],
        [2, 'a', 2, 'jual', ['Kertas' => 7.5, 'Plastik' => 2], 1],
        [2, 'b', 3, 'donasi', ['Botol Kaca' => 5], 3],
        [3, 'a', 1, 'jual', ['Logam' => 2.5], 2],
        [3, 'b', 4, 'jual', ['Plastik' => 8], 4],
    ];

    public function run(SetoranService $setoran, PenjemputanService $penjemputan): void
    {
        if (app()->environment('production')) {
            throw new RuntimeException('TransaksiDemoSeeder tidak boleh dijalankan di production.');
        }

        foreach (self::LEWAT_OPERATOR as $i => [$noOperator, $noWarga, $tipe, $isi, $hari]) {
            $operator = $this->akun("operator{$noOperator}");
            $requestId = $this->kunci("operator/{$i}");

            if ($this->sudahAda($operator, $requestId)) {
                continue;
            }

            $hasil = $setoran->catat($operator, [
                'warga_id' => $this->akun("warga{$noWarga}")->id,
                'tipe' => $tipe,
                'items' => $this->items($isi),
                'catatan' => 'Data demo transaksi',
                'request_id' => $requestId,
            ]);
            $this->mundurkan($hasil, ['created_at' => now()->subDays($hari)->subHours($i + 1)]);
        }

        foreach (self::LEWAT_BENTOR as $i => [$noBank, $huruf, $noWarga, $tipe, $isi, $hari]) {
            $bentor = $this->akun("bentor{$noBank}{$huruf}");
            $requestId = $this->kunci("bentor/{$i}");

            if ($this->sudahAda($bentor, $requestId)) {
                continue;
            }

            $bank = BankSampah::findOrFail($bentor->bank_sampah_id);
            $tugas = $penjemputan->ajukan($this->wargaBolehJemput($noWarga, $bank->id), [
                'bank_sampah_id' => $bank->id,
                'alamat' => 'Alamat contoh '.($i + 1).', '.$bank->tiyuh,
                'lat' => (float) $bank->lat + 0.002 * ($i + 1),
                'lng' => (float) $bank->lng + 0.002 * ($i + 1),
                'perkiraan_kg' => array_sum($isi),
                'catatan' => 'Data demo transaksi',
            ]);
            $armada = Armada::where('driver_id', $bentor->id)->firstOrFail();
            $tugas = $penjemputan->jadwalkan($tugas, $armada->id, now()->addHour()->toDateTimeString());
            $tugas = $penjemputan->ubahOlehBentor($tugas, StatusPenjemputan::Menuju);
            $tugas = $penjemputan->ubahOlehBentor($tugas, StatusPenjemputan::Diambil);
            $hasil = $setoran->catatOlehBentor($bentor, $tugas, [
                'tipe' => $tipe,
                'items' => $this->items($isi),
                'catatan' => 'Data demo transaksi',
                'request_id' => $requestId,
            ]);

            $selesai = now()->subDays($hari)->subHours($i + 1);
            $this->mundurkan($hasil, ['created_at' => $selesai]);
            $this->mundurkan($tugas->refresh(), [
                'created_at' => $selesai->copy()->subHours(5),
                'dijadwalkan_at' => $selesai->copy()->subHours(4),
                'jadwal_at' => $selesai->copy()->subHour(),
                'diambil_at' => $selesai->copy()->subMinutes(15),
                'selesai_at' => $selesai,
            ]);
        }

        $this->command?->info('  Transaksi demo siap.');
    }

    private function akun(string $nama): User
    {
        $user = User::where('email', "{$nama}@banksampah.test")->first();

        if (! $user) {
            throw new RuntimeException("Akun {$nama} belum ada. Jalankan DemoSeeder lebih dulu.");
        }

        return $user;
    }

    /**
     * Warga yang belum mencapai batas jemput aktif di bank ini, mulai dari warga
     * yang diminta, karena database lama bisa punya permintaan yang masih berjalan.
     */
    private function wargaBolehJemput(int $no, int $bankId): User
    {
        for ($geser = 0; $geser < 5; $geser++) {
            $warga = $this->akun('warga'.(($no + $geser - 1) % 5 + 1));
            $menunggu = Penjemputan::where('warga_id', $warga->id)
                ->where('bank_sampah_id', $bankId)
                ->whereIn('status', [StatusPenjemputan::Diajukan->value, StatusPenjemputan::Dijadwalkan->value])
                ->count();

            if ($menunggu < PenjemputanService::MAKS_JEMPUT_MENUNGGU) {
                return $warga;
            }
        }

        throw new RuntimeException("Semua warga demo sudah mencapai batas jemput di bank {$bankId}.");
    }

    private function kunci(string $nama): string
    {
        return Uuid::uuid5(Uuid::NAMESPACE_URL, "banksampah/demo-transaksi/{$nama}")->toString();
    }

    private function sudahAda(User $pencatat, string $requestId): bool
    {
        return Setoran::denganBatal()->where('dicatat_oleh', $pencatat->id)->where('request_id', $requestId)->exists();
    }

    /**
     * @param  array<string, float|int>  $isi
     * @return array<int, array{jenis_sampah_id: int, berat_kg: float|int}>
     */
    private function items(array $isi): array
    {
        return array_map(
            fn (string $jenis, float|int $kg) => [
                'jenis_sampah_id' => JenisSampah::where('nama', $jenis)->firstOrFail()->id,
                'berat_kg' => $kg,
            ],
            array_keys($isi),
            array_values($isi),
        );
    }

    /**
     * Sebar tanggal agar grafik dan riwayat terlihat wajar. Saldo tidak ikut berubah.
     *
     * @param  array<string, mixed>  $kolom
     */
    private function mundurkan(Setoran|Penjemputan $model, array $kolom): void
    {
        $model->newQuery()->withoutGlobalScopes()->whereKey($model->getKey())->update($kolom + ['updated_at' => $kolom['selesai_at'] ?? $kolom['created_at']]);
    }
}
