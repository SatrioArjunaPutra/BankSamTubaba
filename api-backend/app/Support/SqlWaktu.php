<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;

/**
 * Ekspresi SQL tanggal yang berbeda antara SQLite (test) dan PostgreSQL
 * (lokal Docker & Supabase).
 */
final class SqlWaktu
{
    private static function pgsql(): bool
    {
        return DB::connection()->getDriverName() === 'pgsql';
    }

    // Selisih dua kolom timestamp dalam jam
    public static function selisihJam(string $akhir, string $awal): string
    {
        return self::pgsql()
            ? "extract(epoch from ({$akhir} - {$awal})) / 3600.0"
            : "(julianday({$akhir}) - julianday({$awal})) * 24.0";
    }

    // Kunci periode: YYYY-MM-DD (harian) atau YYYY-MM (bulanan)
    public static function periode(string $kolom, string $interval): string
    {
        if (self::pgsql()) {
            return $interval === 'bulanan' ? "to_char({$kolom}, 'YYYY-MM')" : "to_char({$kolom}, 'YYYY-MM-DD')";
        }

        return $interval === 'bulanan' ? "strftime('%Y-%m', {$kolom})" : "strftime('%Y-%m-%d', {$kolom})";
    }
}
