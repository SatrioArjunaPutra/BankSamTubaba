<?php

namespace App\Policies;

use App\Enums\UserRole;
use App\Models\User;

class UserPolicy
{
    // Operator hanya boleh mengaktifkan/menonaktifkan bentor di bank sampahnya
    public function kelolaBentor(User $operator, User $akun): bool
    {
        return $operator->hasRole(UserRole::BankSampah)
            && $akun->hasRole(UserRole::Bentor)
            && $operator->bank_sampah_id !== null
            && (int) $akun->bank_sampah_id === (int) $operator->bank_sampah_id;
    }
}
