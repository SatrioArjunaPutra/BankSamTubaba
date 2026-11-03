<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\TeksBerjalanResource;
use App\Models\TeksBerjalan;

/**
 * Teks berjalan di bagian atas web publik, tanpa login.
 */
class TeksBerjalanController extends Controller
{
    private const BATAS = 20;

    public function __invoke()
    {
        $teks = TeksBerjalan::where('is_aktif', true)->urut()->limit(self::BATAS)->get();

        return $this->sukses('Teks berjalan berhasil dimuat.', TeksBerjalanResource::collection($teks));
    }
}
