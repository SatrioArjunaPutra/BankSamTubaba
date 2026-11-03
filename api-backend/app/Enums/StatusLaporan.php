<?php

namespace App\Enums;

enum StatusLaporan: string
{
    case Baru = 'baru';
    case Ditindak = 'ditindak';
    case Diabaikan = 'diabaikan';
}
