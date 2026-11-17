<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PerangkatResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Perangkat yang sedang login dengan akun ini. Pengguna hanya bisa melihat dan
 * mengeluarkan sesi miliknya sendiri; ID sesi orang lain dijawab 404.
 */
class PerangkatController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $perangkat = $request->user()->tokens()
            ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))
            ->orderByDesc('last_used_at')
            ->orderByDesc('id')
            ->get();

        return $this->daftar(PerangkatResource::collection($perangkat), 'Daftar perangkat berhasil dimuat.');
    }

    public function hapus(Request $request, int $perangkat): JsonResponse
    {
        $token = $request->user()->tokens()->whereKey($perangkat)->firstOrFail();
        $token->delete();

        return $this->sukses('Perangkat berhasil dikeluarkan.');
    }

    public function keluarLainnya(Request $request): JsonResponse
    {
        $tokenSekarang = $request->user()->currentAccessToken();

        $jumlah = $request->user()->tokens()
            ->when($tokenSekarang instanceof PersonalAccessToken, fn ($query) => $query->whereKeyNot($tokenSekarang->getKey()))
            ->delete();

        return $this->sukses('Perangkat lain berhasil dikeluarkan.', ['jumlah' => $jumlah]);
    }
}
