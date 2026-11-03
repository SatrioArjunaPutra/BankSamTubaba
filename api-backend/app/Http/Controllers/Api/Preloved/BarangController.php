<?php

namespace App\Http\Controllers\Api\Preloved;

use App\Enums\StatusLaporan;
use App\Enums\StatusPreloved;
use App\Http\Controllers\Controller;
use App\Http\Requests\Preloved\SimpanBarangRequest;
use App\Http\Resources\PrelovedResource;
use App\Models\LaporanPreloved;
use App\Models\PrelovedItem;
use App\Support\GambarAman;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Throwable;

class BarangController extends Controller
{
    // Hanya barang tersedia; barang milik sendiri yang lain ada di /preloved/saya
    public function index(Request $request)
    {
        $barang = PrelovedItem::with('penjual:id,name')
            ->where('status', StatusPreloved::Tersedia->value)
            ->when($request->filled('kategori'), fn ($q) => $q->where('kategori', $request->string('kategori')))
            ->when($request->filled('kecamatan'), fn ($q) => $q->where('kecamatan', $request->string('kecamatan')))
            ->when($request->filled('q'), function ($q) use ($request) {
                $kata = '%'.mb_strtolower($request->string('q')).'%';
                $q->where(fn ($q) => $q->whereRaw('lower(judul) like ?', [$kata])->orWhereRaw('lower(deskripsi) like ?', [$kata]));
            })
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PrelovedResource::collection($barang), 'Daftar barang berhasil dimuat.');
    }

    public function saya(Request $request)
    {
        $barang = PrelovedItem::with('penjual:id,name')
            ->where('penjual_id', $request->user()->id)
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PrelovedResource::collection($barang), 'Barang Anda berhasil dimuat.');
    }

    public function show(PrelovedItem $prelovedItem)
    {
        // Barang disembunyikan dijawab 404 agar keberadaannya tidak terlihat
        abort_unless(Gate::allows('lihat', $prelovedItem), 404);

        return $this->sukses('Detail barang berhasil dimuat.', new PrelovedResource($prelovedItem->load('penjual:id,name')));
    }

    public function store(SimpanBarangRequest $request)
    {
        $paths = $this->simpanFoto($request->file('foto'));

        try {
            $barang = new PrelovedItem($request->safe()->except('foto'));
            $barang->penjual_id = $request->user()->id;
            $barang->status = StatusPreloved::Tersedia;
            $barang->foto = $paths;
            $barang->save();
        } catch (Throwable $e) {
            Storage::disk(config('filesystems.upload_disk'))->delete($paths);

            throw $e;
        }

        return $this->sukses('Barang berhasil dipasang.', new PrelovedResource($barang->refresh()->load('penjual:id,name')), 201);
    }

    public function update(SimpanBarangRequest $request, PrelovedItem $prelovedItem)
    {
        Gate::authorize('kelola', $prelovedItem);

        $prelovedItem->fill($request->safe()->except('foto'));

        if ($request->hasFile('foto')) {
            $lama = $prelovedItem->foto;
            $prelovedItem->foto = $this->simpanFoto($request->file('foto'));
            $prelovedItem->save();
            Storage::disk(config('filesystems.upload_disk'))->delete($lama);
        } else {
            $prelovedItem->save();
        }

        return $this->sukses('Barang berhasil diperbarui.', new PrelovedResource($prelovedItem->load('penjual:id,name')));
    }

    public function destroy(PrelovedItem $prelovedItem)
    {
        Gate::authorize('kelola', $prelovedItem);

        $prelovedItem->delete();
        $prelovedItem->hapusFileFoto();

        return $this->sukses('Barang berhasil dihapus.');
    }

    public function terjual(PrelovedItem $prelovedItem)
    {
        Gate::authorize('kelola', $prelovedItem);

        if ($prelovedItem->status !== StatusPreloved::Tersedia) {
            throw ValidationException::withMessages(['status' => "Barang berstatus {$prelovedItem->status->value} tidak bisa ditandai terjual."]);
        }

        $prelovedItem->status = StatusPreloved::Terjual;
        $prelovedItem->save();

        return $this->sukses('Barang ditandai terjual.', new PrelovedResource($prelovedItem->load('penjual:id,name')));
    }

    // Lapor ulang oleh orang yang sama memperbarui alasan (bukan laporan baru)
    public function lapor(Request $request, PrelovedItem $prelovedItem)
    {
        abort_unless(Gate::allows('lihat', $prelovedItem), 404);

        $data = $request->validate(['alasan' => ['required', 'string', 'min:5', 'max:500']]);

        if ($prelovedItem->milik($request->user())) {
            throw ValidationException::withMessages(['alasan' => 'Anda tidak bisa melaporkan barang sendiri.']);
        }

        // Satu akun hanya sekali per barang. Dua kiriman bersamaan ditahan indeks unique di database.
        try {
            $laporan = new LaporanPreloved(['preloved_item_id' => $prelovedItem->id, 'pelapor_id' => $request->user()->id, 'alasan' => $data['alasan']]);
            $laporan->status = StatusLaporan::Baru;
            DB::transaction(fn () => $laporan->save());
        } catch (UniqueConstraintViolationException) {
            throw ValidationException::withMessages(['alasan' => 'Anda sudah melaporkan barang ini.']);
        }

        return $this->sukses('Laporan terkirim. Terima kasih, DLH akan meninjau barang ini.', null, 201);
    }

    /**
     * Foto dibersihkan dari EXIF/GPS lalu disimpan dengan nama acak.
     *
     * @param  array<int, UploadedFile>  $files
     * @return array<int, string>
     */
    private function simpanFoto(array $files): array
    {
        return GambarAman::simpanBanyak($files, 'preloved');
    }
}
