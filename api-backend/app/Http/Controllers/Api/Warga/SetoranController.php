<?php

namespace App\Http\Controllers\Api\Warga;

use App\Http\Controllers\Controller;
use App\Http\Resources\SetoranResource;
use App\Models\Setoran;
use Illuminate\Http\Request;

class SetoranController extends Controller
{
    // Riwayat setoran & donasi milik warga, opsional per bank sampah
    public function index(Request $request)
    {
        // Setoran batal tetap tampil agar warga tahu mengapa saldonya berkurang
        $setoran = Setoran::denganBatal()->with(['bankSampah', 'items.jenisSampah'])
            ->where('warga_id', $request->user()->id)
            ->when($request->filled('bank_sampah_id'), fn ($q) => $q->where('bank_sampah_id', $request->integer('bank_sampah_id')))
            ->when($request->filled('tipe'), fn ($q) => $q->where('tipe', $request->string('tipe')))
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(SetoranResource::collection($setoran), 'Riwayat setoran berhasil dimuat.');
    }
}
