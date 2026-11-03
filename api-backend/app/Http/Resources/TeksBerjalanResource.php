<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Tampilan publik: hanya teks yang ditayangkan.
 *
 * @mixin \App\Models\TeksBerjalan
 */
class TeksBerjalanResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'teks' => $this->teks,
        ];
    }
}
