<?php

namespace App\Policies;

use App\Enums\UserRole;
use App\Models\Penarikan;
use App\Models\User;

class PenarikanPolicy
{
    public function proses(User $user, Penarikan $penarikan): bool
    {
        return $user->hasRole(UserRole::BankSampah) && $penarikan->dimilikiOleh($user);
    }
}
