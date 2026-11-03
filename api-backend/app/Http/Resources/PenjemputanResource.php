<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/**
 * @mixin \App\Models\Penjemputan
 */
class PenjemputanResource extends JsonResource
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
            // Kontak warga hanya untuk operator & bentor yang menjemput
            'warga' => $this->whenLoaded('warga', fn () => [
                'id' => $this->warga->id,
                'name' => $this->warga->name,
                'phone' => $this->warga->phone,
            ]),
            'armada_id' => $this->armada_id,
            'armada' => $this->whenLoaded('armada', fn () => $this->armada ? [
                'id' => $this->armada->id,
                'plat_nomor' => $this->armada->plat_nomor,
                'driver' => $this->armada->relationLoaded('driver') ? [
                    'id' => $this->armada->driver->id,
                    'name' => $this->armada->driver->name,
                    'phone' => $this->armada->driver->phone,
                ] : null,
            ] : null),
            'alamat' => $this->alamat,
            'lat' => $this->lat,
            'lng' => $this->lng,
            'perkiraan_kg' => $this->perkiraan_kg !== null ? (float) $this->perkiraan_kg : null,
            'catatan' => $this->catatan,
            'foto_url' => $this->foto_path ? Storage::disk(config('filesystems.upload_disk'))->url($this->foto_path) : null,
            'status' => $this->status->value,
            'alasan_tolak' => $this->alasan_tolak,
            'jadwal_at' => $this->jadwal_at?->toIso8601String(),
            'dijadwalkan_at' => $this->dijadwalkan_at?->toIso8601String(),
            'diambil_at' => $this->diambil_at?->toIso8601String(),
            'selesai_at' => $this->selesai_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
