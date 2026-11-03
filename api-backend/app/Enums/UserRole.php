<?php

namespace App\Enums;

enum UserRole: string
{
    case Dlh = 'dlh';
    case BankSampah = 'bank_sampah';
    case Bentor = 'bentor';
    case Warga = 'warga';

    /**
     * @return array<int, string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
