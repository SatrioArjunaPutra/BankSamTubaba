<?php

namespace App\Http\Resources;

use App\Models\PrelovedItem;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin PrelovedItem
 */
class PrelovedResource extends JsonResource
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
            'status' => $this->status->value,
            'penjual' => $this->whenLoaded('penjual', fn () => [
                'id' => $this->penjual->id,
                'name' => $this->penjual->name,
                'phone' => $this->penjual->phone ?? null,
            ]),
            'milik_saya' => (int) $request->user()?->id === (int) $this->penjual_id,
            'jumlah_laporan' => $this->whenCounted('laporan'),
            'jumlah_favorit' => $this->whenHas('jumlah_favorit', fn ($v) => (int) $v),
            'difavoritkan' => $this->whenHas('difavoritkan', fn ($v) => (bool) $v),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
