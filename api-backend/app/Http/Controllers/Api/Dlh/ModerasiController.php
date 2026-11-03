<?php

namespace App\Http\Controllers\Api\Dlh;

use App\Enums\StatusLaporan;
use App\Enums\StatusPreloved;
use App\Http\Controllers\Controller;
use App\Http\Resources\LaporanPerBarangResource;
use App\Http\Resources\PrelovedResource;
use App\Models\PrelovedItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ModerasiController extends Controller
{
    /**
     * Monitoring seluruh katalog barang preloved warga se-Tubaba.
     */
    public function index(Request $request)
    {
        $request->validate([
            'status' => ['nullable', 'string', 'in:tersedia,terjual,disembunyikan,semua'],
            'kategori' => ['nullable', 'string'],
            'kecamatan' => ['nullable', 'string'],
            'q' => ['nullable', 'string'],
        ]);

        $statusInput = $request->input('status');

        $barang = PrelovedItem::with(['penjual:id,name,phone'])
            // Hanya laporan yang masih perlu ditinjau, sama dengan isi daftar laporan
            ->withCount(['laporan' => fn ($q) => $q->where('status', StatusLaporan::Baru->value)])
            ->when($statusInput && $statusInput !== 'semua', fn ($q) => $q->where('status', $statusInput))
            ->when($request->filled('kategori'), fn ($q) => $q->where('kategori', $request->string('kategori')))
            ->when($request->filled('kecamatan'), fn ($q) => $q->where('kecamatan', $request->string('kecamatan')))
            ->when($request->filled('q'), function ($q) use ($request) {
                $kata = '%'.mb_strtolower($request->string('q')).'%';
                $q->where(fn ($q) => $q->whereRaw('lower(judul) like ?', [$kata])
                    ->orWhereRaw('lower(deskripsi) like ?', [$kata])
                    ->orWhereHas('penjual', fn ($uq) => $uq->whereRaw('lower(name) like ?', [$kata]))
                );
            })
            ->latest()
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PrelovedResource::collection($barang), 'Daftar barang preloved berhasil dimuat.');
    }

    /**
     * Satu baris per barang beserta semua laporan warga berstatus yang disaring
     * (default: baru), urut laporan terbaru.
     */
    public function laporan(Request $request)
    {
        $request->validate(['status' => ['nullable', Rule::enum(StatusLaporan::class)]]);

        $status = $request->input('status', StatusLaporan::Baru->value);
        $saring = fn ($q) => $q->where('status', $status);

        $barang = PrelovedItem::with('penjual:id,name')
            ->with(['laporan' => fn ($q) => $saring($q)->with('pelapor:id,name')->latest()->latest('id')])
            ->withCount(['laporan' => $saring])
            ->withMax(['laporan as laporan_terbaru' => $saring], 'created_at')
            ->whereHas('laporan', $saring)
            ->orderByDesc('laporan_terbaru')
            ->orderByDesc('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(LaporanPerBarangResource::collection($barang), 'Daftar laporan berhasil dimuat.');
    }

    /**
     * Sembunyikan → laporan baru jadi "ditindak"; tampilkan lagi → laporan
     * baru jadi "diabaikan".
     */
    public function ubahStatus(Request $request, PrelovedItem $prelovedItem)
    {
        $data = $request->validate(['status' => ['required', 'in:disembunyikan,tersedia']]);
        $status = StatusPreloved::from($data['status']);

        // "tersedia" hanya untuk memulihkan barang yang disembunyikan, bukan menjual ulang barang terjual
        if ($status === StatusPreloved::Tersedia && $prelovedItem->status !== StatusPreloved::Disembunyikan) {
            throw ValidationException::withMessages([
                'status' => "Barang berstatus {$prelovedItem->status->value} tidak bisa diubah menjadi tersedia.",
            ]);
        }

        DB::transaction(function () use ($prelovedItem, $status) {
            $prelovedItem->status = $status;
            $prelovedItem->save();

            $prelovedItem->laporan()
                ->where('status', StatusLaporan::Baru->value)
                ->update(['status' => $status === StatusPreloved::Disembunyikan ? StatusLaporan::Ditindak->value : StatusLaporan::Diabaikan->value]);
        });

        return $this->sukses(
            $status === StatusPreloved::Disembunyikan ? 'Barang berhasil disembunyikan (diban) dari warga.' : 'Barang ditampilkan kembali ke warga.',
            new PrelovedResource($prelovedItem->load('penjual:id,name')),
        );
    }

    /**
     * Hapus barang preloved oleh DLH jika terbukti melanggar / scam.
     */
    public function destroy(PrelovedItem $prelovedItem)
    {
        DB::transaction(function () use ($prelovedItem) {
            $prelovedItem->laporan()->delete();
            $prelovedItem->percakapan()->delete();
            $prelovedItem->delete();
            $prelovedItem->hapusFileFoto();
        });

        return $this->sukses('Barang preloved berhasil dihapus.');
    }
}
