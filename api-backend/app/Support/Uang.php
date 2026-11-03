<?php

namespace App\Support;

/**
 * Hitung uang & berat dalam satuan sen (integer) agar tidak ada selisih
 * pembulatan float. Kolom DB decimal(.., 2), jadi 2 angka desimal cukup.
 */
final class Uang
{
    public static function keSen(string|int|float|null $nilai): int
    {
        return (int) round(((float) $nilai) * 100);
    }

    public static function dariSen(int $sen): string
    {
        return number_format($sen / 100, 2, '.', '');
    }

    /**
     * berat (kg, 2 desimal) × harga (Rp, 2 desimal), dibulatkan ke sen.
     */
    public static function kali(string|int|float $beratKg, string|int|float $hargaPerKg): int
    {
        return (int) round(self::keSen($beratKg) * self::keSen($hargaPerKg) / 10000 * 100);
    }

    public static function rupiah(string|int|float $nilai): string
    {
        return 'Rp '.number_format((float) $nilai, 0, ',', '.');
    }
}
