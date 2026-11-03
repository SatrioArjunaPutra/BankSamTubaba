<?php

namespace App\Http\Controllers\Api\Dlh;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\UbahStatusAkunRequest;
use App\Http\Resources\UserResource;
use App\Models\BankSampah;
use App\Models\User;
use App\Services\AkunService;

/**
 * Akun operator & bentor milik satu bank sampah, dikelola DLH.
 */
class AkunController extends Controller
{
    public function index(BankSampah $bankSampah)
    {
        $akun = User::where('bank_sampah_id', $bankSampah->id)
            ->whereIn('role', [UserRole::BankSampah->value, UserRole::Bentor->value])
            ->orderBy('role')
            ->orderBy('name')
            ->get();

        return $this->daftar(UserResource::collection($akun), 'Daftar akun berhasil dimuat.');
    }

    public function ubahStatus(UbahStatusAkunRequest $request, User $user, AkunService $service)
    {
        $user = $service->ubahStatus($user, $request->boolean('is_aktif'));

        return $this->sukses(
            $user->is_aktif ? 'Akun diaktifkan.' : 'Akun dinonaktifkan dan dikeluarkan dari semua perangkat.',
            new UserResource($user),
        );
    }
}
