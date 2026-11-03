<?php

namespace App\Http\Controllers\Api\Bs;

use App\Enums\StatusPenarikan;
use App\Http\Controllers\Controller;
use App\Models\Nasabah;
use App\Models\Penarikan;
use App\Models\Penjemputan;
use App\Models\Setoran;
use Carbon\CarbonInterface;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function __invoke(Request $request)
    {
        $bankId = $request->user()->bank_sampah_id;

        $jemput = Penjemputan::where('bank_sampah_id', $bankId)
            ->selectRaw("sum(case when status = 'diajukan' then 1 else 0 end) as diajukan")
            ->selectRaw("sum(case when status in ('dijadwalkan', 'menuju', 'diambil') then 1 else 0 end) as berjalan")
            ->first();

        $penarikan = Penarikan::where('bank_sampah_id', $bankId)
            ->where('status', StatusPenarikan::Diajukan->value)
            ->selectRaw('count(*) as jumlah, coalesce(sum(jumlah), 0) as total')
            ->first();

        $nasabah = Nasabah::where('bank_sampah_id', $bankId)
            ->selectRaw('count(*) as jumlah, coalesce(sum(saldo), 0) as total_saldo')
            ->first();

        return $this->sukses('Ringkasan bank sampah berhasil dimuat.', [
            'hari_ini' => $this->ringkasSetoran($bankId, now()->startOfDay()),
            'bulan_ini' => $this->ringkasSetoran($bankId, now()->startOfMonth()),
            'penjemputan' => [
                'diajukan' => (int) $jemput->diajukan,
                'berjalan' => (int) $jemput->berjalan,
            ],
            'penarikan_diajukan' => [
                'jumlah' => (int) $penarikan->jumlah,
                'total' => (float) $penarikan->total,
            ],
            'nasabah' => [
                'jumlah' => (int) $nasabah->jumlah,
                'total_saldo' => (float) $nasabah->total_saldo,
            ],
        ]);
    }

    /**
     * @return array{jumlah_setoran: int, total_kg: float, kg_donasi: float, total_nilai: float}
     */
    private function ringkasSetoran(int $bankId, CarbonInterface $sejak): array
    {
        $baris = Setoran::where('bank_sampah_id', $bankId)
            ->where('created_at', '>=', $sejak)
            ->selectRaw('count(*) as jumlah, coalesce(sum(total_kg), 0) as total_kg, coalesce(sum(total_nilai), 0) as total_nilai')
            ->selectRaw("coalesce(sum(case when tipe = 'donasi' then total_kg else 0 end), 0) as kg_donasi")
            ->first();

        return [
            'jumlah_setoran' => (int) $baris->jumlah,
            'total_kg' => (float) $baris->total_kg,
            'kg_donasi' => (float) $baris->kg_donasi,
            'total_nilai' => (float) $baris->total_nilai,
        ];
    }
}
