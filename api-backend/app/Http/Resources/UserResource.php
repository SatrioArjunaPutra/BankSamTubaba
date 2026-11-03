<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\User
 */
class UserResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'role' => $this->role?->value,
            'bank_sampah_id' => $this->bank_sampah_id,
            'bank_sampah' => $this->whenLoaded('bankSampah', fn () => $this->bankSampah ? [
                'id' => $this->bankSampah->id,
                'kode' => $this->bankSampah->kode,
                'nama' => $this->bankSampah->nama,
            ] : null),
            'alamat' => $this->alamat,
            'lat' => $this->lat,
            'lng' => $this->lng,
            'is_aktif' => (bool) $this->is_aktif,
        ];
    }
}
