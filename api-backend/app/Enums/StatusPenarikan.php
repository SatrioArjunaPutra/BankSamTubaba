<?php

namespace App\Enums;

enum StatusPenarikan: string
{
    case Diajukan = 'diajukan';
    case Disetujui = 'disetujui';
    case Ditolak = 'ditolak';
}
