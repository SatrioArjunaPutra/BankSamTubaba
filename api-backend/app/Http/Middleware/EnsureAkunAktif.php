<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Dipasang setelah auth:sanctum di semua route privat:
 * - akun yang dinonaktifkan langsung ditolak walau tokennya masih berlaku;
 * - role bank_sampah/bentor wajib terikat ke bank sampah yang aktif (tenancy).
 */
class EnsureAkunAktif
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user->is_aktif) {
            return $this->tolak('Akun Anda dinonaktifkan. Hubungi pengelola.');
        }

        if ($user->terikatBankSampah()) {
            if ($user->bank_sampah_id === null) {
                return $this->tolak('Akun belum terhubung ke bank sampah. Hubungi DLH.');
            }

            if (! $user->bankSampah?->is_aktif) {
                return $this->tolak('Bank sampah Anda sedang nonaktif. Hubungi DLH.');
            }
        }

        return $next($request);
    }

    private function tolak(string $pesan): Response
    {
        return response()->json(['status' => 'gagal', 'pesan' => $pesan], 403);
    }
}
