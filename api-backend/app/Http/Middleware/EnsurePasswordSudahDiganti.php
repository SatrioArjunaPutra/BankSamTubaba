<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Akun yang baru direset petugas memakai password sementara. Sampai password
 * itu diganti, hanya lihat profil, ganti password, dan keluar yang diizinkan
 * (route tersebut memakai withoutMiddleware).
 */
class EnsurePasswordSudahDiganti
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user()?->harus_ganti_password) {
            return response()->json([
                'status' => 'gagal',
                'pesan' => 'Ganti password sementara Anda terlebih dahulu.',
                'kode' => 'wajib_ganti_password',
            ], 403);
        }

        return $next($request);
    }
}
