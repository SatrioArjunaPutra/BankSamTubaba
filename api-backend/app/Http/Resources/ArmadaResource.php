<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Armada
 */
class ArmadaResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'bank_sampah_id' => $this->bank_sampah_id,
            'driver_id' => $this->driver_id,
            'driver' => $this->whenLoaded('driver', fn () => [
                'id' => $this->driver->id,
                'name' => $this->driver->name,
                'phone' => $this->driver->phone,
                'email' => $this->driver->email,
                'is_aktif' => $this->driver->is_aktif,
            ]),
            'plat_nomor' => $this->plat_nomor,
            'kapasitas_kg' => $this->kapasitas_kg !== null ? (float) $this->kapasitas_kg : null,
            'status' => $this->status->value,
            'tugas_aktif' => $this->whenCounted('tugasAktif'),
        ];
    }
}
