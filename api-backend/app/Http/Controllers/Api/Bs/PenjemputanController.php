<?php

namespace App\Http\Controllers\Api\Bs;

use App\Http\Controllers\Controller;
use App\Http\Requests\Bs\ProsesPenjemputanRequest;
use App\Http\Resources\PenjemputanResource;
use App\Models\Penjemputan;
use App\Services\PenjemputanService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class PenjemputanController extends Controller
{
    // ?status= bisa satu atau beberapa dipisah koma, mis. dijadwalkan,menuju
    public function index(Request $request)
    {
        $penjemputan = Penjemputan::milik($request->user())
            ->with(['warga:id,name,phone', 'armada.driver:id,name,phone'])
            ->when($request->filled('status'), fn ($q) => $q->whereIn('status', explode(',', $request->string('status'))))
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PenjemputanResource::collection($penjemputan), 'Daftar penjemputan berhasil dimuat.');
    }

    public function update(ProsesPenjemputanRequest $request, Penjemputan $penjemputan, PenjemputanService $service)
    {
        Gate::authorize('kelola', $penjemputan);

        if ($request->validated('aksi') === 'jadwalkan') {
            $penjemputan = $service->jadwalkan($penjemputan, $request->integer('armada_id'), $request->validated('jadwal_at'));
            $pesan = 'Penjemputan berhasil dijadwalkan.';
        } else {
            $penjemputan = $service->tolak($penjemputan, $request->validated('alasan'));
            $pesan = 'Penjemputan ditolak.';
        }

        return $this->sukses($pesan, new PenjemputanResource($penjemputan->load(['warga:id,name,phone', 'armada.driver:id,name,phone'])));
    }
}
