<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PemberitahuanResource;
use App\Models\Pemberitahuan;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Pemberitahuan milik pengguna yang login. Pemberitahuan orang lain dijawab 404.
 */
class PemberitahuanController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $daftar = Pemberitahuan::where('user_id', $request->user()->id)
            ->orderByDesc('id')
            ->paginate(20);

        return $this->daftar(PemberitahuanResource::collection($daftar), 'Pemberitahuan berhasil dimuat.');
    }

    /**
     * Dipanggil berkala oleh aplikasi untuk angka di ikon lonceng.
     */
    public function belumDibaca(Request $request): JsonResponse
    {
        $jumlah = Pemberitahuan::where('user_id', $request->user()->id)->whereNull('dibaca_at')->count();

        return $this->sukses('Jumlah pemberitahuan belum dibaca.', ['jumlah' => $jumlah]);
    }

    public function baca(Request $request, int $pemberitahuan): JsonResponse
    {
        $baris = Pemberitahuan::where('user_id', $request->user()->id)->whereKey($pemberitahuan)->firstOrFail();

        if ($baris->dibaca_at === null) {
            $baris->forceFill(['dibaca_at' => now()])->save();
        }

        return $this->sukses('Pemberitahuan ditandai dibaca.', new PemberitahuanResource($baris));
    }

    public function bacaSemua(Request $request): JsonResponse
    {
        $jumlah = Pemberitahuan::where('user_id', $request->user()->id)
            ->whereNull('dibaca_at')
            ->update(['dibaca_at' => now()]);

        return $this->sukses('Semua pemberitahuan ditandai dibaca.', ['jumlah' => $jumlah]);
    }
}
