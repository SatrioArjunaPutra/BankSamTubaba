<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Data barang untuk pengunjung tanpa login. Sengaja tanpa identitas penjual;
 * jangan menurunkan dari PrelovedResource yang memuat nomor HP.
 *
 * @mixin \App\Models\PrelovedItem
 */
class PrelovedEtalaseResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'judul' => $this->judul,
            'deskripsi' => $this->deskripsi,
            'kategori' => $this->kategori,
            'kondisi' => $this->kondisi->value,
            'harga' => (float) $this->harga,
            'kecamatan' => $this->kecamatan,
            'foto' => $this->urlFoto(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
