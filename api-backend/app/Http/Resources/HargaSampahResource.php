<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\HargaSampah
 */
class HargaSampahResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'jenis_sampah_id' => $this->jenis_sampah_id,
            'nama' => $this->whenLoaded('jenisSampah', fn () => $this->jenisSampah->nama),
            'satuan' => $this->whenLoaded('jenisSampah', fn () => $this->jenisSampah->satuan),
            'harga_per_kg' => (float) $this->harga_per_kg,
        ];
    }
}
