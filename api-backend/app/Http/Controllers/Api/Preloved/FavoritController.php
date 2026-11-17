<?php

namespace App\Http\Controllers\Api\Preloved;

use App\Enums\StatusPreloved;
use App\Http\Controllers\Controller;
use App\Http\Resources\PrelovedResource;
use App\Models\PrelovedItem;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class FavoritController extends Controller
{
    // Barang yang disimpan warga, terbaru disimpan di atas. Barang disembunyikan DLH tidak ikut.
    public function index(Request $request)
    {
        $warga = $request->user();
        // select() harus sebelum denganFavorit(), kalau tidak kolom hitungan favorit ikut tertimpa
        $barang = PrelovedItem::with('penjual:id,name')
            ->select('preloved_items.*')
            ->denganFavorit($warga)
            ->join('preloved_favorit as simpan', fn ($j) => $j->on('simpan.preloved_item_id', '=', 'preloved_items.id')
                ->where('simpan.warga_id', $warga->id))
            ->where('preloved_items.status', '!=', StatusPreloved::Disembunyikan->value)
            ->orderByDesc('simpan.created_at')
            ->orderByDesc('simpan.id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PrelovedResource::collection($barang), 'Barang favorit berhasil dimuat.');
    }

    // Menyimpan dua kali tidak membuat baris baru dan tetap berhasil
    public function simpan(Request $request, PrelovedItem $prelovedItem)
    {
        abort_unless(Gate::allows('lihat', $prelovedItem), 404);
        $warga = $request->user();

        if ($prelovedItem->milik($warga)) {
            throw ValidationException::withMessages(['barang' => 'Anda tidak bisa memfavoritkan barang sendiri.']);
        }

        if ($prelovedItem->status !== StatusPreloved::Tersedia) {
            throw ValidationException::withMessages(['barang' => 'Barang ini sudah tidak tersedia.']);
        }

        try {
            DB::transaction(fn () => $prelovedItem->favoritOleh()->syncWithoutDetaching([$warga->id]));
        } catch (UniqueConstraintViolationException) {
            // Kiriman bersamaan dari akun yang sama: barang sudah tersimpan
        }

        return $this->sukses('Barang disimpan ke favorit.', new PrelovedResource($prelovedItem->load('penjual:id,name')->muatFavorit($warga)));
    }

    public function hapus(Request $request, PrelovedItem $prelovedItem)
    {
        abort_unless(Gate::allows('lihat', $prelovedItem), 404);
        $warga = $request->user();
        $prelovedItem->favoritOleh()->detach($warga->id);

        return $this->sukses('Barang dihapus dari favorit.', new PrelovedResource($prelovedItem->load('penjual:id,name')->muatFavorit($warga)));
    }
}
