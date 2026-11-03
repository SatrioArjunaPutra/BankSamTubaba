<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Satu barang beserta semua laporan warga berstatus yang sedang disaring.
 *
 * @mixin \App\Models\PrelovedItem
 */
class LaporanPerBarangResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'barang' => new PrelovedResource($this->resource),
            'jumlah_laporan' => (int) $this->laporan_count,
            'laporan' => LaporanPrelovedResource::collection($this->laporan),
        ];
    }
}
