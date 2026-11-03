<?php

namespace App\Http\Controllers\Api\Preloved;

use App\Http\Controllers\Controller;
use App\Http\Requests\Preloved\EtalaseRequest;
use App\Http\Resources\PrelovedEtalaseResource;
use App\Models\PrelovedItem;

/**
 * Etalase publik di web: hanya menampilkan barang. Beli dan chat tetap lewat
 * aplikasi warga.
 */
class EtalaseController extends Controller
{
    public function __invoke(EtalaseRequest $request)
    {
        $barang = PrelovedItem::query()->tayang()
            ->when($request->filled('kategori'), fn ($q) => $q->where('kategori', $request->validated('kategori')))
            ->when($request->filled('kecamatan'), fn ($q) => $q->where('kecamatan', $request->validated('kecamatan')))
            ->when($request->filled('q'), function ($q) use ($request) {
                $kata = '%'.mb_strtolower($request->validated('q')).'%';
                $q->where(fn ($q) => $q->whereRaw('lower(judul) like ?', [$kata])->orWhereRaw('lower(deskripsi) like ?', [$kata]));
            })
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return PrelovedEtalaseResource::collection($barang)->additional([
            'status' => 'sukses',
            'pesan' => 'Etalase preloved berhasil dimuat.',
            'filter' => [
                'kategori' => PrelovedItem::query()->tayang()->distinct()->orderBy('kategori')->pluck('kategori'),
                'kecamatan' => PrelovedItem::query()->tayang()->distinct()->orderBy('kecamatan')->pluck('kecamatan'),
            ],
        ]);
    }
}
