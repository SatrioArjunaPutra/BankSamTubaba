<?php

namespace App\Http\Controllers\Api\Bentor;

use App\Enums\StatusPenjemputan;
use App\Enums\TipeSetoran;
use App\Http\Controllers\Controller;
use App\Http\Requests\Bentor\CatatSetoranTugasRequest;
use App\Http\Requests\Bentor\UbahStatusRequest;
use App\Http\Resources\PenjemputanResource;
use App\Http\Resources\SetoranResource;
use App\Models\Penjemputan;
use App\Services\PenjemputanService;
use App\Services\SetoranService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class TugasController extends Controller
{
    /**
     * Tugas jemput untuk armada milik bentor. Tanpa ?status= hanya tugas yang
     * masih berjalan (dijadwalkan, menuju, diambil), urut jadwal terdekat.
     */
    public function index(Request $request)
    {
        $armadaId = $request->user()->armada?->id;

        $status = $request->filled('status')
            ? explode(',', $request->string('status'))
            : [StatusPenjemputan::Dijadwalkan->value, StatusPenjemputan::Menuju->value, StatusPenjemputan::Diambil->value];

        $tugas = Penjemputan::with(['warga:id,name,phone', 'bankSampah'])
            ->where('armada_id', $armadaId ?? 0)
            ->whereIn('status', $status)
            ->orderBy('jadwal_at')
            ->orderBy('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PenjemputanResource::collection($tugas), 'Daftar tugas berhasil dimuat.');
    }

    public function ubahStatus(UbahStatusRequest $request, Penjemputan $penjemputan, PenjemputanService $service)
    {
        Gate::authorize('jalankan', $penjemputan);

        $tujuan = StatusPenjemputan::from($request->validated('status'));
        $penjemputan = $service->ubahOlehBentor($penjemputan, $tujuan);

        return $this->sukses(
            $tujuan === StatusPenjemputan::Menuju ? 'Status diperbarui: menuju lokasi warga.' : 'Status diperbarui: sampah sudah diambil.',
            new PenjemputanResource($penjemputan->load(['warga:id,name,phone', 'bankSampah'])),
        );
    }

    /** Hasil timbang bentor langsung menjadi setoran dan menyelesaikan tugas. */
    public function catatSetoran(CatatSetoranTugasRequest $request, Penjemputan $penjemputan, SetoranService $service)
    {
        Gate::authorize('jalankan', $penjemputan);

        $setoran = $service->catatOlehBentor($request->user(), $penjemputan, $request->validated());

        return $this->sukses(
            $setoran->tipe === TipeSetoran::Donasi ? 'Donasi sampah berhasil dicatat.' : 'Setoran berhasil dicatat.',
            [
                'setoran' => new SetoranResource($setoran->load(['warga:id,name', 'items.jenisSampah'])),
                'saldo_sekarang' => (float) ($setoran->saldo_setelah ?? $setoran->nasabah->saldo),
            ],
            201,
        );
    }
}
