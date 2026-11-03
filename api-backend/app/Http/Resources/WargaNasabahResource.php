<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Hasil cari warga oleh operator, dengan saldo warga di bank sampah operator
 * (kolom saldo_di_bank dari subquery; 0 jika belum pernah menyetor).
 *
 * @mixin \App\Models\User
 */
class WargaNasabahResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $sudahNasabah = $this->saldo_di_bank !== null;

        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            // Alamat hanya untuk nasabah bank ini (warga lain ditemukan lewat HP/email persis)
            'alamat' => $sudahNasabah ? $this->alamat : null,
            'saldo' => (float) ($this->saldo_di_bank ?? 0),
            'sudah_nasabah' => $sudahNasabah,
        ];
    }
}
