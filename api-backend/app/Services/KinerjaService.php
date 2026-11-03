<?php

namespace App\Services;

use App\Enums\StatusPenjemputan;
use App\Enums\UserRole;
use App\Models\BankSampah;
use App\Models\Penjemputan;
use App\Models\Setoran;
use App\Models\User;
use App\Support\SqlWaktu;
use Carbon\CarbonInterface;
use Illuminate\Support\Collection;

/**
 * Laporan DLH. Semua angka dihitung dengan query agregat (GROUP BY),
 * jumlah query tetap berapa pun banyaknya bank sampah.
 */
class KinerjaService
{
    /**
     * @return array<string, int|float>
     */
    public function ringkasan(CarbonInterface $dari, CarbonInterface $sampai): array
    {
        $setoran = Setoran::whereBetween('created_at', [$dari, $sampai])
            ->selectRaw('count(*) as jumlah, coalesce(sum(total_kg), 0) as total_kg, coalesce(sum(total_nilai), 0) as nilai')
            ->selectRaw("coalesce(sum(case when tipe = 'donasi' then total_kg else 0 end), 0) as kg_donasi")
            ->selectRaw('count(distinct warga_id) as nasabah_aktif')
            ->first();

        return [
            'total_kg' => (float) $setoran->total_kg,
            'kg_donasi' => (float) $setoran->kg_donasi,
            'nilai_transaksi' => (float) $setoran->nilai,
            'jumlah_setoran' => (int) $setoran->jumlah,
            'nasabah_aktif' => (int) $setoran->nasabah_aktif,
            'jemput_aktif' => Penjemputan::whereIn('status', StatusPenjemputan::aktif())->count(),
            'bank_sampah_aktif' => BankSampah::aktif()->count(),
            'jumlah_warga' => User::where('role', UserRole::Warga->value)->count(),
        ];
    }

    /**
     * Per bank sampah aktif, urut total_kg terbesar.
     *
     * @return Collection<int, array<string, mixed>>
     */
    public function perBankSampah(CarbonInterface $dari, CarbonInterface $sampai): Collection
    {
        $setoran = Setoran::whereBetween('created_at', [$dari, $sampai])
            ->groupBy('bank_sampah_id')
            ->select('bank_sampah_id')
            ->selectRaw('coalesce(sum(total_kg), 0) as total_kg, coalesce(sum(total_nilai), 0) as nilai_setoran')
            ->selectRaw("coalesce(sum(case when tipe = 'donasi' then total_kg else 0 end), 0) as kg_donasi")
            ->selectRaw('count(distinct warga_id) as nasabah_aktif')
            ->get()
            ->keyBy('bank_sampah_id');

        $jemput = Penjemputan::where('status', StatusPenjemputan::Selesai->value)
            ->whereBetween('selesai_at', [$dari, $sampai])
            ->groupBy('bank_sampah_id')
            ->select('bank_sampah_id')
            ->selectRaw('count(*) as jemput_selesai')
            ->selectRaw('avg('.SqlWaktu::selisihJam('selesai_at', 'created_at').') as rata2_jam')
            ->get()
            ->keyBy('bank_sampah_id');

        // Jemput yang sedang berjalan saat ini (tidak dibatasi rentang), untuk peta DLH
        $jemputAktif = Penjemputan::whereIn('status', StatusPenjemputan::aktif())
            ->groupBy('bank_sampah_id')
            ->selectRaw('bank_sampah_id, count(*) as jumlah')
            ->pluck('jumlah', 'bank_sampah_id');

        return BankSampah::aktif()->orderBy('kode')->get(['id', 'kode', 'nama', 'kecamatan', 'lat', 'lng'])
            ->map(fn (BankSampah $b) => [
                'bank_sampah' => [
                    'id' => $b->id,
                    'kode' => $b->kode,
                    'nama' => $b->nama,
                    'kecamatan' => $b->kecamatan,
                    'lat' => $b->lat,
                    'lng' => $b->lng,
                ],
                'total_kg' => (float) ($setoran[$b->id]->total_kg ?? 0),
                'kg_donasi' => (float) ($setoran[$b->id]->kg_donasi ?? 0),
                'nasabah_aktif' => (int) ($setoran[$b->id]->nasabah_aktif ?? 0),
                'nilai_setoran' => (float) ($setoran[$b->id]->nilai_setoran ?? 0),
                'jemput_selesai' => (int) ($jemput[$b->id]->jemput_selesai ?? 0),
                'rata2_waktu_jemput_jam' => isset($jemput[$b->id]) ? round((float) $jemput[$b->id]->rata2_jam, 2) : null,
                'jemput_aktif' => (int) ($jemputAktif[$b->id] ?? 0),
            ])
            ->sortByDesc('total_kg')
            ->values();
    }

    /**
     * Deret waktu setoran satu bank sampah. Periode tanpa setoran diisi 0.
     *
     * @return array<int, array{periode: string, total_kg: float, kg_donasi: float, nilai_setoran: float, jumlah_setoran: int}>
     */
    public function tren(BankSampah $bank, CarbonInterface $dari, CarbonInterface $sampai, string $interval): array
    {
        $kunci = SqlWaktu::periode('created_at', $interval);

        $baris = Setoran::where('bank_sampah_id', $bank->id)
            ->whereBetween('created_at', [$dari, $sampai])
            ->groupByRaw($kunci)
            ->selectRaw("{$kunci} as periode")
            ->selectRaw('coalesce(sum(total_kg), 0) as total_kg, coalesce(sum(total_nilai), 0) as nilai_setoran, count(*) as jumlah')
            ->selectRaw("coalesce(sum(case when tipe = 'donasi' then total_kg else 0 end), 0) as kg_donasi")
            ->get()
            ->keyBy('periode');

        $hasil = [];
        $format = $interval === 'bulanan' ? 'Y-m' : 'Y-m-d';
        $langkah = $interval === 'bulanan' ? $dari->copy()->startOfMonth() : $dari->copy()->startOfDay();

        while ($langkah <= $sampai) {
            $p = $langkah->format($format);
            $hasil[] = [
                'periode' => $p,
                'total_kg' => (float) ($baris[$p]->total_kg ?? 0),
                'kg_donasi' => (float) ($baris[$p]->kg_donasi ?? 0),
                'nilai_setoran' => (float) ($baris[$p]->nilai_setoran ?? 0),
                'jumlah_setoran' => (int) ($baris[$p]->jumlah ?? 0),
            ];
            $langkah = $interval === 'bulanan' ? $langkah->addMonth() : $langkah->addDay();
        }

        return $hasil;
    }
}
