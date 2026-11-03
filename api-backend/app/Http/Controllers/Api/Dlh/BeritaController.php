<?php

namespace App\Http\Controllers\Api\Dlh;

use App\Enums\StatusBerita;
use App\Http\Controllers\Controller;
use App\Http\Requests\Dlh\SimpanBeritaRequest;
use App\Http\Resources\BeritaDlhResource;
use App\Models\Berita;
use App\Support\GambarAman;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Throwable;

class BeritaController extends Controller
{
    public function index(Request $request)
    {
        $request->validate([
            'status' => ['nullable', Rule::enum(StatusBerita::class)],
            'q' => ['nullable', 'string', 'max:100'],
        ]);

        $berita = Berita::query()
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->string('status')))
            ->when($request->filled('q'), function ($q) use ($request) {
                $q->whereRaw('lower(judul) like ?', ['%'.mb_strtolower($request->string('q')).'%']);
            })
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(BeritaDlhResource::collection($berita), 'Daftar berita berhasil dimuat.');
    }

    public function store(SimpanBeritaRequest $request)
    {
        $berita = new Berita($request->safe()->except(['foto', 'status', 'hapus_foto']));
        $berita->dibuat_oleh = $request->user()->id;
        $this->terapkanStatus($berita, StatusBerita::from($request->validated('status')));
        $berita->foto_path = $request->hasFile('foto') ? GambarAman::simpan($request->file('foto'), 'berita') : null;

        try {
            $berita->save();
        } catch (Throwable $e) {
            $berita->hapusFileFoto();

            throw $e;
        }

        return $this->sukses('Berita berhasil disimpan.', new BeritaDlhResource($berita->refresh()), 201);
    }

    public function update(SimpanBeritaRequest $request, Berita $berita)
    {
        $berita->fill($request->safe()->except(['foto', 'status', 'hapus_foto']));

        if ($request->filled('status')) {
            $this->terapkanStatus($berita, StatusBerita::from($request->validated('status')));
        }

        $lama = $berita->foto_path;

        if ($request->hasFile('foto')) {
            $berita->foto_path = GambarAman::simpan($request->file('foto'), 'berita');
        } elseif ($request->boolean('hapus_foto')) {
            $berita->foto_path = null;
        }

        $berita->save();

        if ($lama && $lama !== $berita->foto_path) {
            Storage::disk(config('filesystems.upload_disk'))->delete($lama);
        }

        return $this->sukses('Berita berhasil diperbarui.', new BeritaDlhResource($berita));
    }

    public function destroy(Berita $berita)
    {
        $berita->delete();
        $berita->hapusFileFoto();

        return $this->sukses('Berita berhasil dihapus.');
    }

    /** Tanggal terbit pertama dipertahankan saat artikel diturunkan lalu diterbitkan lagi. */
    private function terapkanStatus(Berita $berita, StatusBerita $status): void
    {
        $berita->status = $status;

        if ($status === StatusBerita::Terbit && $berita->diterbitkan_at === null) {
            $berita->diterbitkan_at = now();
        }
    }
}
