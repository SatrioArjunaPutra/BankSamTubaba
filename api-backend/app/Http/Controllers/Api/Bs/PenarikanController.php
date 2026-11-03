<?php

namespace App\Http\Controllers\Api\Bs;

use App\Http\Controllers\Controller;
use App\Http\Requests\Bs\ProsesPenarikanRequest;
use App\Http\Resources\PenarikanResource;
use App\Models\Penarikan;
use App\Services\PenarikanService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class PenarikanController extends Controller
{
    public function index(Request $request)
    {
        $penarikan = Penarikan::milik($request->user())
            ->with('warga:id,name,phone')
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->string('status')))
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PenarikanResource::collection($penarikan), 'Daftar penarikan berhasil dimuat.');
    }

    public function update(ProsesPenarikanRequest $request, Penarikan $penarikan, PenarikanService $service)
    {
        Gate::authorize('proses', $penarikan);

        $setujui = $request->validated('aksi') === 'setujui';
        $penarikan = $setujui
            ? $service->setujui($penarikan, $request->user(), $request->validated('catatan'))
            : $service->tolak($penarikan, $request->user(), $request->validated('catatan'));

        return $this->sukses(
            $setujui ? 'Penarikan disetujui dan saldo nasabah telah dikurangi.' : 'Penarikan ditolak.',
            new PenarikanResource($penarikan->load('warga:id,name,phone')),
        );
    }
}
