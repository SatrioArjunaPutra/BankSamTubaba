<?php

namespace App\Policies;

use App\Enums\StatusPreloved;
use App\Enums\UserRole;
use App\Models\PrelovedItem;
use App\Models\User;

class PrelovedItemPolicy
{
    // Barang disembunyikan DLH hanya terlihat oleh pemiliknya dan DLH
    public function lihat(User $user, PrelovedItem $item): bool
    {
        return $item->status !== StatusPreloved::Disembunyikan
            || $item->milik($user)
            || $user->hasRole(UserRole::Dlh);
    }

    // Ubah, hapus, tandai terjual: hanya penjual
    public function kelola(User $user, PrelovedItem $item): bool
    {
        return $item->milik($user);
    }
}
