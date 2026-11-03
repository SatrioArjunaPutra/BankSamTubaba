<?php

namespace App\Services;

use App\Enums\StatusArmada;
use App\Enums\StatusPenjemputan;
use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Aktif/nonaktifkan akun operator (bank_sampah) dan bentor.
 * Akun yang dinonaktifkan langsung kehilangan semua token login, sehingga
 * tidak bisa lagi mencatat setoran atau menyetujui penarikan.
 */
class AkunService
{
    public function ubahStatus(User $akun, bool $aktif): User
    {
        if (! $akun->terikatBankSampah()) {
            throw ValidationException::withMessages([
                'is_aktif' => 'Hanya akun operator bank sampah dan bentor yang bisa diaktifkan/nonaktifkan.',
            ]);
        }

        return DB::transaction(function () use ($akun, $aktif) {
            if (! $aktif && $akun->hasRole(UserRole::Bentor) && $akun->armada) {
                $sedangJalan = $akun->armada->tugasAktif()
                    ->whereIn('status', [StatusPenjemputan::Menuju->value, StatusPenjemputan::Diambil->value])
                    ->exists();

                if ($sedangJalan) {
                    throw ValidationException::withMessages([
                        'is_aktif' => 'Bentor sedang menjalankan penjemputan. Tunggu sampai selesai sebelum menonaktifkan akun.',
                    ]);
                }

                // Armada tanpa driver aktif tidak boleh dipilih untuk tugas baru
                $akun->armada->update(['status' => StatusArmada::Nonaktif]);
            }

            $akun->forceFill(['is_aktif' => $aktif])->save();

            if (! $aktif) {
                $akun->tokens()->delete();
            }

            return $akun;
        });
    }
}
