<?php

namespace App\Http\Controllers\Api\Bs;

use App\Http\Controllers\Controller;
use App\Http\Requests\Bs\BatalkanSetoranRequest;
use App\Http\Requests\Bs\CatatSetoranRequest;
use App\Http\Resources\SetoranResource;
use App\Models\Setoran;
use App\Services\SetoranService;
use Illuminate\Http\Request;

class SetoranController extends Controller
{
    public function index(Request $request)
    {
        $setoran = Setoran::denganBatal()->milik($request->user())
            ->with(['warga:id,name', 'items.jenisSampah'])
            ->when($request->filled('warga_id'), fn ($q) => $q->where('warga_id', $request->integer('warga_id')))
            ->when($request->filled('tipe'), fn ($q) => $q->where('tipe', $request->string('tipe')))
            ->when($request->filled('dari'), fn ($q) => $q->whereDate('created_at', '>=', $request->date('dari')))
            ->when($request->filled('sampai'), fn ($q) => $q->whereDate('created_at', '<=', $request->date('sampai')))
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(SetoranResource::collection($setoran), 'Riwayat setoran berhasil dimuat.');
    }

    public function store(CatatSetoranRequest $request, SetoranService $service)
    {
        $setoran = $service->catat($request->user(), $request->validated());

        return $this->sukses(
            $setoran->tipe->value === 'donasi' ? 'Donasi sampah berhasil dicatat.' : 'Setoran berhasil dicatat.',
            [
                'setoran' => new SetoranResource($setoran->load(['warga:id,name', 'items.jenisSampah'])),
                'saldo_sekarang' => (float) ($setoran->saldo_setelah ?? $setoran->nasabah->saldo),
            ],
            201,
        );
    }

    /** Bank sampah lain mendapat 404, seperti data yang memang tidak ada. */
    public function batal(BatalkanSetoranRequest $request, SetoranService $service, int $setoran)
    {
        $data = Setoran::denganBatal()->milik($request->user())->findOrFail($setoran);
        $hasil = $service->batalkan($data, $request->user(), $request->validated('alasan'));

        return $this->sukses('Setoran berhasil dibatalkan.', new SetoranResource($hasil->load(['warga:id,name', 'items.jenisSampah'])));
    }
}
