<?php

namespace App\Http\Controllers\Api\Warga;

use App\Http\Controllers\Controller;
use App\Http\Resources\NasabahResource;
use App\Models\Nasabah;
use App\Support\Uang;
use Illuminate\Http\Request;

class SaldoController extends Controller
{
    // data: {total_saldo, daftar: [{bank_sampah_id, bank_sampah, saldo, updated_at}]}
    public function index(Request $request)
    {
        $nasabah = Nasabah::with('bankSampah')
            ->where('warga_id', $request->user()->id)
            ->orderByDesc('saldo')
            ->get();

        $totalSen = $nasabah->sum(fn (Nasabah $n) => Uang::keSen($n->saldo));

        return $this->sukses('Saldo berhasil dimuat.', [
            'total_saldo' => $totalSen / 100,
            'daftar' => NasabahResource::collection($nasabah),
        ]);
    }
}
