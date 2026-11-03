<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\JenisSampahResource;
use App\Models\JenisSampah;

class JenisSampahController extends Controller
{
    public function index()
    {
        return $this->daftar(
            JenisSampahResource::collection(JenisSampah::aktif()->orderBy('nama')->get()),
            'Daftar jenis sampah berhasil dimuat.',
        );
    }
}
