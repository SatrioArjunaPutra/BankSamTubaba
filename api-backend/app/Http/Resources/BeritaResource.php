<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Tampilan publik: tanpa status dan pembuat. Isi artikel hanya ikut di detail.
 *
 * @mixin \App\Models\Berita
 */
class BeritaResource extends JsonResource
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
            'isi' => $this->when($request->route('berita') !== null, $this->isi),
            'kategori' => $this->kategori->value,
            'foto' => $this->urlFoto(),
            'diterbitkan_at' => $this->diterbitkan_at?->toIso8601String(),
            'dibaca' => (int) $this->dibaca,
        ];
    }
}
