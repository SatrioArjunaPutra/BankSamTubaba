<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Penarikan
 */
class PenarikanResource extends JsonResource
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
            'warga' => $this->whenLoaded('warga', fn () => ['id' => $this->warga->id, 'name' => $this->warga->name, 'phone' => $this->warga->phone]),
            'jumlah' => (float) $this->jumlah,
            'status' => $this->status->value,
            'diproses_oleh' => $this->diproses_oleh,
            'catatan' => $this->catatan,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
