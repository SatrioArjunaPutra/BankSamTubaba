<?php

namespace App\Enums;

enum StatusArmada: string
{
    case Siaga = 'siaga';
    case Bertugas = 'bertugas';
    case Nonaktif = 'nonaktif';
}
