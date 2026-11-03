<?php

namespace App\Http\Resources;

use App\Models\BankSampah;

/**
 * Bentuk ringkas bank sampah yang ditempelkan di resource lain.
 */
final class RingkasBankSampah
{
    /**
     * @return array{id: int, kode: string, nama: string}|null
     */
    public static function dari(?BankSampah $bank): ?array
    {
        return $bank ? ['id' => $bank->id, 'kode' => $bank->kode, 'nama' => $bank->nama] : null;
    }
}
