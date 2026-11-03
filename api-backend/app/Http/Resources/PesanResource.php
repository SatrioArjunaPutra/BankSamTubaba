<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Pesan
 */
class PesanResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'percakapan_id' => $this->percakapan_id,
            'pengirim_id' => $this->pengirim_id,
            'milik_saya' => (int) $request->user()?->id === (int) $this->pengirim_id,
            'isi' => $this->isi,
            'tawaran_harga' => $this->tawaran_harga !== null ? (float) $this->tawaran_harga : null,
            'dibaca_at' => $this->dibaca_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
