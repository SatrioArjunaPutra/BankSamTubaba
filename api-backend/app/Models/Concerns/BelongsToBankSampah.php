<?php

namespace App\Models\Concerns;

use App\Models\BankSampah;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Untuk model yang punya kolom bank_sampah_id.
 *
 * Operator (bank_sampah) dan bentor hanya boleh menyentuh data bank sampah
 * miliknya: query dibatasi lewat scope milik(), dan Policy memeriksa satu
 * record lewat dimilikiOleh().
 */
trait BelongsToBankSampah
{
    public function bankSampah(): BelongsTo
    {
        return $this->belongsTo(BankSampah::class);
    }

    /**
     * Batasi query ke bank sampah milik user. Role lain (dlh/warga) tidak
     * dibatasi di sini; batasan mereka diatur oleh route/Policy masing-masing.
     */
    public function scopeMilik(Builder $query, User $user): Builder
    {
        if (! $user->terikatBankSampah()) {
            return $query;
        }

        // bank_sampah_id NULL tidak boleh lolos sebagai "semua data"
        return $query->where($this->qualifyColumn('bank_sampah_id'), $user->bank_sampah_id ?? 0);
    }

    public function dimilikiOleh(User $user): bool
    {
        return $user->bank_sampah_id !== null
            && (int) $this->bank_sampah_id === (int) $user->bank_sampah_id;
    }
}
