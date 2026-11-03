<?php

namespace App\Http\Controllers\Api\Preloved;

use App\Enums\StatusPreloved;
use App\Http\Controllers\Controller;
use App\Http\Requests\Preloved\KirimPesanRequest;
use App\Http\Resources\PercakapanResource;
use App\Http\Resources\PesanResource;
use App\Models\Percakapan;
use App\Models\Pesan;
use App\Models\PrelovedItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

/**
 * Chat jual-beli preloved. Realtime memakai polling (bukan WebSocket):
 * layar chat memanggil GET /chat/{id}/pesan?after_id= tiap 3 detik.
 */
class ChatController extends Controller
{
    private const MAKS_PESAN = 50;

    // Buka (atau ambil yang sudah ada) percakapan sebagai pembeli
    public function buka(Request $request, PrelovedItem $prelovedItem)
    {
        abort_unless(Gate::allows('lihat', $prelovedItem), 404);
        $saya = $request->user();

        if ($prelovedItem->milik($saya)) {
            throw ValidationException::withMessages(['preloved_item_id' => 'Anda tidak bisa chat dengan barang sendiri.']);
        }

        $percakapan = Percakapan::where('preloved_item_id', $prelovedItem->id)->where('pembeli_id', $saya->id)->first();

        if (! $percakapan) {
            if ($prelovedItem->status !== StatusPreloved::Tersedia) {
                throw ValidationException::withMessages(['preloved_item_id' => 'Barang ini sudah tidak tersedia.']);
            }

            $percakapan = Percakapan::firstOrCreate(
                ['preloved_item_id' => $prelovedItem->id, 'pembeli_id' => $saya->id],
                ['penjual_id' => $prelovedItem->penjual_id],
            );
        }

        return $this->sukses(
            'Percakapan siap.',
            new PercakapanResource($percakapan->load(['item', 'penjual:id,name', 'pembeli:id,name'])),
            $percakapan->wasRecentlyCreated ? 201 : 200,
        );
    }

    /**
     * Percakapan yang sudah berisi pesan, terbaru di atas. Pesan terakhir dan
     * jumlah belum dibaca diambil dengan subquery (tanpa N+1).
     */
    public function index(Request $request)
    {
        $saya = $request->user();

        $percakapan = Percakapan::melibatkan($saya)
            ->whereNotNull('last_message_at')
            ->addSelect(['pesan_terakhir_id' => Pesan::select('id')
                ->whereColumn('percakapan_id', 'percakapan.id')
                ->orderByDesc('id')
                ->limit(1)])
            ->withCount(['pesan as belum_dibaca_count' => fn ($q) => $q->whereNull('dibaca_at')->where('pengirim_id', '!=', $saya->id)])
            ->with(['item', 'penjual:id,name', 'pembeli:id,name', 'pesanTerakhir'])
            ->orderByDesc('last_message_at')
            ->orderByDesc('id')
            ->paginate(20)
            ->withQueryString();

        return $this->daftar(PercakapanResource::collection($percakapan), 'Daftar chat berhasil dimuat.');
    }

    /**
     * Dengan after_id: pesan setelah id itu (urut naik, untuk polling).
     * Tanpa after_id: 50 pesan terakhir (urut naik).
     */
    public function pesan(Request $request, Percakapan $percakapan)
    {
        Gate::authorize('ikut', $percakapan);
        $request->validate(['after_id' => ['nullable', 'integer', 'min:0']]);

        $query = $percakapan->pesan()->select(['id', 'percakapan_id', 'pengirim_id', 'isi', 'tawaran_harga', 'dibaca_at', 'created_at']);

        $pesan = $request->filled('after_id')
            ? $query->where('id', '>', $request->integer('after_id'))->orderBy('id')->limit(self::MAKS_PESAN)->get()
            : $query->orderByDesc('id')->limit(self::MAKS_PESAN)->get()->reverse()->values();

        return $this->daftar(PesanResource::collection($pesan), 'Pesan berhasil dimuat.');
    }

    public function kirim(KirimPesanRequest $request, Percakapan $percakapan)
    {
        Gate::authorize('ikut', $percakapan);

        if ($percakapan->item->status === StatusPreloved::Disembunyikan) {
            throw ValidationException::withMessages(['isi' => 'Barang ini disembunyikan oleh DLH, percakapan ditutup.']);
        }

        $pesan = DB::transaction(function () use ($request, $percakapan) {
            $pesan = $percakapan->pesan()->create([
                'pengirim_id' => $request->user()->id,
                'isi' => $request->validated('isi'),
                'tawaran_harga' => $request->validated('tawaran_harga'),
            ]);

            $percakapan->forceFill(['last_message_at' => $pesan->created_at])->save();

            return $pesan;
        });

        return $this->sukses('Pesan terkirim.', new PesanResource($pesan->refresh()), 201);
    }

    // Tandai semua pesan dari lawan bicara sebagai dibaca
    public function baca(Request $request, Percakapan $percakapan)
    {
        Gate::authorize('ikut', $percakapan);

        $jumlah = $percakapan->pesan()
            ->whereNull('dibaca_at')
            ->where('pengirim_id', '!=', $request->user()->id)
            ->update(['dibaca_at' => now()]);

        return $this->sukses('Pesan ditandai dibaca.', ['jumlah' => $jumlah]);
    }
}
