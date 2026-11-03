<?php

namespace App\Enums;

enum StatusPreloved: string
{
    case Tersedia = 'tersedia';
    case Terjual = 'terjual';
    case Disembunyikan = 'disembunyikan';
}
