<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Berita
 */
class BeritaDlhResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'judul' => $this->judul,
            'ringkasan' => $this->ringkasan,
            'isi' => $this->isi,
            'kategori' => $this->kategori->value,
            'status' => $this->status->value,
            'foto' => $this->urlFoto(),
            'diterbitkan_at' => $this->diterbitkan_at?->toIso8601String(),
            'dibaca' => (int) $this->dibaca,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
