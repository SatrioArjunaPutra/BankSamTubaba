<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Percakapan
 */
class PercakapanResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $saya = $request->user();
        $sebagaiPenjual = (int) $saya?->id === (int) $this->penjual_id;
        $lawan = $sebagaiPenjual ? 'pembeli' : 'penjual';

        return [
            'id' => $this->id,
            'peran_saya' => $sebagaiPenjual ? 'penjual' : 'pembeli',
            'barang' => $this->whenLoaded('item', fn () => [
                'id' => $this->item->id,
                'judul' => $this->item->judul,
                'harga' => (float) $this->item->harga,
                'status' => $this->item->status->value,
                'foto' => $this->item->urlFoto()[0] ?? null,
            ]),
            'lawan_bicara' => $this->whenLoaded($lawan, fn () => ['id' => $this->{$lawan}->id, 'name' => $this->{$lawan}->name]),
            'pesan_terakhir' => $this->whenLoaded('pesanTerakhir', fn () => $this->pesanTerakhir ? new PesanResource($this->pesanTerakhir) : null),
            'unread_count' => $this->whenCounted('belumDibaca', fn () => (int) $this->belum_dibaca_count),
            'last_message_at' => $this->last_message_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
