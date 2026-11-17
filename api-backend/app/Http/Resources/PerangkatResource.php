<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Satu sesi login (token Sanctum) milik pengguna. Isi token tidak pernah dikirim.
 *
 * @mixin PersonalAccessToken
 */
class PerangkatResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $tokenSekarang = $request->user()?->currentAccessToken();

        return [
            'id' => $this->id,
            'nama' => $this->name,
            'dibuat_at' => $this->created_at?->toIso8601String(),
            'terakhir_dipakai_at' => $this->last_used_at?->toIso8601String(),
            'kedaluwarsa_at' => $this->expires_at?->toIso8601String(),
            'saat_ini' => $tokenSekarang instanceof PersonalAccessToken && $tokenSekarang->is($this->resource),
        ];
    }
}
