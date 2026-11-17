<?php

namespace App\Http\Resources;

use App\Models\Pemberitahuan;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Pemberitahuan
 */
class PemberitahuanResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'jenis' => $this->jenis,
            'judul' => $this->judul,
            'isi' => $this->isi,
            'tujuan' => (object) ($this->tujuan ?? []),
            'dibaca' => $this->dibaca_at !== null,
            'dibaca_at' => $this->dibaca_at?->toIso8601String(),
            'dibuat_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
