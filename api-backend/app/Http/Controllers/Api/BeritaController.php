<?php

namespace App\Http\Controllers\Api;

use App\Enums\StatusBerita;
use App\Http\Controllers\Controller;
use App\Http\Resources\BeritaResource;
use App\Models\Berita;
use Illuminate\Http\Request;

/**
 * Berita publik di web, tanpa login. Hanya artikel berstatus terbit.
 */
class BeritaController extends Controller
{
    public function index(Request $request)
    {
        $request->validate(['q' => ['nullable', 'string', 'max:100']]);

        $berita = Berita::query()->terbit()
            ->when($request->filled('q'), function ($q) use ($request) {
                $kata = '%'.mb_strtolower($request->string('q')).'%';
                $q->where(fn ($q) => $q->whereRaw('lower(judul) like ?', [$kata])->orWhereRaw('lower(ringkasan) like ?', [$kata]));
            })
            ->latest('diterbitkan_at')
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(BeritaResource::collection($berita), 'Daftar berita berhasil dimuat.');
    }

    public function show(Berita $berita)
    {
        // Draf dijawab 404 agar keberadaannya tidak terlihat
        abort_unless($berita->status === StatusBerita::Terbit, 404);

        // Lewat query builder agar updated_at tidak ikut berubah karena dibaca
        Berita::whereKey($berita->id)->toBase()->increment('dibaca');
        $berita->dibaca++;

        return $this->sukses('Detail berita berhasil dimuat.', new BeritaResource($berita));
    }
}
