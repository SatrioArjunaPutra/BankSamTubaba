<?php

namespace App\Policies;

use App\Enums\UserRole;
use App\Models\Armada;
use App\Models\User;

class ArmadaPolicy
{
    public function kelola(User $user, Armada $armada): bool
    {
        return $user->hasRole(UserRole::BankSampah) && $armada->dimilikiOleh($user);
    }
}
