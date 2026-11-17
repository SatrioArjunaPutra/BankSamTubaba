<?php

namespace App\Http\Controllers\Api\Bs;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\Nasabah;
use App\Models\User;
use App\Services\AkunService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

/**
 * Pengelola mereset password warga yang menabung di banknya atau bentor miliknya,
 * setelah memastikan pemilik akun datang langsung. Password sementara hanya
 * tampil sekali dan tidak disimpan oleh server.
 */
class ResetPasswordController extends Controller
{
    public function nasabah(Request $request, User $warga, AkunService $service): JsonResponse
    {
        $nasabahBankIni = $warga->hasRole(UserRole::Warga)
            && $warga->is_aktif
            && Nasabah::milik($request->user())->where('warga_id', $warga->id)->exists();

        // Warga yang bukan nasabah bank ini dijawab seperti tidak ada
        abort_unless($nasabahBankIni, 404);

        return $this->jawab($warga, $service->resetPassword($warga));
    }

    public function bentor(User $user, AkunService $service): JsonResponse
    {
        Gate::authorize('kelolaBentor', $user);

        return $this->jawab($user, $service->resetPassword($user));
    }

    private function jawab(User $akun, string $sandi): JsonResponse
    {
        return $this->sukses('Password sementara dibuat. Berikan langsung kepada pemilik akun.', [
            'user' => ['id' => $akun->id, 'name' => $akun->name],
            'password_sementara' => $sandi,
        ])->header('Cache-Control', 'no-store');
    }
}
