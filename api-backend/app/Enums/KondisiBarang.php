<?php

namespace App\Enums;

enum KondisiBarang: string
{
    case Baru = 'baru';
    case SepertiBaru = 'seperti_baru';
    case BekasBaik = 'bekas_baik';
    case Bekas = 'bekas';
}
