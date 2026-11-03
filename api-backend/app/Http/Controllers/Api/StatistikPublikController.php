<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BankSampah;
use App\Models\PrelovedItem;

/**
 * Angka ringkas untuk beranda web tanpa login. Hanya jumlah, tanpa data pribadi
 * maupun nilai transaksi.
 */
class StatistikPublikController extends Controller
{
    public function __invoke()
    {
        return response()->json([
            'status' => 'sukses',
            'pesan' => 'Statistik berhasil dimuat.',
            'data' => [
                'bank_sampah' => BankSampah::query()->aktif()->count(),
                'kecamatan' => BankSampah::query()->aktif()->distinct()->count('kecamatan'),
                'barang_preloved' => PrelovedItem::query()->tayang()->count(),
                // Dasar warna kecamatan pada peta
                'bank_per_kecamatan' => (object) BankSampah::query()->aktif()
                    ->selectRaw('kecamatan, count(*) as jumlah')
                    ->groupBy('kecamatan')
                    ->pluck('jumlah', 'kecamatan')
                    ->map(fn ($n) => (int) $n)
                    ->all(),
            ],
        ]);
    }
}
