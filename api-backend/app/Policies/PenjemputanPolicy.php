<?php

namespace App\Policies;

use App\Enums\UserRole;
use App\Models\Penjemputan;
use App\Models\User;

class PenjemputanPolicy
{
    // Operator: jadwalkan/tolak penjemputan di bank sampahnya
    public function kelola(User $user, Penjemputan $penjemputan): bool
    {
        return $user->hasRole(UserRole::BankSampah) && $penjemputan->dimilikiOleh($user);
    }

    // Warga: batalkan permintaannya sendiri
    public function batal(User $user, Penjemputan $penjemputan): bool
    {
        return $user->hasRole(UserRole::Warga) && (int) $penjemputan->warga_id === (int) $user->id;
    }

    // Bentor: hanya tugas yang armada-nya miliknya
    public function jalankan(User $user, Penjemputan $penjemputan): bool
    {
        return $user->hasRole(UserRole::Bentor)
            && $penjemputan->armada_id !== null
            && (int) $penjemputan->armada?->driver_id === (int) $user->id;
    }
}
