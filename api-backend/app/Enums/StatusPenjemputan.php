<?php

namespace App\Enums;

/**
 * Alur: diajukan → dijadwalkan → menuju → diambil → selesai.
 * Dari diajukan juga bisa ditolak (operator) atau dibatalkan (warga).
 */
enum StatusPenjemputan: string
{
    case Diajukan = 'diajukan';
    case Dijadwalkan = 'dijadwalkan';
    case Menuju = 'menuju';
    case Diambil = 'diambil';
    case Selesai = 'selesai';
    case Ditolak = 'ditolak';
    case Dibatalkan = 'dibatalkan';

    /**
     * @return array<int, self>
     */
    public function bolehMenjadi(): array
    {
        return match ($this) {
            self::Diajukan => [self::Dijadwalkan, self::Ditolak, self::Dibatalkan],
            self::Dijadwalkan => [self::Menuju],
            self::Menuju => [self::Diambil],
            self::Diambil => [self::Selesai],
            self::Selesai, self::Ditolak, self::Dibatalkan => [],
        };
    }

    public function bisaMenjadi(self $tujuan): bool
    {
        return in_array($tujuan, $this->bolehMenjadi(), true);
    }

    /**
     * Status yang masih berjalan (belum selesai/ditolak/dibatalkan).
     *
     * @return array<int, string>
     */
    public static function aktif(): array
    {
        return [self::Diajukan->value, self::Dijadwalkan->value, self::Menuju->value, self::Diambil->value];
    }
}
