<?php

namespace App\Policies;

use App\Models\Percakapan;
use App\Models\User;

class PercakapanPolicy
{
    // Hanya penjual & pembeli percakapan itu yang bisa membaca/mengirim pesan
    public function ikut(User $user, Percakapan $percakapan): bool
    {
        return $percakapan->peserta($user);
    }
}
