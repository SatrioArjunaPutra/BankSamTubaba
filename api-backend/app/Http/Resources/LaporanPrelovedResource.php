<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\LaporanPreloved
 */
class LaporanPrelovedResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'alasan' => $this->alasan,
            'status' => $this->status->value,
            'pelapor' => $this->whenLoaded('pelapor', fn () => ['id' => $this->pelapor->id, 'name' => $this->pelapor->name]),
            'barang' => $this->whenLoaded('item', fn () => new PrelovedResource($this->item)),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
