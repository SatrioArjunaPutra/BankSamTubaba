<?php

namespace App\Services;

use App\Enums\StatusArmada;
use App\Enums\StatusPenarikan;
use App\Enums\StatusPenjemputan;
use App\Enums\StatusPreloved;
use App\Enums\UserRole;
use App\Models\Nasabah;
use App\Models\Penarikan;
use App\Models\Penjemputan;
use App\Models\PrelovedItem;
use App\Models\User;
use App\Support\Uang;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Siklus hidup akun: aktif/nonaktif operator dan bentor, reset password oleh
 * petugas, dan hapus akun warga. Setiap perubahan ini mencabut token login.
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

    /**
     * Huruf dan angka yang tidak mudah tertukar saat dibacakan (tanpa 0/o, 1/l/i).
     */
    private const HURUF_SANDI = 'abcdefghjkmnpqrstuvwxyz23456789';

    /**
     * Buat password sementara untuk akun yang lupa password. Semua sesi akun
     * dicabut dan pemiliknya wajib mengganti password saat login berikutnya.
     * Password asli hanya dikembalikan sekali, tidak disimpan.
     */
    public function resetPassword(User $akun): string
    {
        $sandi = '';
        for ($i = 0; $i < 8; $i++) {
            $sandi .= self::HURUF_SANDI[random_int(0, strlen(self::HURUF_SANDI) - 1)];
        }

        DB::transaction(function () use ($akun, $sandi) {
            $akun->forceFill(['password' => $sandi, 'harus_ganti_password' => true])->save();
            $akun->tokens()->delete();
        });

        return $sandi;
    }

    /**
     * Hapus akun warga atas permintaannya sendiri. Riwayat setoran tetap
     * dibutuhkan untuk kinerja bank sampah, jadi akun dianonimkan dan
     * dinonaktifkan, bukan dihapus dari database.
     */
    public function hapusWarga(User $warga): void
    {
        DB::transaction(function () use ($warga) {
            // Kunci saldo agar setoran yang masuk bersamaan tidak lolos tanpa terlihat
            $sisaSaldo = (float) Nasabah::where('warga_id', $warga->id)->lockForUpdate()->get()->sum('saldo');

            if ($sisaSaldo > 0) {
                throw ValidationException::withMessages([
                    'akun' => 'Saldo Anda masih '.Uang::rupiah($sisaSaldo).'. Tarik saldo terlebih dahulu sebelum menghapus akun.',
                ]);
            }

            if (Penarikan::where('warga_id', $warga->id)->where('status', StatusPenarikan::Diajukan->value)->exists()) {
                throw ValidationException::withMessages([
                    'akun' => 'Masih ada penarikan saldo yang menunggu persetujuan.',
                ]);
            }

            if (Penjemputan::where('warga_id', $warga->id)->whereIn('status', StatusPenjemputan::aktif())->exists()) {
                throw ValidationException::withMessages([
                    'akun' => 'Masih ada penjemputan yang berjalan. Batalkan atau tunggu sampai selesai.',
                ]);
            }

            PrelovedItem::where('penjual_id', $warga->id)
                ->where('status', StatusPreloved::Tersedia->value)
                ->update(['status' => StatusPreloved::Disembunyikan->value]);
            DB::table('preloved_favorit')->where('warga_id', $warga->id)->delete();

            $warga->forceFill([
                'name' => 'Warga terhapus',
                'email' => 'terhapus-'.$warga->id.'-'.Str::lower(Str::random(12)).'@akun-terhapus.invalid',
                'phone' => null,
                'alamat' => null,
                'lat' => null,
                'lng' => null,
                'password' => Str::random(40),
                'remember_token' => null,
                'is_aktif' => false,
                'harus_ganti_password' => false,
            ])->save();
            $warga->tokens()->delete();
        });
    }
}
