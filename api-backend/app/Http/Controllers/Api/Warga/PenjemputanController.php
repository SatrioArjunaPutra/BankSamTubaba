<?php

namespace App\Http\Controllers\Api\Warga;

use App\Http\Controllers\Controller;
use App\Http\Requests\Warga\AjukanPenjemputanRequest;
use App\Http\Resources\PenjemputanResource;
use App\Models\Penjemputan;
use App\Services\PenjemputanService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class PenjemputanController extends Controller
{
    public function __construct(private PenjemputanService $service) {}

    public function index(Request $request)
    {
        $penjemputan = Penjemputan::with(['bankSampah', 'armada.driver'])
            ->where('warga_id', $request->user()->id)
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->string('status')))
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PenjemputanResource::collection($penjemputan), 'Daftar penjemputan berhasil dimuat.');
    }

    public function store(AjukanPenjemputanRequest $request)
    {
        $penjemputan = $this->service->ajukan(
            $request->user(),
            $request->safe()->except('foto'),
            $request->file('foto'),
        );

        return $this->sukses('Permintaan jemput berhasil diajukan.', new PenjemputanResource($penjemputan->load('bankSampah')), 201);
    }

    public function batal(Penjemputan $penjemputan)
    {
        Gate::authorize('batal', $penjemputan);

        $penjemputan = $this->service->batal($penjemputan);

        return $this->sukses('Permintaan jemput dibatalkan.', new PenjemputanResource($penjemputan->load('bankSampah')));
    }
}
