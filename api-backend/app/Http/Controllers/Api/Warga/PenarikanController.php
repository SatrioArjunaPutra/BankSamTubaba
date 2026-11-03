<?php

namespace App\Http\Controllers\Api\Warga;

use App\Http\Controllers\Controller;
use App\Http\Requests\Warga\AjukanPenarikanRequest;
use App\Http\Resources\PenarikanResource;
use App\Models\Penarikan;
use App\Services\PenarikanService;
use Illuminate\Http\Request;

class PenarikanController extends Controller
{
    public function index(Request $request)
    {
        $penarikan = Penarikan::with('bankSampah')
            ->where('warga_id', $request->user()->id)
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->string('status')))
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PenarikanResource::collection($penarikan), 'Riwayat penarikan berhasil dimuat.');
    }

    public function store(AjukanPenarikanRequest $request, PenarikanService $service)
    {
        $penarikan = $service->ajukan(
            $request->user(),
            $request->integer('bank_sampah_id'),
            $request->validated('jumlah'),
            $request->validated('catatan'),
        );

        return $this->sukses('Penarikan berhasil diajukan dan menunggu persetujuan bank sampah.', new PenarikanResource($penarikan->load('bankSampah')), 201);
    }
}
