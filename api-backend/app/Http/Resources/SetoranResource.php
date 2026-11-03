<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Setoran
 */
class SetoranResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'bank_sampah_id' => $this->bank_sampah_id,
            'bank_sampah' => $this->whenLoaded('bankSampah', fn () => RingkasBankSampah::dari($this->bankSampah)),
            'warga_id' => $this->warga_id,
            'warga' => $this->whenLoaded('warga', fn () => ['id' => $this->warga->id, 'name' => $this->warga->name]),
            'tipe' => $this->tipe->value,
            'total_kg' => (float) $this->total_kg,
            'total_nilai' => (float) $this->total_nilai,
            'penjemputan_id' => $this->penjemputan_id,
            'dicatat_oleh' => $this->dicatat_oleh,
            'catatan' => $this->catatan,
            'dibatalkan_at' => $this->dibatalkan_at?->toIso8601String(),
            'alasan_batal' => $this->alasan_batal,
            'items' => $this->whenLoaded('items', fn () => $this->items->map(fn ($item) => [
                'jenis_sampah_id' => $item->jenis_sampah_id,
                'nama' => $item->relationLoaded('jenisSampah') ? $item->jenisSampah->nama : null,
                'berat_kg' => (float) $item->berat_kg,
                'harga_per_kg' => (float) $item->harga_per_kg,
                'subtotal' => (float) $item->subtotal,
            ])),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
