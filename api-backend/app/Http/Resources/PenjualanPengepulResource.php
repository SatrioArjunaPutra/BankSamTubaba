<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\PenjualanPengepul
 */
class PenjualanPengepulResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'bank_sampah_id' => $this->bank_sampah_id,
            'nama_pengepul' => $this->nama_pengepul,
            'jenis_sampah_id' => $this->jenis_sampah_id,
            'jenis_sampah' => $this->whenLoaded('jenisSampah', fn () => $this->jenisSampah->nama),
            'berat_kg' => (float) $this->berat_kg,
            'harga_per_kg' => (float) $this->harga_per_kg,
            'total' => (float) $this->total,
            'tanggal' => $this->tanggal?->toDateString(),
            'dicatat_oleh' => $this->dicatat_oleh,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
