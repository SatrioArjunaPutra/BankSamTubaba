<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Nasabah
 */
class NasabahResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'bank_sampah_id' => $this->bank_sampah_id,
            'bank_sampah' => $this->whenLoaded('bankSampah', fn () => RingkasBankSampah::dari($this->bankSampah)),
            'saldo' => (float) $this->saldo,
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
